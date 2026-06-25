// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {InvalidZeroInput} from "../contracts/Errors/Errors.sol";
import {Setup} from "./warden_setup/Setup.sol";
import {WithdrawQueueStorageV1} from "../contracts/Withdraw/WithdrawQueueStorage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title M-09: Deposit reverts when amount equals buffer deficit
/// @notice A user depositing an amount exactly equal to the protocol's buffer deficit 
/// will unexpectedly revert. The protocol subtracts the buffer deficit from the deposit, 
/// resulting in a 0 net amount, which triggers the InvalidZeroInput check.
/// @author 0xSchutze
contract Renzo_M09_PoC_Test is Test, Setup {
    address alice;
    uint256 deficit;

    function setupBufferDeficit() internal {
        alice = makeAddr("alice");
        
        // Setup global buffer deficit state
        uint256 currentBufferBalance = 100e18;
        uint256 newBufferTarget = 110e18;
        deficit = newBufferTarget - currentBufferBalance;
        
        vm.startPrank(OWNER);
        stETH.mint(address(withdrawQueue), currentBufferBalance);
        
        WithdrawQueueStorageV1.TokenWithdrawBuffer[] memory buffers = new WithdrawQueueStorageV1.TokenWithdrawBuffer[](1);
        buffers[0] = WithdrawQueueStorageV1.TokenWithdrawBuffer(address(stETH), newBufferTarget);
        
        
        withdrawQueue.updateWithdrawBufferTarget(buffers);
        vm.stopPrank();
    }

    /// @notice deposit() math reduces input by bufferToFill. When depositAmount == deficit, net amount hits 0, triggering InvalidZeroInput inside OperatorDelegator.
    function test_DepositReverts_WhenAmountEqDeficit() public {
        setupBufferDeficit();
        uint256 depositAmount = deficit;
        
        vm.startPrank(OWNER);
        stETH.mint(alice, depositAmount);
        vm.stopPrank();

        vm.startPrank(alice);
        stETH.approve(address(restakeManager), type(uint256).max);

        // The deposit logic reduces the input amount by the buffer deficit. 
        // Because depositAmount == deficit, the net amount becomes 0, triggering the revert.
        vm.expectRevert(InvalidZeroInput.selector);
        restakeManager.deposit(IERC20(address(stETH)), depositAmount);
        vm.stopPrank();
    }

    /// @notice Proves the math logic functions normally when deposit > deficit.
    function test_DepositSucceeds_WhenAmountGtDeficit() public {
        setupBufferDeficit();
        uint256 depositAmount = deficit + 1 wei;
        uint256 ezEthBalanceBefore = ezETH.balanceOf(alice);
        
        vm.startPrank(OWNER);
        stETH.mint(alice, depositAmount);
        vm.stopPrank();

        vm.startPrank(alice);
        stETH.approve(address(restakeManager), type(uint256).max);

        restakeManager.deposit(IERC20(address(stETH)), depositAmount);
        vm.stopPrank();

        uint256 ezEthBalanceAfter = ezETH.balanceOf(alice);
        assertTrue(ezEthBalanceAfter > ezEthBalanceBefore, "ezETH balance did not increase: deposit above deficit should succeed");
    }
}