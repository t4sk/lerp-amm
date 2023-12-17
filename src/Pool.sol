// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./Math.sol";

// TODO: vyper
// TODO: erc20
contract Pool {
    struct Weight {
        uint64 w0;
        uint64 w1;
        uint32 w0_time;
        uint32 w1_time;
    }

    address public immutable coin0;
    address public immutable coin1;
    // Multiplier to normalize coin 0 and coin 1 to 18 decimals
    uint256 public immutable n0;
    uint256 public immutable n1;

    uint32 private constant MIN_W_DT = 24 * 3600;

    bool private locked;
    Weight public weight;

    // TODO: single slot?
    uint256 public balance0;
    uint256 public balance1;

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
        require(w <= W, "w > max");
        require(f <= W, "fee > max");
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
        return Math.calc_w(
            uint256(w.w0),
            uint256(w.w1),
            uint256(w.w0_time),
            uint256(w.w1_time),
            block.timestamp
        );
    }

    // TODO: auth
    function set_w(uint64 w1, uint32 w1_time) external {
        require(w1 <= W, "w > max");
        require(w1_time >= block.timestamp + MIN_W_DT, "w1 time < min");
        uint256 w = get_w();
        weight.w0 = uint64(w);
        weight.w1 = w1;
        weight.w0_time = uint32(block.timestamp);
        weight.w1_time = w1_time;
    }

    function stop_w() external {
        uint256 w = get_w();
        weight.w0 = uint64(w);
        weight.w1 = uint64(w);
        weight.w0_time = uint32(block.timestamp);
        weight.w1_time = uint32(block.timestamp);
    }

    function add_liquidity(uint256 d0, uint256 d1, uint256 min_lp)
        external
        lock
        returns (uint256 lp, uint256 fee0, uint256 fee1)
    {
        // TODO: input validation
        uint256 w = get_w();
        uint256 dw = W - w;
        // Old balances
        uint256 b0 = balance0;
        uint256 b1 = balance1;
        // New balances
        uint256 c0 = b0;
        uint256 c1 = b1;

        uint256 v20 = Math.calc_v2(c0 * n0, c1 * n1, w, dw);
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
            fee0 = Math.abs_diff(c0, b0 * v1 / v0) * fee / W;
            fee1 = Math.abs_diff(c1, b1 * v1 / v0) * fee / W;
            c0 -= fee0;
            c1 -= fee1;
            uint256 v22 = Math.calc_v2(c0 * n0, c1 * n1, w, dw);
            uint256 v2 = Math.sqrt(v22);
            // TODO: invariant test v1 >= v0
            // TODO: invariant test v0 > 0
            lp = s * (v2 - v0) / v0;
        } else {
            lp = v1;
        }

        balance0 = c0;
        balance1 = c1;

        require(lp >= min_lp, "lp < min");
        _mint(msg.sender, lp);
    }

    function remove_liquidity(uint256 lp, uint256 min_d0, uint256 min_d1)
        external
        lock
        returns (uint256 d0, uint256 d1)
    {
        // TODO: input validation
        // TODO: use token balance?
        uint256 c0 = balance0;
        uint256 c1 = balance1;

        d0 = c0 * lp / total_supply;
        d1 = c1 * lp / total_supply;

        require(d0 >= min_d0, "d0 < min");
        require(d1 >= min_d1, "d1 < min");

        c0 -= d0;
        c1 -= d1;

        balance0 = c0;
        balance1 = c1;

        _burn(msg.sender, lp);
    }

    // TODO: return dy and fee?
    function swap(uint256 dx, uint256 dy, bool zero_for_one) external lock {
        // TODO: input validation
        uint256 w = get_w();
        uint256 dw = W - w;

        uint256 c0 = balance0;
        uint256 c1 = balance1;
        uint256 fee0 = 0;
        uint256 fee1 = 0;

        uint256 v20 = Math.calc_v2(c0 * n0, c1 * n1, w, dw);
        if (zero_for_one) {
            fee1 = dy * fee / W;
            c0 += dx;
            c1 -= (dy - fee1);
        } else {
            fee0 = dy * fee / W;
            c0 -= (dy - fee0);
            c1 += dx;
        }
        uint256 v21 = Math.calc_v2(c0 * n0, c1 * n1, w, dw);

        require(v21 >= v20, "v");

        balance0 = c0 + fee0;
        balance1 = c1 + fee1;
        // TODO: require balance of coin 0 and 1 >= b0 and b1
    }
}
