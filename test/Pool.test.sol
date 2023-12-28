// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../src/Math.sol";
import {Pool} from "../src/Pool.sol";
import {Aux} from "../src/Aux.sol";
import {Coin} from "./lib/Coin.sol";

contract PoolTest is Test {
    Pool private pool;
    Aux private aux;
    Coin private coin0;
    Coin private coin1;

    function setUp() public {
        coin0 = new Coin("coin 0", "COIN0", 18);
        coin1 = new Coin("coin 1", "COIN1", 6);

        pool = new Pool(
            0.9 * 1e5,
            1 * 0.001 * 1e18,
            address(coin0),
            address(coin1),
            "lerp",
            "LERP"
        );
        aux = new Aux(address(pool));

        coin0.approve(address(pool), type(uint256).max);
        coin1.approve(address(pool), type(uint256).max);

        coin0.approve(address(aux), type(uint256).max);
        coin1.approve(address(aux), type(uint256).max);

        pool.approve(address(aux), type(uint256).max);
    }
}
