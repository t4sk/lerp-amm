// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IPool} from "./interfaces/IPool.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import "./Math.sol";

import "forge-std/Test.sol";

contract Aux {
    address public immutable pool;
    address public immutable coin0;
    address public immutable coin1;
    uint256 public immutable n0;
    uint256 public immutable n1;

    constructor(address _pool) {
        pool = _pool;
        coin0 = IPool(pool).coin0();
        coin1 = IPool(pool).coin1();
        n0 = IPool(pool).n0();
        n1 = IPool(pool).n1();
    }

    function _swap(
        address src,
        address dst,
        uint256 d_in,
        uint256 min_out,
        bool zero_for_one
    ) private returns (uint256 out, uint256 fee) {
        // TODO: require(min_out > 0, "min out = 0");

        (uint256 b0, uint256 b1) = IPool(pool).get_balances();
        uint256 w = IPool(pool).get_w();
        uint256 dw = MAX_W - w;

        uint256 x0 = b0 * n0;
        uint256 x1 = b1 * n1;

        uint256 d_out = 0;
        uint256 v2 = Math.calc_v2(x0, x1, w, dw);
        if (zero_for_one) {
            (int256 iy,) = Math.calc_y(
                int256(x0 + d_in * n0),
                int256(x1),
                // TODO: good initial y1
                int256(x1 - Math.max(min_out * n1 / 2, 1)),
                int256(w),
                int256(dw),
                int256(v2)
            );
            d_out = (x1 - uint256(iy)) / n1;

            if (src == address(this)) {
                IERC20(coin0).transfer(address(pool), d_in);
            } else {
                IERC20(coin0).transferFrom(src, address(pool), d_in);
            }
        } else {
            (int256 iy,) = Math.calc_y(
                int256(x1 + d_in * n1),
                int256(x0),
                int256(x0 - Math.max(min_out * n0 / 2, 1)),
                int256(w),
                int256(dw),
                int256(v2)
            );
            d_out = (x0 - uint256(iy)) / n0;

            if (src == address(this)) {
                IERC20(coin1).transfer(address(pool), d_in);
            } else {
                IERC20(coin1).transferFrom(src, address(pool), d_in);
            }
        }

        (out, fee) = IPool(pool).swap(d_in, d_out, zero_for_one, dst);
        require(out >= min_out, "out < min");
    }

    function swap(uint256 d_in, uint256 min_out, bool zero_for_one)
        public
        returns (uint256 out, uint256 fee)
    {
        return _swap(msg.sender, msg.sender, d_in, min_out, zero_for_one);
    }

    function remove_liquidity_one_coin(uint256 lp, uint256 min_out, bool zero)
        external
        returns (uint256 out, uint256 fee)
    {
        IERC20(pool).transferFrom(msg.sender, address(this), lp);

        (uint256 d0, uint256 d1) =
            IPool(pool).remove_liquidity(lp, 0, 0, address(this));
        if (zero) {
            IERC20(coin0).transfer(msg.sender, d0);
            (out, fee) = _swap(address(this), msg.sender, d1, 0, !zero);
            out += d0;
        } else {
            IERC20(coin1).transfer(msg.sender, d1);
            (out, fee) = _swap(address(this), msg.sender, d0, 0, zero);
            out += d1;
        }
        require(out >= min_out, "out < min");
    }
}
