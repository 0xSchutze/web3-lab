// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/// @title IFlashLoanReceiver
/// @notice Interface that must be implemented by any flash loan receiver contract.
/// @dev The provider calls executeOperation after transferring the requested funds.
///      The implementor MUST repay (amount + fee) to the provider before returning.
interface IFlashLoanReceiver {

    /// @notice Called by the provider during an active flash loan.
    /// @param token The ERC20 token that was borrowed.
    /// @param amount The principal amount borrowed.
    /// @param fee The fee to be repaid on top of the principal.
    /// @param initiator The address that originally triggered the flash loan.
    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        address initiator
    ) external;
}