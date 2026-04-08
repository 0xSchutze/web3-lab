// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/// @title IFlashLoanProvider
/// @notice Interface for initiating a flash loan from an external receiver contract.
interface IFlashLoanProvider {

    /// @notice Issues a flash loan to `receiver` for `amount` of `token`.
    /// @param receiver The contract that will receive and handle the loan.
    /// @param token The ERC20 token to borrow.
    /// @param amount The amount to borrow.
    function flashLoan(address receiver, address token, uint256 amount) external;
}
