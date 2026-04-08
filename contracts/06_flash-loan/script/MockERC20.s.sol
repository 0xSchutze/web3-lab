// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {MockERC20} from "../src/MockERC20.sol";
import {Script} from "forge-std/Script.sol";


contract MockERC20Deploy is Script {

    function run() external {
        vm.startBroadcast();
        MockERC20 token = new MockERC20();

        // Mint initial liquidity to the deployer so they can
        // fund the FlashLoanProvider pool after deployment.
        // Transfer these tokens to the provider address manually,
        // or extend this script with: token.transfer(PROVIDER_ADDRESS, amount)
        token.mint(msg.sender, 1_000_000e18);

        vm.stopBroadcast();
    }
}
