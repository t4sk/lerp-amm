# pragma version ^0.4.0

# xy = (w + (1 - w)z)v^2
# z = 4xy / (x + y)^2
# 0 <= w <= 1

U: constant(uint256) = 10 ** 18
UU: constant(uint256) = 10 ** 36
W: constant(uint256) = 10 ** 5

@pure
def lerp(w0: uint64, w1: uint64, t0: uint64, t1: uint64, t: uint64) -> uint64:
   if t >= t1:
      return w1
   if w0 < w1:
      return w0 + (w1 - w0) * (t - t0) // (t1 - t0)
   if w0 > w1:
      return w0 - (w0 - w1) * (t - t0) // (t1 - t0)
   return w1

@pure
def calc_v2(x: uint256, y: uint256, w: uint256) -> uint256:
   if w == 0:
      return (x + y) ** 2 // 4
   if w == W:
      return x * y
   if x == 0 or y == 0:
      return 0
   
   p: uint256 = x * y
   s: uint256 = x + y
   z: uint256 = 4 * p * U // s * U // s
   d: uint256 = (w * UU + (W - w) * z) // W
   return p * UU // d
