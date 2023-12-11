// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./Math.sol";

contract Pool {
    address public immutable coin0;
    address public immutable coin1;

    uint256 public immutable n0;
    uint256 public immutable n1;

    uint256 private constant MIN_W_DT = 24 * 3600;
    // TODO: single slot
    uint256 public w0;
    uint256 public w1;
    uint256 public w0_time;
    uint256 public w1_time;

    // TODO: single slot?
    uint256 public b0;
    uint256 public b1;

    uint256 public total_supply;
    mapping(address => uint256) public balance_of;

    // TODO: fee

    constructor(uint256 w) {
        require(w <= W, "w > max");
        coin0 = address(1);
        coin1 = address(2);
        n0 = 1;
        n1 = 10 ** 12;
        w0 = w;
        w1 = w;
        w0_time = block.timestamp;
        w1_time = block.timestamp;
    }

    function _mint(address dst, uint256 amount) private {
        balance_of[dst] += amount;
        total_supply += amount;
    }

    function _burn(address src, uint256 amount) private {
        balance_of[src] -= amount;
        total_supply -= amount;
    }

    function get_w() public view returns (uint256 w) {
        w = Math.calc_w(w0, w1, w0_time, w1_time, block.timestamp);
    }

    function set_w(uint256 _w1, uint256 _w1_time) external {
        require(_w1 <= W, "w > max");
        require(_w1_time >= block.timestamp + MIN_W_DT, "w1 time < min");
        uint256 w = get_w();
        w0 = w;
        w1 = _w1;
        w0_time = block.timestamp;
        w1_time = _w1_time;
    }

    function stop_w() external {
        uint256 w = get_w();
        w0 = w;
        w1 = w;
        w0_time = block.timestamp;
        w1_time = block.timestamp;
    }

    function add_liquidity(uint256 d0, uint256 d1, uint256 min_lp)
        external
        returns (uint256 lp)
    {
        uint256 w = get_w();
        uint256 dw = W - w;
        uint256 x0 = b0;
        uint256 x1 = b1;

        uint256 v20 = Math.calc_v2(x0 * n0, x1 * n1, w, dw);
        x0 += d0;
        x1 += d1;
        uint256 v21 = Math.calc_v2(x0 * n0, x1 * n1, w, dw);

        // TODO: imbalance fee? or require x0 = x1
        b0 = x0;
        b1 = x1;

        if (total_supply == 0) {
            lp = Math.sqrt(v21);
        } else {
            uint256 v0 = Math.sqrt(v20);
            uint256 v1 = Math.sqrt(v21);
            lp = total_supply * (v1 - v0) / v0;
        }
        require(lp >= min_lp, "lp < min");
        _mint(msg.sender, lp);
    }

    function remove_liquidity(uint256 lp, uint256 min_d0, uint256 min_d1)
        external
        returns (uint256 d0, uint256 d1)
    {
        uint256 x0 = b0;
        uint256 x1 = b1;

        d0 = x0 * lp / total_supply;
        d1 = x1 * lp / total_supply;

        require(d0 >= min_d0, "d0 < min");
        require(d1 >= min_d1, "d1 < min");

        x0 -= d0;
        x1 -= d1;

        b0 = x0;
        b1 = x1;

        _burn(msg.sender, lp);
    }

    function swap(uint256 dx, uint256 dy, bool zero_for_one) external {
        uint256 w = get_w();
        uint256 dw = W - w;

        uint256 x0 = b0;
        uint256 x1 = b1;

        uint256 v20 = Math.calc_v2(x0 * n0, x1 * n1, w, dw);
        if (zero_for_one) {
            x0 += dx;
            x1 -= dy;
        } else {
            x0 -= dy;
            x1 += dx;
        }
        uint256 v21 = Math.calc_v2(x0 * n0, x1 * n1, w, dw);

        require(v21 >= v20, "v");

        b0 = x0;
        b1 = x1;
    }
}
