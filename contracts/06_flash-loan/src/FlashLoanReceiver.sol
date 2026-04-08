// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IFlashLoanReceiver} from "./IFlashLoanReceiver.sol";
import {IFlashLoanProvider} from "./IFlashLoanProvider.sol";
import {IERC20} from "./IERC20.sol";

/// @title FlashLoanReceiver
/// @notice Reference implementation of a flash loan receiver contract.
/// @dev Implements IFlashLoanReceiver. The executeOperation callback repays
///      the loan immediately after receiving it. In production, insert arbitrage,
///      liquidation, or collateral swap logic before the repayment transfer.
contract FlashLoanReceiver is IFlashLoanReceiver {

    /// @notice Address of the trusted FlashLoanProvider.
    /// @dev Immutable — set once at construction, cannot be changed afterwards.
    address public immutable provider;

    /// @param _provider Address of the FlashLoanProvider to interact with.
    constructor(address _provider) {
        provider = _provider;
    }

    /// @notice Initiates a flash loan request to the trusted provider.
    /// @param token ERC20 token address to borrow.
    /// @param amount Amount of tokens to borrow.
    function requestFlashLoan(address token, uint256 amount) external {
        IFlashLoanProvider(provider).flashLoan(address(this), token, amount);
    }

    /// @notice Callback executed by the provider mid-flash-loan.
    /// @dev Only the trusted provider may call this function.
    ///      At this point, address(this) holds `amount` tokens.
    ///      Insert custom logic (arbitrage, liquidation) before the repayment transfer.
    ///      The `initiator` parameter (who triggered the loan) is available but unused here.
    /// @param token The token that was borrowed.
    /// @param amount The principal that was borrowed.
    /// @param fee The fee to repay on top of the principal.
    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        address /* initiator */
    ) external {
        require(msg.sender == provider, "FlashLoanReceiver: caller is not provider");

        // --- Insert custom logic here ---
        // At this point this contract holds `amount` tokens.
        // Use them for arbitrage, liquidation, collateral swaps, etc.
        // --------------------------------

        // Repay principal + fee to the provider.
        IERC20(token).transfer(provider, amount + fee);
    }
}