// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IDetectionBot — Aggregated interface for DET, Forta, and CryptoVault interactions
interface IDetectionBot {
    // Forta
    function setDetectionBot(address detectionBotAddress) external;
    function raiseAlert(address user) external;

    // DoubleEntryPoint public getters
    function cryptoVault() external view returns (address);
    function forta() external view returns (address);
}
