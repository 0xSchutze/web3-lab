// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {Staking} from "../src/Staking.sol";
import {StakingToken} from "../src/StakingToken.sol";
import {RewardToken} from "../src/RewardToken.sol";

contract DeployMiniStaking is Script {
    function run() external returns (Staking, StakingToken, RewardToken) {
        vm.startBroadcast();

        // 1. Deploy Tokens
        StakingToken stakingToken = new StakingToken();
        RewardToken rewardToken = new RewardToken();

        // 2. Deploy Staking Contract mapping to both tokens with 10 tokens per second rate
        uint256 rewardRate = 10 * 1e18; // 10 tokens per second
        Staking staking = new Staking(address(stakingToken), address(rewardToken), rewardRate);

        // 3. Fund the Staking Contract with some RewardTokens so it can pay out
        rewardToken.transfer(address(staking), 500000 * 1e18);

        vm.stopBroadcast();
        return (staking, stakingToken, rewardToken);
    }
}
