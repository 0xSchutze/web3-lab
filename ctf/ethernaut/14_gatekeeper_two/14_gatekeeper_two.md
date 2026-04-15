# Level 14: Gatekeeper Two

**Target:** [GatekeeperTwo.sol](./GatekeeperTwo.sol)

## Vulnerability

Three independent access controls that must all pass within a single constructor execution. The gates combine `tx.origin` vs `msg.sender` checks, EVM contract lifecycle quirks, and bitwise XOR arithmetic.

## Gates

**Gate 1** — `msg.sender != tx.origin`  
Must call through a contract, same pattern as Gatekeeper One.

**Gate 2** — `extcodesize(caller()) == 0`  
The caller's code size must be zero. Normally impossible for a contract — but during **constructor execution**, the contract's bytecode has not yet been stored on-chain, so `extcodesize` returns 0. All exploit logic must run inside the constructor.

**Gate 3** — `uint64(bytes8(keccak256(abi.encodePacked(msg.sender)))) ^ uint64(_gateKey) == type(uint64).max`  
XOR equation: `A ^ B = C`. Since XOR is its own inverse, solving for `B` is simply `B = A ^ C`. The key is computed as:
```solidity
uint64 gateKey = uint64(bytes8(keccak256(abi.encodePacked(address(this))))) ^ type(uint64).max;
```

## Root Cause

Gate 2 relies on `extcodesize` to distinguish EOAs from contracts, but this check is bypassable during contract construction — an EVM lifecycle edge case. Gate 3 uses XOR as a "lock" but XOR is trivially reversible by design.

## Exploit

Single-step: deploy an exploit contract whose constructor computes the XOR key and calls `enter()`. No separate `attack()` function needed — everything executes atomically during deployment.

```solidity
constructor() {
    uint64 gateKey = uint64(bytes8(keccak256(abi.encodePacked(address(this))))) ^ type(uint64).max;
    IExploit(target).enter(bytes8(gateKey));
}
```

## Real-World Reference

The `extcodesize == 0` trick is a well-known bypass for contracts that attempt to restrict calls to EOAs only. This pattern was exploited in multiple DeFi protocols that used `isContract()` checks (e.g., OpenZeppelin's deprecated `Address.isContract()`). The recommended mitigation is to never rely on `extcodesize` for access control — use `msg.sender == tx.origin` if EOA-only access is truly required, though even this has limitations with account abstraction (ERC-4337).
