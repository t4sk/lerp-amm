// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./interfaces/IERC20.sol";
import "./lib/ERC20.sol";
import "./Math.sol";

// TODO: ema price
// TODO: gas and price compare with curve v1
// TODO: vyper
contract Pool is ERC20 {
    struct Weight {
        uint64 w0;
        uint64 w1;
        uint32 w0_time;
        uint32 w1_time;
    }

    struct Balances {
        uint128 b0;
        uint128 b1;
    }

    address public immutable coin0;
    address public immutable coin1;
    // Multiplier to normalize coin 0 and coin 1 to 18 decimals
    uint256 public immutable n0;
    uint256 public immutable n1;

    uint32 private constant MIN_W_DT = 24 * 3600;

    address public owner;
    bool private locked;
    Weight public weight;
    Balances private balances;
    uint256 public fee;

    modifier lock() {
        require(!locked, "locked");
        locked = true;
        _;
        locked = false;
    }

    modifier auth() {
        require(msg.sender == owner, "not authorized");
        _;
    }

    constructor(
        uint64 w,
        uint256 f,
        address _coin0,
        address _coin1,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol, 18) {
        require(w <= W, "w > max");
        require(f <= F, "fee > max");
        require(_coin0 != _coin1, "coin 0 = coin 1");
        coin0 = _coin0;
        coin1 = _coin1;
        n0 = 10 ** (18 - IERC20(_coin0).decimals());
        n1 = 10 ** (18 - IERC20(_coin1).decimals());
        weight = Weight({
            w0: w,
            w1: w,
            w0_time: uint32(block.timestamp),
            w1_time: uint32(block.timestamp)
        });
        fee = f;
        owner = msg.sender;
    }

    function set_owner(address _owner) external auth {
        owner = _owner;
    }

    function set_fee(uint256 f) external auth {
        require(f <= F, "fee > max");
        fee = f;
    }

    function set_w(uint64 w1, uint32 w1_time) external auth {
        require(w1 <= W, "w > max");
        require(w1_time >= uint32(block.timestamp) + MIN_W_DT, "w1 time < min");
        uint64 w = uint64(get_w());
        weight.w0 = w;
        weight.w1 = w1;
        weight.w0_time = uint32(block.timestamp);
        weight.w1_time = w1_time;
    }

    function stop_w() external auth {
        uint64 w = uint64(get_w());
        weight.w0 = w;
        weight.w1 = w;
        weight.w0_time = uint32(block.timestamp);
        weight.w1_time = uint32(block.timestamp);
    }

    function get_w() public view returns (uint256) {
        Weight memory w = weight;
        return Math.lerp_w(
            uint256(w.w0),
            uint256(w.w1),
            uint256(w.w0_time),
            uint256(w.w1_time),
            block.timestamp
        );
    }

    function get_balances() public view returns (uint256 b0, uint256 b1) {
        Balances memory bals = balances;
        b0 = bals.b0;
        b1 = bals.b1;
    }

    function _set_balances(uint256 b0, uint256 b1) private {
        Balances storage bals = balances;
        bals.b0 = uint128(b0);
        bals.b1 = uint128(b1);
    }

    function _bal0() private view returns (uint256) {
        (bool ok, bytes memory data) = coin0.staticcall(
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(this))
        );
        require(ok && data.length >= 32, "balance 0 failed");
        return abi.decode(data, (uint256));
    }

    function _bal1() private view returns (uint256) {
        (bool ok, bytes memory data) = coin1.staticcall(
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(this))
        );
        require(ok && data.length >= 32, "balance 1 failed");
        return abi.decode(data, (uint256));
    }

    function add_liquidity(uint256 d0, uint256 d1, uint256 min_lp, address dst)
        external
        lock
        returns (uint256 lp, uint256 fee0, uint256 fee1)
    {
        require(d0 > 0 || d1 > 0, "d0 = 0 and d1 = 0");
        require(dst != address(0), "dst = 0 address");

        uint256 w = get_w();
        uint256 dw = W - w;
        // Old balances
        (uint256 b0, uint256 b1) = get_balances();
        // New balances
        uint256 c0 = b0 + d0;
        uint256 c1 = b1 + d1;

        uint256 v20 = Math.calc_v2(b0 * n0, b1 * n1, w, dw);
        uint256 v21 = Math.calc_v2(c0 * n0, c1 * n1, w, dw);
        require(v21 >= v20, "v2");

        uint256 s = totalSupply;
        uint256 v0 = Math.sqrt(v20);
        uint256 v1 = Math.sqrt(v21);
        if (v0 > 0) {
            fee0 = Math.abs_uint(c0, b0 * v1 / v0) * fee / F;
            fee1 = Math.abs_uint(c1, b1 * v1 / v0) * fee / F;
            uint256 v22 =
                Math.calc_v2((c0 - fee0) * n0, (c1 - fee1) * n1, w, dw);
            uint256 v2 = Math.sqrt(v22);
            // TODO: if v2 > 1e18 and v0 = 1?
            lp = s * (v2 - v0) / v0;
        } else {
            lp = v1;
        }

        _set_balances(c0, c1);

        require(lp >= min_lp, "lp < min");
        _mint(dst, lp);

        if (d0 > 0) {
            IERC20(coin0).transferFrom(msg.sender, address(this), d0);
        }
        if (d1 > 0) {
            IERC20(coin1).transferFrom(msg.sender, address(this), d1);
        }
    }

    function remove_liquidity(
        uint256 lp,
        uint256 min0,
        uint256 min1,
        address dst
    ) external lock returns (uint256 d0, uint256 d1) {
        require(lp > 0, "lp = 0");
        require(dst != address(0), "dst = 0 address");

        (uint256 b0, uint256 b1) = get_balances();
        uint256 s = totalSupply;

        d0 = b0 * lp / s;
        d1 = b1 * lp / s;

        require(d0 >= min0, "d0 < min");
        require(d1 >= min1, "d1 < min");

        _set_balances(b0 - d0, b1 - d1);
        _burn(msg.sender, lp);

        if (d0 > 0) {
            IERC20(coin0).transfer(dst, d0);
        }
        if (d1 > 0) {
            IERC20(coin1).transfer(dst, d1);
        }
    }

    function swap(uint256 d_in, uint256 d_out, bool zero_for_one, address dst)
        external
        lock
        returns (uint256, uint256)
    {
        require(d_in > 0, "d_in = 0");
        require(dst != address(0), "dst = 0 address");

        uint256 w = get_w();
        uint256 dw = W - w;

        (uint256 b0, uint256 b1) = get_balances();
        uint256 c0 = b0;
        uint256 c1 = b1;
        uint256 f = d_out * fee / F;
        d_out -= f;

        uint256 v20 = Math.calc_v2(b0 * n0, b1 * n1, w, dw);
        if (zero_for_one) {
            c0 += d_in;
            c1 -= d_out;
        } else {
            c0 -= d_out;
            c1 += d_in;
        }
        uint256 v21 = Math.calc_v2(c0 * n0, c1 * n1, w, dw);
        require(v21 >= v20, "v2");

        _set_balances(c0, c1);

        if (zero_for_one) {
            require(_bal0() - b0 >= d_in, "d_in");
            IERC20(coin1).transfer(dst, d_out);
        } else {
            require(_bal1() - b1 >= d_in, "d_in");
            IERC20(coin0).transfer(dst, d_out);
        }

        return (d_out, f);
    }

    function skim() external auth {
        (uint256 b0, uint256 b1) = get_balances();
        uint256 bal0 = _bal0();
        uint256 bal1 = _bal1();
        if (bal0 > b0) {
            IERC20(coin0).transfer(msg.sender, bal0 - b0);
        }
        if (bal1 > b1) {
            IERC20(coin1).transfer(msg.sender, bal1 - b1);
        }
    }
}
