# Fal1out

## Vulnerability: Constructor Typo (Legacy Solidity)

**Category:** Access Control
**Severity:** Critical
**Target Contract:** [Fallout.sol](./Fallout.sol)

## Analysis

In Solidity versions prior to 0.5.0, constructors were defined as functions with the same name as the contract. If the function name didn't match the contract name exactly, it would compile as a regular public function instead of a constructor.

In this contract, the intended constructor is named `Fal1out()` (with the digit `1`), while the contract is named `Fallout`. Due to this typo, `Fal1out()` is not treated as a constructor — it becomes a publicly callable function. As a result, anyone can call it at any time to claim ownership.

## Exploit Steps

1. Call `Fal1out()` with any ETH value — this sets `owner = msg.sender`.

## Key Takeaway

Modern Solidity (≥0.5.0) introduced the `constructor()` keyword specifically to prevent this class of bugs. Always use `constructor()` instead of named constructor functions. This vulnerability was present in early real-world contracts and is a reminder that even simple typos can lead to critical exploits.
