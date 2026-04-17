# Level 11: Elevator

**Target:** [Elevator.sol](./Elevator.sol)

## Vulnerability

The contract blindly trusts an external interface (`Building`) implemented by `msg.sender`. The same function `isLastFloor()` is called twice in one transaction — once to gate entry into the if-block, and again to set `top`. Since the implementation is provided by the caller, it can return different values on each call.

```solidity
// Elevator.sol — calls isLastFloor twice on the same input
if (!building.isLastFloor(_floor)) {   // call 1: must return false to enter
    floor = _floor;
    top = building.isLastFloor(floor); // call 2: must return true to set top
}
```

## Root Cause

Trusting an externally supplied implementation (oracle spoofing / TOC-TOU). The contract assumes the same query will produce the same result within a single transaction — which is false when the answering party controls the answer.

## Exploit

Implement `Building` with a stateful `isLastFloor()` that flips on each call: returns `false` on the first call (to pass the gate), `true` on the second (to set `top = true`).

```solidity
bool private toggle = true;

function isLastFloor(uint256) external returns (bool) {
    toggle = !toggle;
    return toggle; // false on 1st call, true on 2nd
}
```

## Real-World Reference

**Rari Capital / Fuse Pools (2022) — $80M stolen.** Rari's permissionless lending pools allowed anyone to specify a custom price oracle when creating a pool. Attackers deployed malicious oracle contracts that returned fabricated prices — exactly the same pattern as this level (trusting an externally supplied interface). The protocol's code trusted `msg.sender`'s oracle implementation without validation, allowing attackers to inflate collateral values and drain real assets from shared pools.
