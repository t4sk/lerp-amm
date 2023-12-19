// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IPool {
    function n0() external view returns (uint256);
    function n1() external view returns (uint256);
    function get_balances() external view returns (uint256 b0, uint256 b1);
    function get_w() external view returns (uint256 w);
    function add_liquidity(uint256 d0, uint256 d1, uint256 min_lp)
        external
        returns (uint256 lp, uint256 fee0, uint256 fee1);
    function remove_liquidity(uint256 lp, uint256 min0, uint256 min1)
        external
        returns (uint256 d0, uint256 d1);
    function swap(uint256 dx, uint256 dy, bool zero_for_one) external;
}
