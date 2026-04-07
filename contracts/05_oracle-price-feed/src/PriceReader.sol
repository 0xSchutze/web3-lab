// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/// @title PriceReader
/// @notice A contract to read and normalize Chainlink price feeds
/// @dev Implements standard 8-decimal to 18-decimal conversion math
contract PriceReader {
    /// @notice The Chainlink price feed aggregator
    AggregatorV3Interface public immutable priceFeed;

    /// @notice Initializes the contract with a specific price feed
    /// @param _priceFeed The address of the Chainlink AggregatorV3Interface contract
    constructor(address _priceFeed) {
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    /// @notice Fetches the latest price from the Chainlink feed
    /// @return price The latest price (usually with 8 decimals for USD pairs)
    function getLatestPrice() public view returns (int256 price) {
        (/* uint80 roundID */,
            price,/* uint startedAt */,/* uint timeStamp */,
            /* uint80 answeredInRound */
        ) = priceFeed.latestRoundData();
    }

    /// @notice Converts an ETH amount to its equivalent USD value
    /// @dev Normalizes the 8-decimal Chainlink price to 18-decimal precision
    /// @param ethAmount The amount of ETH (in wei, 18 decimals)
    /// @return usdValueforAmount The USD value formatted with 18 decimals
    function getConversionRate(uint256 ethAmount) public view returns (uint256 usdValueforAmount) {
        // Cast the signed price to unsigned (prices cannot be negative)
        uint256 price = uint256(getLatestPrice());

        // Scale 8-decimal chainlink price up to 18 decimals to match ethAmount
        uint256 conversionRate = price * 1e10;

        // Multiply and divide out the extra 1e18 added by the multiplication
        usdValueforAmount = (ethAmount * conversionRate) / 1e18;
    }
}
