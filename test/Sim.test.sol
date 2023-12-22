// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../src/Math.sol";
import {Pool} from "../src/Pool.sol";
import {Aux} from "../src/Aux.sol";

contract SimTest is Test {
    Pool private pool;
    Aux private aux;

    // TODO: python test
    // TODO: test with fee = 0
    function setUp() public {
        // high fee -> balanced
        // low fee  -> imbalanced
        // high w   -> imbalanced
        // low w    -> balanced
        pool = new Pool(0.9 * 1e5, 1 * 0.001 * 1e18);
        aux = new Aux();
    }

    struct SwapIn {
        uint256 d_in;
        bool zero_for_one;
    }

    function test() public {
        string memory root = vm.projectRoot();
        string memory in_path = string.concat(root, "/tmp/data.json");
        string memory json = vm.readFile(in_path);

        SwapIn[] memory data = abi.decode(vm.parseJson(json), (SwapIn[]));

        pool.add_liquidity(100 * 1e18, 100 * 1e18, 0);

        for (uint256 i = 0; i < data.length; i++) {
            (uint256 out, uint256 fee) =
                aux.swap(address(pool), data[i].d_in, 0, data[i].zero_for_one);
            // aux.swap(address(pool), out, 0, !data[i].zero_for_one);

            (uint256 b0, uint256 b1) = pool.get_balances();
            // uint256 v2 = Math.calc_v2(b0, b1, 0.7 * 1e5, 0.3 * 1e5);

            console.log("PY_LOG", b0, b1);
        }
    }

    function tmp_test() public {
        {
            (uint256 lp, uint256 f0, uint256 f1) =
                pool.add_liquidity(1e18, 1e6, 0);
            console.log("f0", f0);
            console.log("f1", f1);
            console.log("lp", lp);
        }
        {
            (uint256 lp, uint256 f0, uint256 f1) =
                pool.add_liquidity(1e18, 0, 0);
            console.log("f0", f0);
            console.log("f1", f1);
            console.log("lp", lp);
        }
        {
            (uint256 lp, uint256 f0, uint256 f1) = pool.add_liquidity(0, 1e6, 0);
            console.log("f0", f0);
            console.log("f1", f1);
            console.log("lp", lp);
        }
        {
            (uint256 lp, uint256 f0, uint256 f1) =
                pool.add_liquidity(1e18, 1e6, 0);
            console.log("f0", f0);
            console.log("f1", f1);
            console.log("lp", lp);
        }

        for (uint256 i = 0; i < 100; i++) {
            {
                uint256 d_in = 1e18;
                uint256 min_out = 0.95 * 1e6;
                (uint256 out, uint256 fee) =
                    aux.swap(address(pool), d_in, min_out, true);
                console.log("DY", out, fee);
            }
            {
                uint256 d_in = 1e6;
                uint256 min_out = 0.95 * 1e18;
                (uint256 out, uint256 fee) =
                    aux.swap(address(pool), d_in, min_out, false);
                console.log("DY", out, fee);
            }
        }
    }
}
