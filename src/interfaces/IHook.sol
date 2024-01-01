// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IHook {
    function get_ema() external view returns (uint256 p, uint256 t);
    function after_swap(
        uint256 d_in,
        uint256 d_out,
        uint256 fee,
        bool zero_for_one,
        uint256 v2,
        uint256 b0,
        uint256 b1
    ) external;
}
