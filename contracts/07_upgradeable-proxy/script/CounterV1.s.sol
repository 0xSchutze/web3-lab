// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {Counter} from "../src/CounterV1.sol";

/**
 * @title  CounterV1Script
 * @notice Deploys the first implementation contract (CounterV1) and writes
 *         its address to `deployments.json` for use by the proxy deploy script.
 *
 * @dev Usage:
 *      forge script script/CounterV1.s.sol --rpc-url $RPC_URL \
 *          --broadcast --private-key $PRIVATE_KEY
 */
contract CounterV1Script is Script {
    /**
     * @notice Entry point called by `forge script`.
     * @return CounterV1 Address of the newly deployed Counter implementation.
     */
    function run() public returns (address CounterV1) {
        vm.startBroadcast();
        CounterV1 = address(new Counter());
        vm.stopBroadcast();

        // Persist the deployment address so subsequent scripts can read it.
        string memory json = vm.serializeAddress("deployment", "CounterV1", CounterV1);
        vm.writeJson(json, "./deployments.json");
    }
}