# Level 26: Double Entry Point

**Target:** [DoubleEntryPoint.sol](./DoubleEntryPoint.soll)
**Defense:** [DetectionBot.sol](./DetectionBot.sol)

## Vulnerability

The CryptoVault's `sweepToken()` function prevents direct withdrawal of the underlying DET token. However, sweeping the deprecated LegacyToken (LGT) bypasses this check because LGT's overridden `transfer()` internally calls `DET.delegateTransfer()`, effectively draining DET tokens from the vault through a secondary entry point.

## Key Concepts

**Dual Entry Point (Token Migration Residue):** When protocols migrate from one token to another, the legacy token's transfer logic is often redirected to the new token via `delegateTransfer()`. This creates two distinct call paths to move the same underlying asset, only one of which may be guarded.

**Forta Detection Bot Pattern:** The DET contract uses a `fortaNotify` modifier that invokes registered detection bots before completing `delegateTransfer()`. If any bot raises an alert, the entire transaction reverts. This is an on-chain intrusion detection system.

**Calldata Forensics (Assembly):** The detection bot receives raw `msg.data` from the `delegateTransfer` call. Extracting the `origSender` parameter requires understanding ABI encoding layout: `[4B selector][32B to][32B value][32B origSender]`, with `origSender` starting at byte offset 68.

## Root Cause

`CryptoVault.sweepToken()` only checks `token != underlying` (i.e., the address is not DET). It does not account for the fact that LegacyToken's `transfer()` internally delegates to DET's `delegateTransfer()`, creating an unguarded backdoor to drain the vault's DET balance.

## Exploit (Defense)

This level requires writing a **defense** (Forta detection bot), not an attack.

1. Deploy a `DetectionBot` contract that implements `IDetectionBot.handleTransaction()`.
2. Inside `handleTransaction`, extract the `origSender` from the raw calldata using assembly at offset 68.
3. If `origSender == cryptoVault`, call `forta.raiseAlert(user)` to revert the transaction.
4. Register the bot with Forta via `setDetectionBot()`.

```solidity
function handleTransaction(address user, bytes calldata msgData) external {
    address origSender;
    assembly {
        // delegateTransfer(to, value, origSender) — origSender is at offset 68
        origSender := calldataload(add(msgData.offset, 68))
    }

    if (origSender == cryptoVault) {
        IDetectionBot(fortaAddress).raiseAlert(user);
    }
}
```

## Real-World Reference

Token migration vulnerabilities are a recurring theme in DeFi. When protocols upgrade their token contracts (v1 to v2), residual delegation logic in the old token can create unintended transfer paths. The Forta detection pattern mirrors real-world on-chain monitoring services like Forta Network, OpenZeppelin Defender, and Tenderly Alerts used by protocols to detect anomalous transactions in real time.
