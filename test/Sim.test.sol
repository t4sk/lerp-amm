// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../src/Math.sol";
import {Pool} from "../src/Pool.sol";
import {Aux} from "../src/Aux.sol";
import {Coin} from "./lib/Coin.sol";

// TODO: sim add liq, swaps, remove liq
// TODO: invariant tests
// forge test --via-ir --match-path test/Sim.test.sol -vvv > tmp/out.txt
contract SimTest is Test {
    Pool private pool;
    Aux private aux;
    Coin private coin0;
    Coin private coin1;

    function setUp() public {
        coin0 = new Coin("coin 0", "COIN0", 18);
        coin1 = new Coin("coin 1", "COIN1", 18);

        // high fee -> balanced
        // low fee  -> imbalanced
        // high w   -> imbalanced
        // low w    -> balanced
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

    struct SwapIn {
        uint256 d_in;
        bool zero_for_one;
    }

    function test_sim() public {
        coin0.mint(address(this), 100 * 1e18);
        coin1.mint(address(this), 100 * 1e18);
        (uint256 lp,,) =
            pool.add_liquidity(100 * 1e18, 100 * 1e18, 0, address(this));

        string memory root = vm.projectRoot();
        string memory in_path = string.concat(root, "/tmp/data.json");
        string memory json = vm.readFile(in_path);

        SwapIn[] memory data = abi.decode(vm.parseJson(json), (SwapIn[]));

        for (uint256 i = 0; i < data.length; i++) {
            if (data[i].zero_for_one) {
                coin0.mint(address(this), data[i].d_in);
            } else {
                coin1.mint(address(this), data[i].d_in);
            }

            (uint256 out, uint256 fee) =
                aux.swap(data[i].d_in, 0, data[i].zero_for_one);

            // if (data[i].zero_for_one) {
            //     coin1.mint(address(this), fee);
            // } else {
            //     coin0.mint(address(this), fee);
            // }
            // aux.swap(out + fee, 0, !data[i].zero_for_one);

            // (uint256 b0, uint256 b1) = pool.get_balances();
            // console.log("PY_LOG", b0, b1);
            if (data[i].zero_for_one) {
                console.log("PY_LOG", data[i].d_in, out);
            }
        }

        // (uint256 d0, uint256 d1) = pool.remove_liquidity_one_coin(lp, 0, 0);
        // console.log("remove", d0, d1);
        (uint256 out, uint256 fee) =
            aux.remove_liquidity_one_coin(lp / 10, 0, true);
    }

    struct Price {
        uint256 p;
    }

    // function test_sim_price() public {
    //     coin0.mint(address(this), 100 * 1e18);
    //     coin1.mint(address(this), 100 * 1e18);
    //     (uint256 lp,,) =
    //         pool.add_liquidity(100 * 1e18, 100 * 1e18, 0, address(this));

    //     coin0.mint(address(this), 1e6 * 1e18);
    //     coin1.mint(address(this), 1e6 * 1e18);

    //     string memory root = vm.projectRoot();
    //     string memory in_path = string.concat(root, "/tmp/data.json");
    //     string memory json = vm.readFile(in_path);

    //     Price[] memory data = abi.decode(vm.parseJson(json), (Price[]));

    //     for (uint256 i = 0; i < data.length; i++) {
    //         (uint256 b0, uint256 b1) = pool.get_balances();
    //         if (1e18 < data[i].p) {
    //             // b0 < b1
    //             if (b0 < b1) {
    //                 //
    //             } else {
    //                 // b0 > b1
    //                 (uint256 out, uint256 fee) = aux.swap(1e18, 0, true);
    //             }
    //         } else if (data[i].p < 1e18) {
    //             // b0 > b1
    //             if (b0 < b1) {
    //                 (uint256 out, uint256 fee) = aux.swap(1e18, 0, false);
    //             } else {
    //                 //
    //             }
    //         } else {
    //             if (b0 < b1) {
    //                 (uint256 out, uint256 fee) = aux.swap(1e18, 0, true);
    //             } else {
    //                 (uint256 out, uint256 fee) = aux.swap(1e18, 0, false);
    //             }
    //         }

    //         (b0, b1) = pool.get_balances();
    //         console.log("PY_LOG", b0, b1);
    //     }
    // }
}
