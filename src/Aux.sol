// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IPool} from "./interfaces/IPool.sol";
import "./Math.sol";

contract Aux {
    function swap(address pool, uint256 dx, uint256 min_dy, bool zero_for_one)
        external
        returns (uint256 dy)
    {
        uint256 b0 = IPool(pool).b0();
        uint256 b1 = IPool(pool).b1();
        uint256 n0 = IPool(pool).n0();
        uint256 n1 = IPool(pool).n1();
        uint256 w = IPool(pool).get_w();
        uint256 dw = W - w;

        uint256 x0 = b0 * n0;
        uint256 x1 = b1 * n1;

        uint256 v2 = Math.calc_v2(x0, x1, w, dw);
        uint256 y0 = 0;
        uint256 y1 = 0;
        if (zero_for_one) {
            y0 = x1;
            y1 = uint256(
                Math.calc_y(
                    int256(x0 + dx * n0),
                    int256(x1),
                    int256(x1 - min_dy * n1),
                    int256(w),
                    int256(dw),
                    int256(v2)
                )
            );
        } else {
            y0 = x0;
            y1 = uint256(
                Math.calc_y(
                    int256(x1 + dx * n1),
                    int256(x0),
                    int256(x0 - min_dy * n0),
                    int256(w),
                    int256(dw),
                    int256(v2)
                )
            );
        }
        dy = y0 - y1;

        require(dy >= min_dy, "dy < min");
        IPool(pool).swap(dx, dy, zero_for_one);
    }
}
