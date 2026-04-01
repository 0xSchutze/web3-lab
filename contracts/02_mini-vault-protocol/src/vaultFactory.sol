// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Vault} from "./vault.sol";

/// @title VaultFactory
/// @author 0xSchutze
/// @notice Deploys and tracks individual Vault instances. Each address can own one vault.
contract VaultFactory {
    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice All deployed vaults
    Vault[] public vaults;

    /// @notice Number of vaults created by an address (max 1)
    mapping(address => uint256) public vaultCount;

    /// @notice Maps owner address to their vault instance
    mapping(address => Vault) private vaultToOwner;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event VaultCreated(
        address indexed owner,
        address indexed vault,
        uint256 date
    );

    /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploy a new Vault. Each address can only create one vault.
    function createVault() external {
        require(
            vaultCount[msg.sender] == 0,
            "vault already exists for this address"
        );
        Vault vault = new Vault(msg.sender);
        vaults.push(vault);
        vaultToOwner[msg.sender] = vault;
        vaultCount[msg.sender]++;
        emit VaultCreated(msg.sender, address(vault), block.timestamp);
    }

    /// @notice Returns the vault owned by the caller
    function getVaultByOwner() external view returns (Vault) {
        require(vaultCount[msg.sender] > 0, "no vault found for this address");
        return vaultToOwner[msg.sender];
    }

    /// @notice Returns all deployed vaults
    function getAllVaults() external view returns (Vault[] memory) {
        return vaults;
    }

    /// @notice Returns total number of vaults deployed
    function getTotalVaults() external view returns (uint256) {
        return vaults.length;
    }
}
