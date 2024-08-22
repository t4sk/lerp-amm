// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {Vyper} from "../lib/Vyper.sol";

// forge test --via-ir --ffi --match-path test/Vy.test.sol -vvvv --evm-version shanghai
interface IMath {
    function mul(uint256 x, uint256 y) external pure returns (uint256);
    function sqrt(uint256 x) external pure returns (uint256);
}

contract VyTest is Test {
    Vyper private vy = new Vyper();
    IMath private math;

    function setUp() public {
        address addr = vy.deploy("Math");
        math = IMath(addr);
    }

    function test_sqrt(uint256 x) public {
        math.sqrt(x);
    }
}
