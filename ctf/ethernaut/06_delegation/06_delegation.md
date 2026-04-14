# Level 06: Delegation

**Target:** [Delegate.sol](./Delegate.sol)

## Vulnerability

The `Delegation` contract forwards any unknown function call to `Delegate` via `delegatecall` in its `fallback()`, with no access control:

```solidity
fallback() external payable {
    (bool result,) = address(delegate).delegatecall(msg.data);
}
```

`delegatecall` executes the target's **code** in the **caller's storage context**. When `Delegate.pwn()` runs via `delegatecall`, `owner = msg.sender` writes to `Delegation`'s slot 0, not `Delegate`'s.

## Root Cause

Unprotected `delegatecall` in a proxy pattern. The fallback forwards arbitrary calldata to the implementation contract without restricting which functions can be invoked or who can invoke them.

## Exploit

Send a raw transaction to `Delegation` with calldata `0xdd365b8b` (the function selector for `pwn()`). The fallback delegates it, and `owner` in `Delegation`'s storage is overwritten.

```javascript
await web3.eth.sendTransaction({from: player, to: contract.address, data: "0xdd365b8b", gas: 100000})
```

Solved via browser console — no exploit contract needed.

## Real-World Reference

**Parity Multisig Hack (July 2017) — $30M stolen.** Parity Wallet used a proxy + library architecture where each wallet proxy delegated calls to a shared implementation. The implementation's `initWallet()` function — which set the wallet owner — had no access control and no single-use guard. An attacker called `initWallet()` on the richest wallet proxies via `delegatecall`, took ownership, and drained ~153,000 ETH. [Parity Post-Mortem](https://www.parity.io/blog/the-multi-sig-hack-a-postmortem)