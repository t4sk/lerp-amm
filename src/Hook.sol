// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./lib/ERC20.sol";
import "./Math.sol";
import "./interfaces/IPool.sol";

contract Hook {
    uint256 private constant A = 1e18;
    uint256 private constant R = 1e27;
    uint256 private constant H = 0.5 * 1e27;

    address public immutable pool;
    address public immutable coin0;
    address public immutable coin1;
    uint256 public immutable n0;
    uint256 public immutable n1;
    address public owner;
    uint256 public half_life;
    // EMA of x1 / x0
    uint256 public last_ema;
    uint256 public ema;
    uint256 public updated_at;
    uint256 public last_price;

    modifier auth() {
        require(msg.sender == owner, "not authorized");
        _;
    }

    modifier only_pool() {
        require(msg.sender == pool, "not authorized");
        _;
    }

    constructor(address _pool) {
        pool = _pool;
        coin0 = IPool(pool).coin0();
        coin1 = IPool(pool).coin1();
        n0 = IPool(pool).n0();
        n1 = IPool(pool).n1();
        half_life = 3600;
        ema = R;
        last_ema = R;
        last_price = R;
        updated_at = block.timestamp;
    }

    function set_owner(address _owner) external auth {
        owner = _owner;
    }

    function set_half_life(uint256 h) external auth {
        require(h >= 30, "h < min");
        require(h <= 365 * 24 * 3600, "h > max");
        half_life = h;
    }

    function alpha(uint256 t0, uint256 t1) public view returns (uint256) {
        // TODO: scale up dt / half_life?
        return A - Math.rpow(H, (t1 - t0) / half_life, R) / 1e9;
    }

    function get_ema() public view returns (uint256 p, uint256 t) {
        t = updated_at;
        uint256 a = alpha(t, block.timestamp);
        p = (last_price * a + (A - a) * last_ema) / A;
    }

    function after_swap(
        uint256 d_in,
        uint256 d_out,
        uint256 fee,
        bool zero_for_one
    ) external only_pool {
        // TODO: fee = 0 ?
        fee = 0;
        uint256 a = alpha(updated_at, block.timestamp);
        // p = x1 / x0
        uint256 p = 0;
        if (zero_for_one) {
            p = (d_out + fee) * n1 * R / (d_in * n0);
        } else {
            p = (d_in * n0 * R) / ((d_out + fee) * n1);
        }
        last_ema = ema;
        last_price = p;
        ema = (p * a + (A - a) * ema) / A;
        updated_at = block.timestamp;
    }
}
