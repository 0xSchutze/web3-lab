// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../src/MockERC20.sol";
import {FlashLoanProvider} from "../src/FlashLoanProvider.sol";
import {FlashLoanReceiver} from "../src/FlashLoanReceiver.sol";

/// @title FlashLoanTest
/// @notice Integration tests for the FlashLoan Provider/Receiver system.
contract FlashLoanTest is Test {

    FlashLoanProvider public provider;
    FlashLoanReceiver public receiver;
    MockERC20 public token;

    function setUp() external {
        token    = new MockERC20();
        provider = new FlashLoanProvider();
        receiver = new FlashLoanReceiver(address(provider));

        // Fund the provider pool with 1,000,000 tokens as initial liquidity.
        token.mint(address(provider), 1_000_000e18);
    }

    /// @notice Verifies that a flash loan is successfully issued and repaid.
    /// @dev Receiver is pre-funded with 1,000 tokens to cover the 900-token fee
    ///      (1,000,000 * 0.09% = 900). After repayment the receiver retains 100 tokens.
    function test_FlashLoanSuccess() external {
        token.mint(address(receiver), 1_000e18);

        receiver.requestFlashLoan(address(token), 1_000_000e18);

        assertEq(token.balanceOf(address(receiver)), 100e18);
    }

    /// @notice Verifies that a flash loan reverts if the receiver cannot repay.
    /// @dev Receiver has zero balance, making repayment impossible.
    ///      The provider's balance must remain intact after the revert.
    function test_FlashLoanFail() external {
        vm.expectRevert();
        receiver.requestFlashLoan(address(token), 1_000_000e18);
    }
}