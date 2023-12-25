// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../src/Math.sol";

contract MathTest is Test {
    // TODO: test f
    // TODO: test v2
    // TODO: test calc y

    function test_v2_f_fuzz(uint256 x, uint256 y, uint256 w) public {
        x = bound(x, 1e6, 1e32);
        y = bound(y, 1e6, 1e32);
        w = bound(w, 0, MAX_W);
        uint256 dw = MAX_W - w;

        uint256 v2 = Math.calc_v2(x, y, w, dw);
        int256 f =
            Math.f(int256(x), int256(y), int256(w), int256(dw), int256(v2));

        assertEq(f, 0);
    }

    function test_calc_y() public {
        uint256 x = 1e32;
        uint256 y0 = 1e32;
        uint256 w = MAX_W * 70 / 100;
        uint256 dw = MAX_W - w;

        uint256 dx = 100 * 1e18;
        uint256 min_dy = 99 * 1e18;

        uint256 v2 = Math.calc_v2(x, y0, w, dw);
        (int256 iy,) = Math.calc_y(
            int256(x + dx),
            int256(y0),
            int256(y0 - min_dy),
            int256(w),
            int256(dw),
            int256(v2)
        );
        uint256 y1 = uint256(iy);

        uint256 dy = y0 - y1;
        assertGe(dy, min_dy);
    }

    function test_calc_y_fuzz(uint256 x, uint256 y0, uint256 dx) public {
        x = bound(x, 1e6, 1e32);
        y0 = bound(y0, 1e6, 1e32);

        // y0 = x;
        uint256 w = MAX_W * 70 / 100;
        uint256 dw = MAX_W - w;
        dx = bound(dx, 1e6, 1e30);
        uint256 y1 = y0 >= dx / 2 ? y0 - dx / 2 : 1;

        uint256 v2 = Math.calc_v2(x, y0, w, dw);
        (int256 iy,) = calc_y(
            int256(x + dx),
            int256(y0),
            int256(y1),
            int256(w),
            int256(dw),
            int256(v2)
        );
        uint256 y2 = uint256(iy);

        assertLe(y2, y0, "y2 < y0");
        console.log("y0", y0);
        console.log("y2", y2);
        uint256 dy = (y0 - y2) * 999 / 1000;
        uint256 v21 = Math.calc_v2(x + dx, y0 - dy, w, dw);
        assertGe(v21, v2, "v21 < v2");
        console.log("v2", v2);
        console.log("v21", v21);
        // revert("DONE");
        // assertGe(dy, min_dy, "min dy");
    }

    function calc_y(
        int256 x,
        int256 y0,
        int256 y1,
        int256 w,
        int256 dw,
        int256 v2
    ) internal pure returns (int256 y, uint256 i) {
        int256 f0 = Math.f(x, y0, w, dw, v2);
        if (Math.abs_int(f0) <= 0) {
            return (y0, 0);
        }
        int256 f1 = 0;
        int256 y2 = 0;
        while (i < 255) {
            f1 = Math.f(x, y1, w, dw, v2);
            console2.log("------", i);
            console2.log("f0", f0);
            console2.log("f1", f1);
            console2.log("y0", y0);
            console2.log("y1", y1);
            if (Math.abs_int(f1) <= 0 || f1 == f0) {
                return (y1, i);
            }
            y2 = Math.max_int(y1 - f1 * (y1 - y0) / (f1 - f0), 0);
            // y2 = y1 - f1 * (y1 - y0) / (f1 - f0);
            y0 = y1;
            y1 = y2;
            f0 = f1;
            unchecked {
                ++i;
            }
        }
        revert("f != 0");
    }
}
