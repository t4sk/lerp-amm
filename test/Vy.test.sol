// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "./lib/Vyper.sol";

// forge test --via-ir --ffi --match-path test/Vy.test.sol -vvvv --evm-version shanghai
interface IMath {
    function mul(uint256 x, uint256 y) external pure returns (uint256);
}

contract VyTest is Test {
    Vyper private vy = new Vyper();

    function setUp() public {
        address addr = vy.deploy("Math");

        console.log("ADDR", addr);

        IMath(addr).mul(123, 456);

    }

    function test() public {
        //
    }

}