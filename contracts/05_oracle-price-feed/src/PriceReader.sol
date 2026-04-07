// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;


import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";




contract PriceReader {


    AggregatorV3Interface public priceFeed;

   constructor(address _priceFeed) {

    priceFeed = AggregatorV3Interface(_priceFeed);

   }




   function getLatestPrice() public view returns (int256 price) {
    (
    /* uint80 roundID */,
    price,
    /*uint startedAt*/,
    /*uint timeStamp*/,
    /*uint80 answeredInRound*/
)  = priceFeed.latestRoundData();
   }


   function getConversionRate(uint256 ethAmount) public view returns (uint256 usdValueforAmount){

    uint256 price = uint256(getLatestPrice());

    uint256 conversionRate = price * 1e10;

   usdValueforAmount = (ethAmount * conversionRate) / 1e18; 







   }

}