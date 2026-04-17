# Level 13: Gatekeeper One

**Target:** [Gatekeeper.sol](./Gatekeeper.sol)

## Vulnerability

Three independent access controls (`modifiers`) that must all pass within a single transaction. None of them is inherently broken — the vulnerability is that they can be simultaneously satisfied by a carefully crafted intermediary contract.

## Gates

**Gate 1** — `msg.sender != tx.origin`  
Must call through a contract. Pass by deploying an intermediary.

**Gate 2** — `gasleft() % 8191 == 0`  
The remaining gas at this exact point must be a multiple of 8191. Exact gas usage cannot be statically computed (compiler/version-dependent), so the offset is discovered via off-chain brute-force simulation before a single on-chain transaction is sent.

**Gate 3** — Bitwise key constraints derived from `tx.origin`:
```
uint32(uint64(key)) == uint16(uint64(key))   // middle bytes must be zero
uint32(uint64(key)) != uint64(key)            // upper bytes must be non-zero  
uint32(uint64(key)) == uint16(uint160(tx.origin)) // lower bytes must match origin
```

Key is derived by masking the caller's address:
```solidity
bytes8 key = bytes8(uint64(uint160(tx.origin))) & 0xFFFFFFFF0000FFFF;
```

## Root Cause

Each gate relies on assumptions that can be circumvented: gate 1 assumes direct EOA interaction, gate 2 assumes unpredictable gas consumption, gate 3 assumes opaque address-derived keys. All three are bypassable with a purpose-built intermediary contract and off-chain simulation.

## Exploit

1. **Off-chain (free):** Simulate brute-force across gas offsets 0–300 to find the exact value that satisfies gate 2.
2. **On-chain (single tx):** Deploy exploit contract and call `attack(correctOffset)` — one shot, precise gas.

## Real-World Reference

Gas-dependent logic is fragile across EVM upgrades. After the Istanbul hard fork (EIP-2200), gas costs for `SSTORE` changed, breaking contracts that relied on exact gas amounts — including some multi-sig wallets. The bitwise masking pattern (gate 3) maps directly to understanding how Solidity truncates data during type casting, a common source of precision loss bugs in DeFi protocols (e.g., rounding errors in reward calculations or fee computations that silently discard significant bits).
