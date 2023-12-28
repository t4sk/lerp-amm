// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

uint256 constant W = 1e5;
uint256 constant F = 1e18;
uint256 constant U = 1e18;
int256 constant I = 1e18;

library Math {
    // Copied from https://github.com/Vectorized/solady/blob/main/src/utils/FixedPointMathLib.sol
    /// @dev Returns the square root of `x`.
    function sqrt(uint256 x) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // `floor(sqrt(2**15)) = 181`. `sqrt(2**15) - 181 = 2.84`.
            z := 181 // The "correct" value is 1, but this saves a multiplication later.

            // This segment is to get a reasonable initial estimate for the Babylonian method. With a bad
            // start, the correct # of bits increases ~linearly each iteration instead of ~quadratically.

            // Let `y = x / 2**r`. We check `y >= 2**(k + 8)`
            // but shift right by `k` bits to ensure that if `x >= 256`, then `y >= 256`.
            let r := shl(7, lt(0xffffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffffff, shr(r, x))))
            z := shl(shr(1, r), z)

            // Goal was to get `z*z*y` within a small factor of `x`. More iterations could
            // get y in a tighter range. Currently, we will have y in `[256, 256*(2**16))`.
            // We ensured `y >= 256` so that the relative difference between `y` and `y+1` is small.
            // That's not possible if `x < 256` but we can just verify those cases exhaustively.

            // Now, `z*z*y <= x < z*z*(y+1)`, and `y <= 2**(16+8)`, and either `y >= 256`, or `x < 256`.
            // Correctness can be checked exhaustively for `x < 256`, so we assume `y >= 256`.
            // Then `z*sqrt(y)` is within `sqrt(257)/sqrt(256)` of `sqrt(x)`, or about 20bps.

            // For `s` in the range `[1/256, 256]`, the estimate `f(s) = (181/1024) * (s+1)`
            // is in the range `(1/2.84 * sqrt(s), 2.84 * sqrt(s))`,
            // with largest error when `s = 1` and when `s = 256` or `1/256`.

            // Since `y` is in `[256, 256*(2**16))`, let `a = y/65536`, so that `a` is in `[1/256, 256)`.
            // Then we can estimate `sqrt(y)` using
            // `sqrt(65536) * 181/1024 * (a + 1) = 181/4 * (y + 65536)/65536 = 181 * (y + 65536)/2**18`.

            // There is no overflow risk here since `y < 2**136` after the first branch above.
            z := shr(18, mul(z, add(shr(r, x), 65536))) // A `mul()` is saved from starting `z` at 181.

            // Given the worst case multiplicative error of 2.84 above, 7 iterations should be enough.
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))

            // If `x+1` is a perfect square, the Babylonian method cycles between
            // `floor(sqrt(x))` and `ceil(sqrt(x))`. This statement ensures we return floor.
            // See: https://en.wikipedia.org/wiki/Integer_square_root#Using_only_integer_division
            z := sub(z, lt(div(x, z), z))
        }
    }

    // Copied from https://github.com/Vectorized/solady/blob/main/src/utils/FixedPointMathLib.sol
    /// @dev Calculates `floor(a * b / d)` with full precision.
    /// Throws if result overflows a uint256 or when `d` is zero.
    /// Credit to Remco Bloemen under MIT license: https://2π.com/21/muldiv
    function mul_div(uint256 x, uint256 y, uint256 d)
        internal
        pure
        returns (uint256 result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            for {} 1 {} {
                // 512-bit multiply `[p1 p0] = x * y`.
                // Compute the product mod `2**256` and mod `2**256 - 1`
                // then use the Chinese Remainder Theorem to reconstruct
                // the 512 bit result. The result is stored in two 256
                // variables such that `product = p1 * 2**256 + p0`.

                // Least significant 256 bits of the product.
                result := mul(x, y) // Temporarily use `result` as `p0` to save gas.
                let mm := mulmod(x, y, not(0))
                // Most significant 256 bits of the product.
                let p1 := sub(mm, add(result, lt(mm, result)))

                // Handle non-overflow cases, 256 by 256 division.
                if iszero(p1) {
                    if iszero(d) {
                        mstore(0x00, 0xae47f702) // `FullMulDivFailed()`.
                        revert(0x1c, 0x04)
                    }
                    result := div(result, d)
                    break
                }

                // Make sure the result is less than `2**256`. Also prevents `d == 0`.
                if iszero(gt(d, p1)) {
                    mstore(0x00, 0xae47f702) // `FullMulDivFailed()`.
                    revert(0x1c, 0x04)
                }

                /*------------------- 512 by 256 division --------------------*/

                // Make division exact by subtracting the remainder from `[p1 p0]`.
                // Compute remainder using mulmod.
                let r := mulmod(x, y, d)
                // `t` is the least significant bit of `d`.
                // Always greater or equal to 1.
                let t := and(d, sub(0, d))
                // Divide `d` by `t`, which is a power of two.
                d := div(d, t)
                // Invert `d mod 2**256`
                // Now that `d` is an odd number, it has an inverse
                // modulo `2**256` such that `d * inv = 1 mod 2**256`.
                // Compute the inverse by starting with a seed that is correct
                // correct for four bits. That is, `d * inv = 1 mod 2**4`.
                let inv := xor(2, mul(3, d))
                // Now use Newton-Raphson iteration to improve the precision.
                // Thanks to Hensel's lifting lemma, this also works in modular
                // arithmetic, doubling the correct bits in each step.
                inv := mul(inv, sub(2, mul(d, inv))) // inverse mod 2**8
                inv := mul(inv, sub(2, mul(d, inv))) // inverse mod 2**16
                inv := mul(inv, sub(2, mul(d, inv))) // inverse mod 2**32
                inv := mul(inv, sub(2, mul(d, inv))) // inverse mod 2**64
                inv := mul(inv, sub(2, mul(d, inv))) // inverse mod 2**128
                result :=
                    mul(
                        // Divide [p1 p0] by the factors of two.
                        // Shift in bits from `p1` into `p0`. For this we need
                        // to flip `t` such that it is `2**256 / t`.
                        or(
                            mul(sub(p1, gt(r, result)), add(div(sub(0, t), t), 1)),
                            div(sub(result, r), t)
                        ),
                        // inverse mod 2**256
                        mul(inv, sub(2, mul(d, inv)))
                    )
                break
            }
        }
    }

    function rpow(uint256 x, uint256 n, uint256 b)
        internal
        pure
        returns (uint256 z)
    {
        assembly {
            switch x
            case 0 {
                switch n
                case 0 { z := b }
                default { z := 0 }
            }
            default {
                switch mod(n, 2)
                case 0 { z := b }
                default { z := x }

                let half := div(b, 2)
                for { n := div(n, 2) } n { n := div(n, 2) } {
                    let xx := mul(x, x)
                    if iszero(eq(div(xx, x), x)) { revert(0, 0) }
                    let xxRound := add(xx, half)
                    if lt(xxRound, xx) { revert(0, 0) }
                    x := div(xxRound, b)
                    if mod(n, 2) {
                        let zx := mul(z, x)
                        if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) {
                            revert(0, 0)
                        }
                        let zxRound := add(zx, half)
                        if lt(zxRound, zx) { revert(0, 0) }
                        z := div(zxRound, b)
                    }
                }
            }
        }
    }

    function min_uint(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x <= y ? x : y;
    }

    function min_int(int256 x, int256 y) internal pure returns (int256 z) {
        z = x <= y ? x : y;
    }

    function max_uint(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x >= y ? x : y;
    }

    function max_int(int256 x, int256 y) internal pure returns (int256 z) {
        z = x >= y ? x : y;
    }

    function abs_uint(uint256 x, uint256 y) internal pure returns (uint256) {
        return x >= y ? x - y : y - x;
    }

    function abs_int(int256 x) internal pure returns (uint256) {
        return x >= 0 ? uint256(x) : uint256(-x);
    }

    function lerp_w(uint256 w0, uint256 w1, uint256 t0, uint256 t1, uint256 t)
        internal
        pure
        returns (uint256 w)
    {
        if (t >= t1) {
            return w1;
        }
        if (w0 < w1) {
            return w0 + (w1 - w0) * (t - t0) / (t1 - t0);
        }
        if (w0 > w1) {
            return w0 - (w0 - w1) * (t - t0) / (t1 - t0);
        }
        return w1;
    }

    // xy((1-w) + 4w)(x+y)^2 = v^2((1-w)(x+y)^2 + 4w4xy)
    // w = 0 -> xy = v^2
    // w = 1 -> (x+y)^2 = (2v)^2
    function calc_v2(uint256 x, uint256 y, uint256 w, uint256 dw)
        internal
        pure
        returns (uint256 v2)
    {
        if (w == 0) {
            return x * y;
        }
        if (w == W) {
            return (x + y) ** 2 / 4;
        }
        if (x == 0 || y == 0) {
            return 0;
        }
        // v2 = p*(dw + 4*w)*s2 / (dw*s2 + 16*w*p)
        uint256 p = x * y;
        uint256 s2 = (x + y) ** 2;
        // W * U^2
        v2 = mul_div(p * (dw + 4 * w), s2, dw * s2 + 16 * w * p);
    }

    function f(int256 x, int256 y, int256 w, int256 dw, int256 v2)
        internal
        pure
        returns (int256 z)
    {
        // TODO: return early if w = 0 or w = 1
        int256 p = x * y;
        int256 s2 = (x + y) ** 2;
        int256 l = s2 > 0
            ? int256(
                mul_div(
                    uint256(p * (dw + 4 * w)),
                    uint256(s2),
                    uint256(dw * s2 + 16 * w * p)
                )
            )
            : int256(0);
        z = (l - v2) / I;
    }

    // Secant method
    // x = token in
    // y = token out
    function calc_y(
        int256 x,
        int256 y0,
        int256 y1,
        int256 w,
        int256 dw,
        int256 v2
    ) internal pure returns (int256 y, uint256 i) {
        // TODO: return early if w = 0 or w = 1
        // if (w == 0) {
        //     x*(y0 - dy) = v2
        //     y0 - v2 / x = dy
        // }
        // if (w == 1) {
        //     v = Math.sqrt(v2)
        //     x + (y0 - dy) = 2v
        //     dy = x + y0 - 2v
        // }

        int256 f0 = f(x, y0, w, dw, v2);
        if (f0 == 0) {
            return (y0, 0);
        }
        int256 f1 = 0;
        int256 y2 = 0;
        while (i < 255) {
            f1 = f(x, y1, w, dw, v2);
            if (f1 == 0 || f1 == f0) {
                return (y1, i);
            }
            y2 = max_int(y1 - f1 * (y1 - y0) / (f1 - f0), 0);
            y0 = y1;
            y1 = y2;
            f0 = f1;
            unchecked {
                ++i;
            }
        }
        revert("f != 0");
    }

    // TODO: newton's method
}
