# Delegation

## Vulnerability: Unprotected `delegatecall` in Fallback

**Category:** Access Control / Delegatecall Misuse
**Severity:** Critical
**Target Contract:** [Delegate.sol](./Delegate.sol)

## Analysis

The `Delegation` contract implements a proxy pattern using `delegatecall` inside its `fallback()` function. When a call is made to `Delegation` with data that doesn't match any of its own functions, the fallback triggers and forwards the call to the `Delegate` contract via `delegatecall`.

The critical property of `delegatecall` is that it executes the target contract's **code** in the **caller's storage context**. This means when `Delegate.pwn()` runs via `delegatecall`, the `owner = msg.sender` assignment modifies `Delegation`'s storage (slot 0), not `Delegate`'s.

Since there are no access control checks on who can trigger the fallback, anyone can send a transaction with `pwn()`'s function selector (`0xdd365b8b`) as calldata. The fallback forwards it via `delegatecall`, and the `Delegation` contract's owner is overwritten.

## Exploit Steps

1. Compute the function selector for `pwn()`: `keccak256("pwn()")` → first 4 bytes → `0xdd365b8b`.
2. Send a raw transaction to the `Delegation` contract with `data: 0xdd365b8b`.
3. The fallback catches this call and delegates it to `Delegate`, which executes `owner = msg.sender` in `Delegation`'s storage.

**Solved via browser console:**
```javascript
await web3.eth.sendTransaction({from: player, to: contract.address, data: "0xdd365b8b", gas: 100000})
```

## Real-World Impact: Parity Multisig Hack (2017)

Parity Wallet used a similar proxy + library architecture for gas efficiency. The library contract had an `initWallet()` function that set the wallet owner, but it lacked access control — anyone could call it. A hacker exploited this by calling `initWallet()` through users' proxy wallets via `delegatecall`, taking ownership and stealing **~$30M in ETH**.

## Key Takeaway

When using `delegatecall` in a proxy pattern, ensure that:
1. The fallback function has proper access control (or is intentionally open with safe logic).
2. Any initialization function in the logic contract can only be called once (`initializer` modifier).
3. Storage layouts between the proxy and logic contract are perfectly aligned to prevent **storage collision**.