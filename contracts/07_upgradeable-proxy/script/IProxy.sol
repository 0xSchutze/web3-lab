// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title  IProxy
 * @notice Minimal interface used by deploy/upgrade scripts to interact with a
 *         deployed `upgradableProxy` without importing the full contract.
 */
interface IProxy {
    /**
     * @notice Points the proxy at a new implementation contract.
     * @dev    Caller must be the proxy admin; reverts otherwise.
     * @param newImpl Address of the new implementation contract.
     */
    function upgradeTo(address newImpl) external;
}