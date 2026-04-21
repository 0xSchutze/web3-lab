// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IDetectionBot} from "./IDetectionBot.sol";

/// @title DetectionBot — Forta Alert Agent for CryptoVault Drain Protection
/// @notice Monitors delegateTransfer() calls on the DoubleEntryPoint token.
///         If the origSender (3rd parameter in calldata) matches the CryptoVault
///         address, raises a Forta alert to revert the transaction.
contract DetectionBot {
    address private immutable fortaAddress;
    address private immutable cryptoVault;

    /// @param det Address of the DoubleEntryPoint (DET) token contract.
    constructor(address det) {
        fortaAddress = IDetectionBot(det).forta();
        cryptoVault = IDetectionBot(det).cryptoVault();
    }

    /// @notice Called by Forta.notify() during the fortaNotify modifier execution.
    /// @dev The msgData contains the full calldata of delegateTransfer(to, value, origSender).
    ///      Layout: [4B selector][32B to][32B value][32B origSender]
    ///      We extract origSender at offset 68 (4 + 32 + 32).
    /// @param user The player address registered in Forta.
    /// @param msgData Raw calldata from the delegateTransfer invocation.
    function handleTransaction(address user, bytes calldata msgData) external {
        address origSender;
        assembly {
            origSender := calldataload(add(msgData.offset, 68))
        }

        if (origSender == cryptoVault) {
            IDetectionBot(fortaAddress).raiseAlert(user);
        }
    }
}
