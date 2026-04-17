# Level 05: Token

**Target:** [Token.sol](./Token.sol)

## Vulnerability

The balance check uses unsigned integer subtraction without overflow protection:

```solidity
require(balances[msg.sender] - _value >= 0); // always true for uint256
```

Since `uint256` cannot be negative, the subtraction wraps around to `~2^256` when `_value > balance`. The wrapped result is always `>= 0`, so the check always passes.

## Root Cause

Integer underflow in Solidity <0.8.0 which lacks built-in overflow/underflow checks. Developers had to use OpenZeppelin's SafeMath library to guard against this.

## Exploit

Transfer more tokens than owned (e.g., `totalSupply` from a zero-balance contract). The underflow grants the attacker an astronomically large balance.

## Real-World Reference

The BEC (Beauty Chain) token hack (2018) exploited an integer overflow in `batchTransfer()` where `amount * receivers.length` overflowed to zero, bypassing the balance check while still crediting each receiver the full `amount`. Over $900M in token value was destroyed. This led to multiple exchange delistings and accelerated the adoption of SafeMath across the ecosystem. [BEC Overflow Analysis](https://medium.com/@peckshield/alert-new-batchoverflow-bug-in-multiple-erc20-smart-contracts-cve-2018-10299-511067db6536)