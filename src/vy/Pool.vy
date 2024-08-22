# pragma version ^0.4.0
from ethereum.ercs import IERC20
import Math

coin0: public(immutable(address))
coin1: public(immutable(address))
n0: public(immutable(uint256))
n1: public(immutable(uint256))

w0: public(uint64)
w1: public(uint64)
t0: public(uint64)
t1: public(uint64)

# 100% = 10000
# 0.01% = 1
FEE: constant(uint256) = 30
W: constant(uint64) = 10 ** 5
MIN_W_DT: constant(uint64) = 24 * 3600

owner: public(address)

total_supply: public(uint256)
balance_of: public(HashMap[address, uint256])

b0: public(uint256)
b1: public(uint256)

@deploy
def __init__(
    _coin0: address,
    _coin1: address,
    dec0: uint256,
    dec1: uint256,
    w: uint64
):
    assert w <= W, "w > max"
    coin0 = _coin0
    coin1 = _coin1
    n0 = 10 ** (18 - dec0)
    n1 = 10 ** (18 - dec1)
    self.w0 = w
    self.w1 = w
    self.t0 = convert(block.timestamp, uint64)
    self.t1 = convert(block.timestamp, uint64)
    self.owner = msg.sender

@internal
@view
def w() -> uint64:
    return Math.lerp(
        self.w0, self.w1, self.t0, self.t1, convert(block.timestamp, uint64)
    )

@external
@view
def get_w() -> uint64:
    return self.w()

@external
def set_w(w1: uint64, t1: uint64):
    assert msg.sender == self.owner, "not auth"
    assert w1 <= W, "w > max"
    assert t1 >= convert(block.timestamp, uint64) + MIN_W_DT, "w1 time < min"
    self.w0 = self.w()
    self.w1 = w1
    self.t0 = convert(block.timestamp, uint64)
    self.t1 = t1

@external
def stop_w():
    assert msg.sender == self.owner, "not auth"
    w: uint64 = self.w()
    self.w0 = w
    self.w1 = w
    self.t0 = convert(block.timestamp, uint64)
    self.t1 = convert(block.timestamp, uint64)

@internal
@view
def bal0() -> uint256:
    return staticcall IERC20(coin0).balanceOf(self)

@internal
@view
def bal1() -> uint256:
    return staticcall IERC20(coin1).balanceOf(self)

@external
@nonreentrant
def swap(
    d_in: uint256, d_out: uint256, zero_for_one: bool, dst: address
) -> (uint256, uint256):
    assert d_in > 0, "d_in = 0"
    assert dst != empty(address), "dst = 0 address"

    w: uint256 = convert(self.w(), uint256)
    b0: uint256 = self.b0
    b1: uint256 = self.b1
    fee: uint256 = d_out * FEE // 10000 
    d_out_minus_fee: uint256 = d_out - fee

    v20: uint256 = Math.calc_v2(b0 * n0, b1 * n1, w)
    assert v20 > 0, "v2 = 0"

    if zero_for_one:
        b0 += d_in
        b1 -= d_out_minus_fee
    else:
        b0 -= d_out_minus_fee
        b1 += d_in

    v21: uint256 = Math.calc_v2(b0 * n0, b1 * n1, w)
    assert v21 > v20, "v21 <= v20"
    
    self.b0 = b0
    self.b1 = b1

    if zero_for_one:
        assert self.bal0() >= b0, "d_in"
        extcall IERC20(coin1).transfer(dst, d_out)
    else:
        assert self.bal1() >= b1, "d_in"
        extcall IERC20(coin0).transfer(dst, d_out)

    return (d_out_minus_fee, fee)

@internal
def mint(dst: address, amt: uint256):
    self.total_supply += amt
    self.balance_of[dst] += amt

@internal
def burn(src: address, amt: uint256):
    self.total_supply -= amt
    self.balance_of[src] -= amt

@external
def add_liquidity():
    pass

@external
def remove_liquidity(
    lp: uint256, min0: uint256, min1: uint256, dst: address
) -> (uint256, uint256):
    assert lp > 0, "lp = 0"
    assert dst != empty(address), "dst = 0 address"

    s: uint256 = self.total_supply
    b0: uint256 = self.b0
    b1: uint256 = self.b1

    d0: uint256 = b0 * lp // s
    d1: uint256 = b1 * lp // s

    assert d0 >= min0, "d0 < min"
    assert d1 >= min1, "d1 < min"

    self.b0 = b0 - d0
    self.b1 = b1 - d1

    self.burn(msg.sender, lp)

    if d0 > 0:
        extcall IERC20(coin0).transfer(dst, d0)
    if d1 > 0:
        extcall IERC20(coin1).transfer(dst, d1)

    return (d0, d1)

@external
def skim():
    bal0: uint256 = self.bal0()
    bal1: uint256 = self.bal1()
    b0: uint256 = self.b0
    b1: uint256 = self.b1
    if bal0 > b0:
        extcall IERC20(coin0).transfer(self.owner, bal0 - b0)
    if bal1 > b1:
        extcall IERC20(coin1).transfer(self.owner, bal1 - b1)