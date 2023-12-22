// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IPool} from "./interfaces/IPool.sol";
import "./Math.sol";

contract Aux {
    // TODO: add liquidity imbalanced
    // TODO: remove liquidity
    // TODO: remove liquidity one coin
    // TODO: gas and price compare with curve v1

    function swap(
        address pool,
        uint256 d_in,
        uint256 min_out,
        bool zero_for_one
    ) external returns (uint256 out, uint256 fee) {
        // require(min_out > 0, "min out = 0");

        (uint256 b0, uint256 b1) = IPool(pool).get_balances();
        uint256 n0 = IPool(pool).n0();
        uint256 n1 = IPool(pool).n1();
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
        }

        (out, fee) = IPool(pool).swap(d_in, d_out, zero_for_one);
        require(out >= min_out, "out < min");
    }
}
