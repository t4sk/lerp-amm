// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../src/Math.sol";

contract MathTest is Test {
    uint256 constant M = 2 ** 100;

    function test_max_uint(uint256 x, uint256 y) public {
        assertEq(Math.max_uint(x, y), x >= y ? x : y);
    }

    function test_max_int(int256 x, int256 y) public {
        assertEq(Math.max_int(x, y), x >= y ? x : y);
    }

    function test_abs_uint(uint256 x, uint256 y) public {
        assertEq(Math.abs_uint(x, y), x >= y ? x - y : y - x);
    }

    function test_abs_int(int256 x) public {
        x = bound(x, type(int256).min + 1, type(int256).max);
        assertEq(Math.abs_int(x), x >= 0 ? uint256(x) : uint256(-x));
    }

    function test_lerp_w() public {
        uint256[6][6] memory tests = [
            // w0, w1, t0, t1, t, expected w
            // w0 < w1
            [0, W, 0, 100, 0, 0],
            [0, W, 0, 100, 50, W / 2],
            [0, W, 0, 100, 100, W],
            // w1 < w0
            [W, 0, 0, 100, 0, W],
            [W, 0, 0, 100, 50, W / 2],
            [W, 0, 0, 100, 100, 0]
        ];

        for (uint256 i = 0; i < tests.length; i++) {
            uint256 w0 = tests[i][0];
            uint256 w1 = tests[i][1];
            uint256 t0 = tests[i][2];
            uint256 t1 = tests[i][3];
            uint256 t = tests[i][4];
            uint256 w = tests[i][5];
            assertEq(Math.lerp_w(w0, w1, t0, t1, t), w);
        }
    }

    function test_lerp_w_fuzz(
        uint256 w0,
        uint256 w1,
        uint256 t0,
        uint256 t1,
        uint256 t
    ) public {
        w0 = bound(w0, 0, W);
        w1 = bound(w1, 0, W);
        t0 = bound(t0, 0, type(uint32).max);
        t1 = bound(t1, 0, type(uint32).max);
        if (t0 > t1) {
            (t0, t1) = (t1, t0);
        }
        t = bound(t, t0, t1);

        uint256 w = Math.lerp_w(w0, w1, t0, t1, t);
        assertGe(w, 0);
        assertLe(w, W);
        if (w0 <= w1) {
            assertGe(w, w0);
            assertLe(w, w1);
        } else {
            assertLe(w, w0);
            assertGe(w, w1);
        }
    }

    function test_v2_f_fuzz(uint256 x, uint256 y, uint256 w) public {
        x = bound(x, 1e6, 1e32);
        y = bound(y, 1e6, 1e32);
        w = bound(w, 0, W);
        uint256 dw = W - w;

        uint256 v2 = Math.calc_v2(x, y, w, dw);
        int256 f =
            Math.f(int256(x), int256(y), int256(w), int256(dw), int256(v2));

        assertEq(f, 0);
    }

    function test_calc_v2() public {
        uint256[4][16] memory tests = [
            // x, y, w, v2
            [U, U, 0, U * U],
            [M, M, 0, M * M],
            [U, U, W, (U + U) ** 2 / 4],
            [M, M, W, (M + M) ** 2 / 4],
            [U, U, 0.1 * 1e5, (U + U) ** 2 / 4],
            [M, M, 0.1 * 1e5, (M + M) ** 2 / 4],
            [U, U, 0.2 * 1e5, (U + U) ** 2 / 4],
            [M, M, 0.2 * 1e5, (M + M) ** 2 / 4],
            [U, U, 0.5 * 1e5, (U + U) ** 2 / 4],
            [M, M, 0.5 * 1e5, (M + M) ** 2 / 4],
            [M, 0, 0.5 * 1e5, 0],
            [0, M, 0.5 * 1e5, 0],
            [U, U, 0.8 * 1e5, (U + U) ** 2 / 4],
            [M, M, 0.8 * 1e5, (M + M) ** 2 / 4],
            [U, U, 0.9 * 1e5, (U + U) ** 2 / 4],
            [M, M, 0.9 * 1e5, (M + M) ** 2 / 4]
        ];

        for (uint256 i = 0; i < tests.length; i++) {
            uint256 x = tests[i][0];
            uint256 y = tests[i][1];
            uint256 w = tests[i][2];
            uint256 v2 = tests[i][3];
            uint256 dw = W - w;
            assertEq(Math.calc_v2(x, y, w, dw), v2);
        }
    }

    function test_calc_v2_fuzz(uint256 x, uint256 y, uint256 w) public {
        x = bound(x, 0, M);
        y = bound(y, 0, M);
        w = bound(w, 0, W);
        uint256 dw = W - w;

        uint256 v2 = Math.calc_v2(x, y, w, dw);

        if (w == 0) {
            assertEq(v2, x * y);
        } else if (w == W) {
            assertEq(v2, (x + y) ** 2 / 4);
        } else {
            if (x == 0 || y == 0) {
                assertEq(v2, 0);
            } else {
                uint256 min = Math.min_uint(x, y);
                uint256 max = Math.max_uint(x, y);
                assertGe(v2, (min + min) ** 2 / 4);
                assertLe(v2, (max + max) ** 2 / 4);
            }
        }
    }

    function test_f() public {
        uint256[3][8] memory tests = [
            // x, y, w
            [uint256(0), 0, 0],
            [M, M, 0],
            [M, M, W],
            [M, M, 0.1 * 1e5],
            [M, M, 0.2 * 1e5],
            [M, M, 0.5 * 1e5],
            [M, M, 0.8 * 1e5],
            [M, M, 0.9 * 1e5]
        ];

        for (uint256 i = 0; i < tests.length; i++) {
            uint256 x = tests[i][0];
            uint256 y = tests[i][1];
            uint256 w = tests[i][2];
            uint256 dw = W - w;
            uint256 v2 = Math.calc_v2(x, y, w, dw);
            assertEq(
                Math.f(int256(x), int256(y), int256(w), int256(dw), int256(v2)),
                0
            );
        }
    }

    function test_f_fuzz(uint256 x, uint256 y, uint256 w) public {
        x = bound(x, 0, M);
        y = bound(y, 0, M);
        w = bound(w, 0, W);
        uint256 dw = W - w;
        uint256 v2 = Math.calc_v2(x, y, w, dw);
        assertEq(
            Math.f(int256(x), int256(y), int256(w), int256(dw), int256(v2)), 0
        );
    }

    function test_calc_y() public {
        uint256 x = 1e32;
        uint256 y0 = 1e32;
        uint256 w = W * 70 / 100;
        uint256 dw = W - w;

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
        uint256 w = W * 70 / 100;
        uint256 dw = W - w;
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
