// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title  upgradableProxy
 * @notice EIP-1967 compliant Transparent Upgradeable Proxy.
 *
 * @dev    Architecture:
 *         - All calls that do NOT match the proxy's own functions fall through
 *           to `fallback()` / `receive()` which forward them to the current
 *           implementation via `delegatecall`.
 *         - The implementation address and the admin address are stored in
 *           pseudo-random storage slots derived from EIP-1967 to prevent
 *           storage-layout collisions with the implementation contract.
 *         - Only the admin may call `upgradeTo` or `transferOwnership`.
 *
 * Storage slots (EIP-1967):
 *   Implementation : bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
 *   Admin          : bytes32(uint256(keccak256("eip1967.admin.implementation"))  - 1)
 */
contract UpgradableProxy {
    // -------------------------------------------------------------------------
    // Storage slots (EIP-1967)
    // -------------------------------------------------------------------------

    /// @dev Slot that holds the address of the current implementation contract.
    bytes32 private constant _IMPLEMENTATION_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

    /// @dev Slot that holds the address of the admin (the only account that
    ///      may upgrade the implementation or transfer ownership).
    bytes32 private constant _ADMIN_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /**
     * @notice Deploys the proxy, pointing it at `_implementation` and
     *         granting admin rights to `_admin`.
     * @param _implementation Address of the first implementation contract.
     * @param _admin          Address that will have admin privileges.
     */
    constructor(address _implementation, address _admin) {
        bytes32 implSlot  = _IMPLEMENTATION_SLOT;
        bytes32 adminSlot = _ADMIN_SLOT;
        assembly {
            sstore(implSlot,  _implementation)
            sstore(adminSlot, _admin)
        }
    }

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------

    /// @dev Reverts if the caller is not the current admin.
    modifier onlyOwner() {
        address admin;
        bytes32 adminSlot = _ADMIN_SLOT;
        assembly {
            admin := sload(adminSlot)
        }
        require(msg.sender == admin, "upgradableProxy: caller is not admin");
        _;
    }

    // -------------------------------------------------------------------------
    // Admin functions
    // -------------------------------------------------------------------------

    /**
     * @notice Points the proxy at a new implementation contract.
     * @dev    Only the admin may call this function.
     *         The caller is responsible for ensuring the new implementation is
     *         storage-layout compatible with the previous one.
     * @param newImpl Address of the new implementation contract.
     */
    function upgradeTo(address newImpl) external onlyOwner {
        bytes32 implSlot = _IMPLEMENTATION_SLOT;
        assembly {
            sstore(implSlot, newImpl)
        }
    }

    /**
     * @notice Transfers admin rights to a new address.
     * @dev    Only the current admin may call this function.
     *         Once transferred, the old admin loses all privileges permanently.
     * @param newAdmin Address of the new admin.
     */
    function transferOwnership(address newAdmin) external onlyOwner {
        bytes32 adminSlot = _ADMIN_SLOT;
        assembly {
            sstore(adminSlot, newAdmin)
        }
    }

    // -------------------------------------------------------------------------
    // Fallback — delegation layer
    // -------------------------------------------------------------------------

    /// @dev Delegates any non-matching calldata to the current implementation.
    fallback() external payable {
        _delegate();
    }

    /// @dev Delegates plain ETH transfers to the current implementation.
    receive() external payable {
        _delegate();
    }

    /**
     * @dev Performs a `delegatecall` to the current implementation.
     *      Reverts if no implementation is set.
     *      Uses inline assembly so that arbitrary return-data sizes are handled
     *      correctly — something Solidity's type system cannot do natively.
     *
     *      Flow:
     *        1. Read implementation address from EIP-1967 slot.
     *        2. Copy calldata into memory at offset 0.
     *        3. delegatecall → implementation (execution context stays in Proxy).
     *        4. Copy return data into memory at offset 0.
     *        5. Return or revert, forwarding the return data verbatim.
     */
    function _delegate() private {
        // Step 1: read implementation address from EIP-1967 slot.
        address impl;
        bytes32 implSlot = _IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(implSlot)
        }
        require(impl != address(0), "upgradableProxy: implementation not set");

        // Steps 2-5: forward call via delegatecall and bubble up the result.
        assembly {
            // Copy calldata into memory starting at offset 0.
            calldatacopy(0, 0, calldatasize())

            // delegatecall: execution runs inside the implementation's code
            // but reads/writes THIS proxy's storage and preserves msg.sender.
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)

            // Copy whatever the implementation returned into memory offset 0.
            returndatacopy(0, 0, returndatasize())

            // Bubble up success or failure to the original caller.
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}