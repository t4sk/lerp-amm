// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IPool {
    function n0() external view returns (uint256);
    function n1() external view returns (uint256);
    function balance0() external view returns (uint256);
    function balance1() external view returns (uint256);
    function get_w() external view returns (uint256 w);
    function add_liquidity(uint256 d0, uint256 d1, uint256 min_lp)
        external
        returns (uint256 lp);
    function remove_liquidity(uint256 lp, uint256 min_d0, uint256 min_d1)
        external
        returns (uint256 d0, uint256 d1);
    function swap(uint256 dx, uint256 dy, bool zero_for_one) external;
}
