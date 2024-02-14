// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../src/Math.sol";
import {Pool} from "../src/Pool.sol";
import {Aux} from "../src/Aux.sol";
import {Coin} from "./lib/Coin.sol";

contract Handler is Test {
    uint256 private constant M0 = 1e9 * 1e18;
    uint256 private constant M1 = 1e9 * 1e6;

    Pool private immutable pool;
    Aux private immutable aux;
    Coin private immutable coin0;
    Coin private immutable coin1;
    uint256 private immutable n0;
    uint256 private immutable n1;
    address[] private users = [address(11), address(12)];

    constructor(address p, address a, address c0, address c1) {
        coin0 = Coin(c0);
        coin1 = Coin(c1);
        pool = Pool(p);
        aux = Aux(a);
        n0 = Pool(p).n0();
        n1 = Pool(p).n1();

        vm.startPrank(users[0]);
        coin0.approve(address(pool), type(uint256).max);
        coin1.approve(address(pool), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(users[1]);
        coin0.approve(address(aux), type(uint256).max);
        coin1.approve(address(aux), type(uint256).max);
        vm.stopPrank();
    }

    function get_v2() private view returns (uint256) {
        (uint256 b0, uint256 b1) = pool.get_balances();
        uint256 w = pool.get_w();
        uint256 dw = W - w;
        return Math.calc_v2(b0 * n0, b1 * n1, w, dw);
    }

    function mint(Coin coin, address user, uint256 d) private {
        if (d > coin.balanceOf(user)) {
            coin.mint(user, d);
        }
    }

    function add_liquidity(uint256 d0, uint256 d1) public {
        console.log("--- add liquidity ---");
        d0 = bound(d0, 1, M0);
        d1 = bound(d1, 1, M1);

        mint(coin0, users[0], d0);
        mint(coin1, users[0], d1);

        uint256 v20 = get_v2();
        vm.prank(users[0]);
        pool.add_liquidity(d0, d1, 1, users[0]);
        uint256 v21 = get_v2();

        assertGe(v21, v20, "add liquidity: v21 < v20");
    }

    function remove_liquidity(uint256 lp) public {
        console.log("--- remove liquidity ---");
        lp = bound(lp, 1, pool.balanceOf(users[0]));

        uint256 v20 = get_v2();
        vm.prank(users[0]);
        pool.remove_liquidity(lp, 1, 1, users[0]);
        uint256 v21 = get_v2();

        assertLe(v21, v20, "remove liquidity: v21 > v20");
    }

    function swap(uint256 d_in, bool zero_for_one) public {
        console.log("--- swap ---");
        if (zero_for_one) {
            d_in = bound(d_in, 1, M0);
            mint(coin0, users[1], d_in);
        } else {
            d_in = bound(d_in, 1, M1);
            mint(coin1, users[1], d_in);
        }

        uint256 v20 = get_v2();
        vm.prank(users[1]);
        aux.swap(d_in, 1, zero_for_one);
        uint256 v21 = get_v2();

        assertGe(v21, v20, "swap: v21 < v20");
    }
}

contract PoolInvariantTest is Test {
    Pool private pool;
    Aux private aux;
    Coin private coin0;
    Coin private coin1;
    uint256 private n0;
    uint256 private n1;

    Handler private handler;

    function setUp() public {
        coin0 = new Coin("coin 0", "COIN0", 18);
        coin1 = new Coin("coin 1", "COIN1", 6);

        pool = new Pool(
            0.8 * 1e5,
            1 * 0.001 * 1e18,
            address(coin0),
            address(coin1),
            "lerp",
            "LERP"
        );
        aux = new Aux(address(pool));

        n0 = pool.n0();
        n1 = pool.n1();

        handler = new Handler(
            address(pool),
            address(aux),
            address(coin0),
            address(coin1)
        );

        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = Handler.add_liquidity.selector;
        selectors[1] = Handler.remove_liquidity.selector;
        selectors[2] = Handler.swap.selector;

        targetSelector(
            FuzzSelector({addr: address(handler), selectors: selectors})
        );
    }

    function invariant_v2() public {
        (uint256 b0, uint256 b1) = pool.get_balances();
        assertGe(coin0.balanceOf(address(pool)), b0, "b0");
        assertGe(coin1.balanceOf(address(pool)), b1, "b0");

        if (pool.totalSupply() > 0) {
            uint256 w = pool.get_w();
            uint256 dw = W - w;
            uint256 v2 = Math.calc_v2(b0 * n0, b1 * n1, w, dw);
            assertGt(v2, 0, "v2");
        }
    }
}

// TODO: pool unit tests
