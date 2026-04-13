# Vault

## Vulnerability: False Sense of Privacy with `private` Variables

**Category:** Information Disclosure
**Severity:** High

## Analysis

The contract stores a `password` as a `private` state variable (`bytes32 private password`) and uses it inside `unlock()` to guard the vault. The developer assumed that marking a variable as `private` hides it from external access.

In Solidity, `private` only prevents **other contracts** from reading the variable via a getter function. It does **not** hide the data from the blockchain itself. Every state variable is stored in a deterministic storage slot, and anyone can read any slot using an RPC call (`eth_getStorageAt`).

```solidity
bool public locked;      // slot 0
bytes32 private password; // slot 1 — "private" but fully readable
```

## Exploit Steps

1. Read the password directly from storage slot 1:
```javascript
await web3.eth.getStorageAt(contract.address, 1)
```
2. Pass the returned `bytes32` value to `unlock()`:
```javascript
await contract.unlock("0x...")
```

**Solved via browser console — no exploit contract needed.**

## Key Takeaway

The blockchain is a **public ledger**. Every piece of data stored on-chain — including `private` variables — is visible to anyone with an RPC endpoint. Never store secrets (passwords, private keys, API keys) in smart contract storage. If sensitive data must be used on-chain, store only its hash (commitment scheme) or use off-chain computation with on-chain verification (e.g., ZK proofs).
