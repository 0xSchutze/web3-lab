# Level 02: Fal1out

**Target:** [Fallout.sol](./Fallout.sol)

## Vulnerability

The intended constructor is named `Fal1out()` (digit `1`) while the contract is named `Fallout`. In Solidity <0.5.0, constructors were functions matching the contract name — this typo makes it a regular public function callable by anyone.

```solidity
function Fal1out() public payable {
    owner = msg.sender; // anyone can call this at any time
}
```

## Root Cause

Pre-0.5.0 constructor convention relied on exact name matching. A single-character typo silently converted the constructor into an unprotected public function.

## Exploit

Call `Fal1out()` — instantly becomes owner. No exploit contract needed.

## Real-World Reference

The Rubixi contract had an identical bug: the contract was renamed from `DynamicPyramid` to `Rubixi` but the constructor function name was never updated, leaving `DynamicPyramid()` as a public function anyone could call to claim ownership. Solidity ≥0.5.0 introduced the `constructor()` keyword to eliminate this entire class of bugs.
