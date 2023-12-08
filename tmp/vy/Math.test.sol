pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import {Vyper} from "../lib/Vyper.sol";

interface IMath {
    function mul(uint256 x, uint256 y) external pure returns (uint256);
}

// source venv/bin/activate
// forge test --match-path test/vy/Math.test.sol --ffi
contract VyperStorageTest is Test {
    Vyper private vy = new Vyper();
    IMath private math;

    function setUp() public {
        math = IMath(vy.deploy("Math"));
        targetContract(address(math));
    }

    function test_mul() public {
        console.log("ADDR", address(math).code.length);
        assertEq(math.mul(2, 3), 6);
    }
}
