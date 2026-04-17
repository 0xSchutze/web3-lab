# Level 01: Fallback

**Target:** [Fallback.sol](./Fallback.sol)

## Vulnerability

The `receive()` function contains ownership transfer logic — sending any amount of ETH after making a small contribution reassigns the contract owner.

```solidity
receive() external payable {
    require(msg.value > 0 && contributions[msg.sender] > 0);
    owner = msg.sender; // ownership bypass
}
```

## Root Cause

Critical access control logic placed inside `receive()`, which is meant for handling unexpected ETH transfers — not authorization decisions.

## Exploit

1. Call `contribute()` with a small amount to register a non-zero contribution.
2. Send ETH directly to trigger `receive()` → becomes owner.
3. Call `withdraw()` to drain the contract.

Solved via browser console — no exploit contract needed.

## Real-World Reference

The Rubixi contract (2016) had a similar ownership bug where the constructor was misspelled, allowing anyone to claim ownership. While not identical to a `receive()` flaw, both stem from the same root: ownership logic in an unprotected entry point. [Rubixi Post-Mortem](https://blog.ethereum.org/2016/06/19/thinking-smart-contract-security)