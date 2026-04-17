# Level 12: Privacy

**Target:** [Privacy.sol](./Privacy.sol)

## Vulnerability

`private` visibility in Solidity only prevents other contracts from reading a variable. It does **not** hide data from the blockchain — all storage is publicly readable off-chain via tools like `cast`, `ethers.js`, or Foundry's `vm.load`.

## Key Concepts

**Storage packing:** The EVM fits multiple small variables into a single 32-byte slot. Layout for this contract:

| Slot | Variable(s) |
|------|-------------|
| 0 | `locked` (bool, 1 byte) |
| 1 | `ID` (uint256, 32 bytes) |
| 2 | `flattening` + `denomination` + `awkwardness` (packed, 4 bytes total) |
| 3 | `data[0]` (bytes32) |
| 4 | `data[1]` (bytes32) |
| 5 | `data[2]` (bytes32) ← target |

**Casting truncation:** Converting `bytes32` to `bytes16` drops the right half — only the first 16 bytes are kept.

## Root Cause

`private` is a compile-time access modifier, not a data protection mechanism. The blockchain is a public ledger — all storage is readable by anyone with an RPC endpoint.

## Exploit

Read `data[2]` from storage slot 5 off-chain, cast to `bytes16`, pass to `unlock()`.

```solidity
bytes32 key = vm.load(target, bytes32(uint256(5)));
IPrivacy(target).unlock(bytes16(key));
```

## Real-World Reference

Storage layout knowledge is critical for proxy-based exploits. The **Audius governance hack (2022, $6M)** exploited a storage collision between a proxy and its implementation — the attacker read the storage layout, found a misaligned slot, and injected a malicious proposal. Understanding how variables pack into slots (and how to read them) is foundational for both this CTF pattern and real-world proxy/storage collision attacks.