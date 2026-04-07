// SPDX-License-Identifier: MIT


pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {PriceReader} from "../src/PriceReader.sol";

contract PriceReaderTest is Test {

    PriceReader public conversionContract;
    MockV3Aggregator public testMock;


    function setUp() public {

        testMock = new MockV3Aggregator(8, 2000e8);

        conversionContract = new PriceReader(address(testMock));
     
    }



    function test_Conversion() view public {

        uint256 conversion = conversionContract.getConversionRate(0.5 ether);
        assertEq(conversion, 1000 * 1e18);
    }


    function test_Price() view public {

        conversionContract.getLatestPrice();
        assertEq(conversionContract.getLatestPrice(), 2000e8);
    }







}