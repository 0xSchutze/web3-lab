// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {PriceReader} from "../src/PriceReader.sol";


contract DeployPriceReader is Script {

    function run() external returns (PriceReader) {


        vm.startBroadcast();
        PriceReader contractAddress = new PriceReader(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        vm.stopBroadcast();
        return contractAddress;

        

    }


}