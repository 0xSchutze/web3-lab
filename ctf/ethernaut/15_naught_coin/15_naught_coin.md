# Level 15: Naught Coin

**Target:** [NaughtCoin.sol](./NaughtCoin.sol)

## Vulnerability

Incomplete access control on ERC20 token transfer mechanisms. The developer overrode `transfer()` with a 10-year timelock modifier but left the inherited `approve()` + `transferFrom()` pathway completely unprotected.

## Key Concepts

**ERC20 dual-transfer model:** The ERC20 standard defines two independent ways to move tokens:
1. `transfer(to, amount)` — direct transfer by the token holder.
2. `approve(spender, amount)` + `transferFrom(from, to, amount)` — delegated transfer via allowance mechanism.

**Inheritance blind spot:** `NaughtCoin` inherits from OpenZeppelin's `ERC20`. The `lockTokens` modifier was applied only to the overridden `transfer()`. All other inherited public functions (`approve`, `transferFrom`, `increaseAllowance`, etc.) remain accessible without restriction.

## Root Cause

Selective override without comprehensive coverage. When overriding a parent contract's function for access control, **all** alternative pathways that achieve the same outcome must also be restricted. The developer protected one door but left the back door wide open.

## Exploit

No intermediary contract needed — the entire bypass is executed from the EOA via the Foundry deployment script:

```solidity
IExploit(target).approve(msg.sender, totalSupply);
IExploit(target).transferFrom(msg.sender, expl, totalSupply);
```

The EOA approves itself (or any address) to spend the full balance, then uses `transferFrom` to move all tokens out — completely bypassing the timelocked `transfer()`.

## Real-World Reference

This pattern maps directly to real-world token lockup bypasses. Several vesting contracts and token lock implementations have been exploited because they only restricted `transfer()` without accounting for `transferFrom()`. The mitigation is to override `_transfer()` (the internal function) or apply the modifier to `_beforeTokenTransfer()` — hooks that catch **all** transfer paths regardless of the entry point.