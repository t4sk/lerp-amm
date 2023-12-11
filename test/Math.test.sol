// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../src/Math.sol";

contract MathTest is Test {
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

    function test_calc_y() public {
        uint256 x = 1e32;
        uint256 y0 = 1e32;
        uint256 w = W * 70 / 100;
        uint256 dw = W - w;

        uint256 dx = 100 * 1e18;
        uint256 min_dy = 99 * 1e18;

        uint256 v2 = Math.calc_v2(x, y0, w, dw);

        uint256 y1 = uint256(
            Math.calc_y(
                int256(x + dx),
                int256(y0),
                int256(y0 - min_dy),
                int256(w),
                int256(dw),
                int256(v2)
            )
        );

        uint256 dy = y0 - y1;
        console.log("dy", dy);
    }
    // test f
    // test v2
    // test calc y
}
