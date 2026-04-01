// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/// @title IERC20
/// @notice Minimal ERC20 interface used by the Vault for token interactions
interface IERC20 {
    /// @notice Transfer tokens to a given address
    function transfer(address to, uint256 amount) external returns (bool);

    /// @notice Transfer tokens from one address to another (requires prior approval)
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    /// @notice Returns the token balance of an address
    function balanceOf(address account) external view returns (uint256);

    /// @notice Approve a spender to use tokens on behalf of the caller
    function approve(address spender, uint256 amount) external returns (bool);
}
