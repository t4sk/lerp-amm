// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../src/Math.sol";

contract MathTest is Test {
    uint256 constant M = 2 ** 104;

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
        // TODO: fuzz for x, y = 0
        x = bound(x, 1e6, M);
        y = bound(y, 1e6, M);
        w = bound(w, 0, W);
        uint256 dw = W - w;
        uint256 v2 = Math.calc_v2(x, y, w, dw);
        assertEq(
            Math.f(int256(x), int256(y), int256(w), int256(dw), int256(v2)), 0
        );
    }

    function test_calc_y() public {
        uint256 f = 0.999 * 1e18;
        uint256[4][5] memory tests = [
            // x, y0, w, dx
            [M, M, 0, 100 * 1e18],
            [M, M, 0.1 * 1e5, 100 * 1e18],
            [M, M, 0.5 * 1e5, 100 * 1e18],
            [M, M, 0.9 * 1e5, 100 * 1e18],
            [M, M, W, 100 * 1e18]
        ];

        for (uint256 i = 0; i < tests.length; i++) {
            uint256 x = tests[i][0];
            uint256 y0 = tests[i][1];
            uint256 w = tests[i][2];
            uint256 dx = tests[i][3];
            uint256 dw = W - w;

            uint256 y1 = y0 >= dx / 2 ? y0 - dx / 2 : y0 - 1;

            uint256 v20 = Math.calc_v2(x, y0, w, dw);
            (int256 iy,) = Math.calc_y(
                int256(x + dx),
                int256(y0),
                int256(y1),
                int256(w),
                int256(dw),
                int256(v20)
            );
            uint256 y2 = uint256(iy);

            assertGe(y0, y2, "y2 > y0");
            uint256 dy = (y0 - y2) * f / F;
            uint256 v21 = Math.calc_v2(x + dx, y0 - dy, w, dw);
            assertGe(v21, v20, "v21 < v20");
        }
    }

    function test_calc_y_fuzz(uint256 x, uint256 y0, uint256 w, uint256 dx)
        public
    {
        uint256 f = 0.999 * 1e18;
        x = bound(x, 1e6, M);
        y0 = bound(y0, 1e6, M);
        w = bound(w, 0, W);
        uint256 dw = W - w;

        // dx = 1e6;
        dx = bound(dx, 1, y0);
        uint256 y1 = y0 >= dx / 2 ? y0 - dx / 2 : y0 - 1;

        uint256 v20 = Math.calc_v2(x, y0, w, dw);
        (int256 iy,) = Math.calc_y(
            int256(x + dx),
            int256(y0),
            int256(y1),
            int256(w),
            int256(dw),
            int256(v20)
        );
        uint256 y2 = uint256(iy);

        assertGe(y0, y2, "y2 > y0");
        uint256 dy = (y0 - y2) * f / F;
        uint256 v21 = Math.calc_v2(x + dx, y0 - dy, w, dw);
        assertGe(v21, v20, "v21 < v20");
    }
}
