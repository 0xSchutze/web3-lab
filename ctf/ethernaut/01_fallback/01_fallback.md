# Fallback

## Vulnerability: Access Control via `receive()`

**Category:** Access Control
**Severity:** Critical
**Target Contract:** [Fallback.sol](./Fallback.sol)

## Analysis

The `receive()` function is a special Solidity function that triggers whenever someone sends ETH to the contract without calling any specific function. In this contract, the `receive()` function reassigns ownership to `msg.sender` if two conditions are met: the sender has a non-zero contribution and sends any amount greater than 0.

```solidity
receive() external payable {
    require(msg.value > 0 && contributions[msg.sender] > 0);
    owner = msg.sender;
}
```

The `contribute()` function also allows ownership transfer, but only if the caller's total contributions exceed the owner's (1000 ETH). This path is impractical. However, the `receive()` function provides a shortcut — a single small contribution followed by a direct ETH transfer is enough to claim ownership.

## Exploit Steps

1. Call `contribute()` with a small amount (e.g., 0.0001 ETH) to register a non-zero contribution.
2. Send ETH directly to the contract address to trigger `receive()`, which sets `owner = msg.sender`.
3. Call `withdraw()` to drain the contract.

**Solved via browser console — no exploit contract needed.**

## Key Takeaway

Never place ownership logic inside `receive()` or `fallback()` functions. These are meant for handling unexpected ETH transfers, not for access control decisions.