// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {FlashLoanProvider} from "../src/FlashLoanProvider.sol";
import {Script} from "forge-std/Script.sol";


contract FlashLoanProviderDeploy is Script {

    function run() external {
        vm.startBroadcast();
        new FlashLoanProvider();
        vm.stopBroadcast();
    }
}