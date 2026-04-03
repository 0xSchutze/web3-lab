// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Staking} from "../src/Staking.sol";
import {StakingToken} from "../src/StakingToken.sol";
import {RewardToken} from "../src/RewardToken.sol";

contract MiniStakingTest is Test {
    StakingToken stakingToken;
    RewardToken rewardToken;
    Staking staking;

    address public alice = makeAddr("Alice");
    address public bob = makeAddr("Bob");

    function setUp() public {
        stakingToken = new StakingToken();
        rewardToken = new RewardToken();
        
        uint256 rewardRate = 20 * 1e18; // 20 tokens per second for our math test
        staking = new Staking(address(stakingToken), address(rewardToken), rewardRate);

        // Fund staking contract with rewards
        rewardToken.transfer(address(staking), 100000 * 1e18);

        // Give Alice and Bob initial tokens
        stakingToken.transfer(alice, 100 * 1e18);
        stakingToken.transfer(bob, 100 * 1e18);
    }

    function test_StakingMathematics() public {
        // We will recreate the exact linear math distribution test
        // Setup: rate = 20
        // Second 0: Alice stakes 10
        // Second 2: Bob stakes 30
        // Second 5: Both withdraw

        // --- Second 0 ---
        vm.startPrank(alice);
        stakingToken.approve(address(staking), 10 * 1e18);
        staking.stake(10 * 1e18);
        vm.stopPrank();

        // --- Second 2 ---
        vm.warp(block.timestamp + 2); // Fast forward 2 seconds

        vm.startPrank(bob);
        stakingToken.approve(address(staking), 30 * 1e18);
        staking.stake(30 * 1e18);
        vm.stopPrank();

        // --- Second 5 ---
        vm.warp(block.timestamp + 3); // Fast forward 3 more seconds (Total 5)

        // Everyone withdraws
        vm.prank(alice);
        staking.getReward();
        
        vm.prank(bob);
        staking.getReward();

        // --- Assertions (Audit Check) ---
        uint256 aliceRewards = rewardToken.balanceOf(alice);
        uint256 bobRewards = rewardToken.balanceOf(bob);

        console.log("Alice's rewards:", aliceRewards / 1e18);
        console.log("Bob's rewards:", bobRewards / 1e18);

        // Math expectations based on precise temporal staking
        // Alice should have 55
        // Bob should have 45
        assertEq(aliceRewards, 55 * 1e18, "Alice math failed!");
        assertEq(bobRewards, 45 * 1e18, "Bob math failed!");
    }
}
