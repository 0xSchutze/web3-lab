// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC20} from "./IERC20.sol";
import {IFlashLoanReceiver} from "./IFlashLoanReceiver.sol";

/// @title FlashLoanProvider
/// @notice A minimal liquidity pool that issues uncollateralized flash loans.
/// @dev Loans must be repaid within the same transaction or the call reverts atomically.
///      The fee rate matches Aave v2 at 9 basis points (0.09%).
contract FlashLoanProvider {

    /// @notice Fee charged on flash loans, expressed in basis points (9 = 0.09%).
    uint256 public constant FEE_BASIS_POINTS = 9;

    /// @notice Divisor used to convert basis points to a ratio.
    uint256 public constant BASIS_POINTS_DIVISOR = 10000;

    /// @notice Emitted when a flash loan is successfully executed and repaid.
    /// @param receiver The contract that received and repaid the loan.
    /// @param token The token that was borrowed.
    /// @param amount The principal amount borrowed.
    /// @param fee The fee collected on top of the principal.
    event FlashLoanExecuted(
        address indexed receiver,
        address indexed token,
        uint256 amount,
        uint256 fee
    );

    /// @notice Issues a flash loan to `receiver` for `amount` of `token`.
    /// @dev The receiver must implement IFlashLoanReceiver and repay amount + fee
    ///      before this call returns, otherwise the entire transaction reverts.
    /// @param receiver Address of the contract that will receive and handle the loan.
    /// @param token ERC20 token address to borrow.
    /// @param amount Amount of tokens to borrow.
    function flashLoan(address receiver, address token, uint256 amount) external {
        uint256 fee = (amount * FEE_BASIS_POINTS) / BASIS_POINTS_DIVISOR;
        uint256 balanceBefore = IERC20(token).balanceOf(address(this));

        require(balanceBefore >= amount, "FlashLoanProvider: insufficient liquidity");

        IERC20(token).transfer(receiver, amount);
        IFlashLoanReceiver(receiver).executeOperation(token, amount, fee, msg.sender);

        uint256 balanceAfter = IERC20(token).balanceOf(address(this));

        require(balanceAfter >= balanceBefore + fee, "FlashLoanProvider: loan not repaid");

        emit FlashLoanExecuted(receiver, token, amount, fee);
    }
}