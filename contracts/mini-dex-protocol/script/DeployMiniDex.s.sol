// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MiniDEXFactory} from "../src/Mini-DEX-Factory.sol";
import {Launchpad} from "../src/Launchpad/Launchpad.sol";

contract DeployMiniDex is Script {
    function run() external {
        // Foundry will automatically read PRIVATE_KEY from your .env file
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        console.log("--- BUIDL INITIATED ---");
        console.log("Deployer Wallet:", deployerAddress);

        // Start broadcasting transactions to the Sepolia Network
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy the Launchpad (Fair Token Factory)
        Launchpad launchpad = new Launchpad();
        console.log("--- 1. Launchpad Deployed! ---");
        console.log("Launchpad Address:", address(launchpad));

        // 2. Deploy the MiniDEX Factory (Fee Setter = Deployer)
        MiniDEXFactory factory = new MiniDEXFactory(deployerAddress);
        console.log("--- 2. MiniDEX Factory Deployed! ---");
        console.log("Factory Address  :", address(factory));

        vm.stopBroadcast();
        
        console.log("--- DEPLOYMENT SUCCESSFUL ---");
    }
}
