// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./Math.sol";
import "forge-std/Test.sol";

// TODO: vyper
// TODO: erc20
contract Pool {
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

    bool private locked;
    Weight public weight;
    Balances private balances;
    // TODO: dynamic fee
    uint256 public fee;

    uint256 public total_supply;
    mapping(address => uint256) public balance_of;

    modifier lock() {
        require(!locked, "locked");
        locked = true;
        _;
        locked = false;
    }

    constructor(uint64 w, uint256 f) {
        require(w <= MAX_W, "w > max");
        require(f <= MAX_FEE, "fee > max");
        coin0 = address(1);
        coin1 = address(2);
        n0 = 1;
        n1 = 10 ** 12;
        weight = Weight({
            w0: w,
            w1: w,
            w0_time: uint32(block.timestamp),
            w1_time: uint32(block.timestamp)
        });
        fee = f;
    }

    function _mint(address dst, uint256 amount) private {
        balance_of[dst] += amount;
        total_supply += amount;
    }

    function _burn(address src, uint256 amount) private {
        balance_of[src] -= amount;
        total_supply -= amount;
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

    function set_fee(uint256 f) external {
        require(f <= MAX_FEE, "fee > max");
        fee = f;
    }

    // TODO: auth
    function set_w(uint64 w1, uint32 w1_time) external {
        require(w1 <= MAX_W, "w > max");
        require(w1_time >= uint32(block.timestamp) + MIN_W_DT, "w1 time < min");
        uint64 w = uint64(get_w());
        weight.w0 = w;
        weight.w1 = w1;
        weight.w0_time = uint32(block.timestamp);
        weight.w1_time = w1_time;
    }

    function stop_w() external {
        uint64 w = uint64(get_w());
        weight.w0 = w;
        weight.w1 = w;
        weight.w0_time = uint32(block.timestamp);
        weight.w1_time = uint32(block.timestamp);
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

    function add_liquidity(uint256 d0, uint256 d1, uint256 min_lp)
        external
        lock
        returns (uint256 lp, uint256 fee0, uint256 fee1)
    {
        // TODO: input validation
        uint256 w = get_w();
        uint256 dw = MAX_W - w;
        // Old balances
        (uint256 b0, uint256 b1) = get_balances();
        // New balances
        uint256 c0 = b0;
        uint256 c1 = b1;

        uint256 v20 = Math.calc_v2(b0 * n0, b1 * n1, w, dw);
        c0 += d0;
        c1 += d1;
        uint256 v21 = Math.calc_v2(c0 * n0, c1 * n1, w, dw);
        require(v21 >= v20, "v21 < v20");

        // TODO: imbalance fee?
        // w = 0 -> xy = v^2
        // w = 1 -> (x+y)^2 = (2v)^2
        uint256 s = total_supply;
        uint256 v0 = Math.sqrt(v20);
        uint256 v1 = Math.sqrt(v21);
        if (s > 0) {
            // TODO: require v0 > 0?
            fee0 = Math.abs_diff(c0, b0 * v1 / v0) * fee / MAX_FEE;
            fee1 = Math.abs_diff(c1, b1 * v1 / v0) * fee / MAX_FEE;
            uint256 v22 = Math.calc_v2(c0 * n0, c1 * n1, w, dw);
            uint256 v2 = Math.sqrt(v22);
            // TODO: invariant test v1 >= v0
            // TODO: invariant test v0 > 0
            lp = s * (v2 - v0) / v0;
        } else {
            lp = v1;
        }

        _set_balances(c0, c1);

        require(lp >= min_lp, "lp < min");
        _mint(msg.sender, lp);
    }

    function remove_liquidity(uint256 lp, uint256 min0, uint256 min1)
        external
        lock
        returns (uint256 d0, uint256 d1)
    {
        // TODO: input validation
        // TODO: use token balance?
        (uint256 b0, uint256 b1) = get_balances();

        d0 = b0 * lp / total_supply;
        d1 = b1 * lp / total_supply;

        require(d0 >= min0, "d0 < min");
        require(d1 >= min1, "d1 < min");

        _set_balances(b0 - d0, b1 - d1);
        _burn(msg.sender, lp);
    }

    // TODO: return dy and fee?
    function swap(uint256 d_in, uint256 d_out, bool zero_for_one)
        external
        lock
        returns (uint256, uint256)
    {
        // TODO: input validation
        uint256 w = get_w();
        uint256 dw = MAX_W - w;

        (uint256 b0, uint256 b1) = get_balances();
        uint256 f = d_out * fee / MAX_FEE;
        d_out -= f;

        uint256 v20 = Math.calc_v2(b0 * n0, b1 * n1, w, dw);
        if (zero_for_one) {
            b0 += d_in;
            b1 -= d_out;
        } else {
            b0 -= d_out;
            b1 += d_in;
        }
        uint256 v21 = Math.calc_v2(b0 * n0, b1 * n1, w, dw);
        require(v21 >= v20, "v");

        zero_for_one ? b1 += f : b0 += f;
        _set_balances(b0, b1);
        // TODO: require balance of coin 0 and 1 >= b0 and b1

        return (d_out, f);
    }
}
