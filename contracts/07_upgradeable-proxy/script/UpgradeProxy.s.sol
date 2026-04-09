// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {CounterV2} from "../src/CounterV2.sol";
import {IProxy} from "./IProxy.sol";

/**
 * @title  UpgradeProxyScript
 * @notice Deploys the CounterV2 implementation and upgrades an existing proxy
 *         to point at it.
 *
 * @dev    The broadcaster must be the proxy admin; the transaction will revert
 *         on-chain if it is not.
 *
 *         Usage:
 *           forge script script/UpgradeProxy.s.sol --rpc-url $RPC_URL \
 *               --broadcast --private-key $ADMIN_PRIVATE_KEY
 *
 *         Required env vars:
 *           PROXY_ADDRESS — address of the already-deployed proxy.
 */
contract UpgradeProxyScript is Script {
    /**
     * @notice Entry point called by `forge script`.
     * @return counterV2 Address of the newly deployed CounterV2 implementation.
     */
    function run() public returns (address counterV2) {
        // Read the proxy address from environment variables.
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");

        vm.startBroadcast();

        // 1. Deploy the new implementation.
        counterV2 = address(new CounterV2());

        // 2. Point the proxy at the new implementation.
        //    Caller must be the proxy admin, otherwise this reverts.
        IProxy(proxyAddress).upgradeTo(counterV2);

        vm.stopBroadcast();
    }
}