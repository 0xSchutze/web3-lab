// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Script} from "forge-std/Script.sol";
import {VaultFactory} from "../src/vaultFactory.sol";

contract DeployVaultFactory is Script {
    function run() external returns (VaultFactory) {
        vm.startBroadcast();
        VaultFactory factory = new VaultFactory();
        vm.stopBroadcast();
        return factory;
    }
}
