// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../src/lib/ERC20.sol";

contract Coin is ERC20 {
    constructor(string memory _name, string memory _symbol, uint8 _decimals)
        ERC20(_name, _symbol, _decimals)
    {}

    function mint(address dst, uint256 amount) external {
        _mint(dst, amount);
    }

    function burn(address src, uint256 amount) external {
        _burn(src, amount);
    }
}
