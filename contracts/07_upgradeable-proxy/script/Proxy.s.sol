// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {UpgradableProxy} from "../src/UpgradableProxy.sol";

/**
 * @title  upgradableProxyScript
 * @notice Deploys the `upgradableProxy` contract, wiring it to an existing
 *         implementation and granting admin rights to the deployer.
 *
 * @dev Usage:
 *      1. Deploy the implementation first (CounterV1Script).
 *      2. Set IMPLEMENTATION_ADDRESS and ADMIN_ADDRESS in your .env file
 *         (or pass them inline).
 *      3. Run:
 *         forge script script/Proxy.s.sol --rpc-url $RPC_URL \
 *             --broadcast --private-key $PRIVATE_KEY
 */
contract UpgradableProxyScript is Script {
    /**
     * @notice Entry point called by `forge script`.
     * @return proxyAddr Address of the newly deployed proxy.
     */
    function run() public returns (address proxyAddr) {
        // Read the implementation and admin addresses from environment variables.
        address implementation = vm.envAddress("IMPLEMENTATION_ADDRESS");
        address admin          = vm.envAddress("ADMIN_ADDRESS");

        vm.startBroadcast();
        proxyAddr = address(new upgradableProxy(implementation, admin));
        vm.stopBroadcast();
    }
}