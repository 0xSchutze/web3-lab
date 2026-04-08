// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/// @title IERC20
/// @notice Minimal ERC20 interface exposing the functions used by this project.
interface IERC20 {
    function transfer(address to, uint256 amount) external;
    function transferFrom(address from, address to, uint256 amount) external;
    function approve(address spender, uint256 amount) external;
    function mint(address to, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}