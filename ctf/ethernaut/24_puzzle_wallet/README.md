# Level 24: Puzzle Wallet

**Target:** [PuzzleWallet.sol](./PuzzleWallet.sol)
**Script:** [exploitScript.s.sol](./exploitScript.s.sol)

---

## Vulnerability

`PuzzleProxy` and `PuzzleWallet` share the same storage layout but define different state variables at overlapping slots, creating a dual storage collision. Additionally, `multicall()` enforces a `depositCalled` guard using a local variable, which resets on each recursive invocation — allowing a nested call to credit `msg.value` twice.

---

## Key Concepts

**Storage Collision (Slot Aliasing)**
EVM storage is a flat key-value map of 32-byte slots. When a proxy delegates to an implementation, both contracts operate on the proxy's storage. If their state variable declarations do not match slot-for-slot, reading or writing through the implementation corrupts the proxy's own variables.

| Slot | PuzzleProxy    | PuzzleWallet |
|------|----------------|--------------|
| 0    | `pendingAdmin` | `owner`      |
| 1    | `admin`        | `maxBalance` |

**`multicall()` Re-entrancy via Nested Delegation**
The guard `bool depositCalled = false` is a function-local variable. Each call to `multicall()` (including recursive delegatecalls from within itself) initialises its own fresh copy of this flag. A second `deposit()` inside a nested `multicall()` therefore bypasses the guard entirely, allowing `msg.value` to be recorded in `balances[]` a second time within the same transaction.

---

## Root Cause

1. The proxy author did not align the storage layout between `PuzzleProxy` and `PuzzleWallet`, enabling writes to implementation variables to silently overwrite proxy admin state.
2. The `multicall()` developer assumed a transaction-scoped `depositCalled` flag would prevent re-use of `msg.value`, but the flag is stack-local and is re-initialised on every delegatecall frame.

---

## Exploit

The attack is executed in five sequential steps within a single script:

**Step 1 — Claim ownership via Slot 0 collision**
```solidity
IExploit(target).proposeNewAdmin(msg.sender);
```
`proposeNewAdmin` writes `msg.sender` to `PuzzleProxy.pendingAdmin` (Slot 0). Because `PuzzleWallet.owner` also lives at Slot 0, the implementation now treats the attacker as `owner`.

**Step 2 — Whitelist the attacker**
```solidity
IExploit(target).addToWhitelist(msg.sender);
```
Now recognised as `owner`, the attacker can whitelist any address. This is required by the `onlyWhitelisted` modifier on `multicall`, `deposit`, and `execute`.

**Step 3 — Double-count `msg.value` via nested `multicall`**
```solidity
bytes[] memory depositData = new bytes[](1);
depositData[0] = abi.encodeWithSelector(IExploit.deposit.selector);

bytes memory nestedMulticall = abi.encodeWithSelector(IExploit.multicall.selector, depositData);

bytes[] memory finalData = new bytes[](2);
finalData[0] = depositData[0];          // outer: deposit()
finalData[1] = nestedMulticall;         // outer: multicall([deposit()])

IExploit(target).multicall{value: 0.001 ether}(finalData);
```

| Frame         | `depositCalled` | Action                  | `balances[attacker]` |
|---------------|-----------------|-------------------------|----------------------|
| outer loop i=0 | `false → true` | `deposit()` executes   | +0.001 ether         |
| outer loop i=1 | selector ≠ deposit | inner `multicall()` starts | —              |
| inner loop i=0 | `false` (fresh) | `deposit()` executes   | +0.001 ether         |

The contract receives `0.001 ether` but records `0.002 ether` in `balances[attacker]`.

**Step 4 — Drain the contract**
```solidity
IExploit(target).execute(msg.sender, 0.002 ether, "");
```
`balances[attacker]` (0.002) >= `value` (0.002), so the check passes. The full balance is transferred out. Contract ETH balance is now zero.

**Step 5 — Overwrite the admin slot via Slot 1 collision**
```solidity
IExploit(target).setMaxBalance(uint256(uint160(msg.sender)));
```
`setMaxBalance` requires `address(this).balance == 0` — satisfied. It writes `_maxBalance` to Slot 1 (`maxBalance`). Due to the collision, this simultaneously overwrites `PuzzleProxy.admin` (also Slot 1) with the attacker's address cast to `uint256`.

---

## Real-World Reference

The storage collision pattern is the root cause of several high-profile proxy upgrade incidents. The most studied case is the **Audius governance exploit (July 2022)** — an attacker reinitialised an upgradeable contract's storage by exploiting a mismatch between the proxy and implementation slot layout, granting themselves 10 trillion governance tokens. The delegatecall-based `msg.value` accounting confusion is structurally identical to vulnerabilities found in several on-chain router and vault contracts audited on Solodit, where batched call handlers failed to account for value re-use across nested calls.
