# Token

## Vulnerability: Integer Underflow

**Category:** Arithmetic
**Severity:** Critical

## Analysis

The `transfer()` function checks whether the sender has enough balance using:

```solidity
require(balances[msg.sender] - _value >= 0);
```

At first glance, this appears to validate that the sender's balance is sufficient. However, since `balances` is a `uint256` (unsigned integer), the subtraction `balances[msg.sender] - _value` can never produce a negative result. Instead, when `_value` exceeds the sender's balance, the result **wraps around** to an extremely large number (close to `2^256 - 1`). This wrapped value is always greater than 0, so the `require` check always passes.

As a result, an attacker can transfer more tokens than they own, effectively minting tokens out of thin air.

## Exploit Files

- [exploit.sol](./exploit.sol) — Requests `totalSupply` tokens from a zero-balance contract, triggering underflow
- [exploitScript.s.sol](./exploitScript.s.sol) — Deploys and executes in a single transaction

## Key Takeaway

Solidity versions prior to 0.8.0 do not have built-in overflow/underflow protection. Developers had to use libraries like **OpenZeppelin's SafeMath** to guard against arithmetic bugs. Starting from Solidity 0.8.0, the compiler automatically reverts on overflow and underflow, making this class of vulnerability largely obsolete in newer contracts.