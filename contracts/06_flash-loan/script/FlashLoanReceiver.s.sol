// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {FlashLoanReceiver} from "../src/FlashLoanReceiver.sol";
import {Script} from "forge-std/Script.sol";


contract FlashLoanReceiverDeploy is Script {

    function run() external {
        // Provider is deployed separately (by a different team).
        // Read its address from the environment before running this script:
        // export PROVIDER_ADDRESS=0x<deployed_provider_address>
        address providerAddress = vm.envAddress("PROVIDER_ADDRESS");

        vm.startBroadcast();
        new FlashLoanReceiver(providerAddress);
        vm.stopBroadcast();
    }
}