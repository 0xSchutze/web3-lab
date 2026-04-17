# Level 07: Force

**Target:** [Force.sol](./Force.sol)

## Vulnerability

The contract has no `receive()`, no `fallback()`, and no `payable` functions — yet ETH can still be forced into it via `selfdestruct`.

```solidity
contract Force { /* empty */ }
```

## Root Cause

`selfdestruct(address)` bypasses all Solidity-level ETH acceptance checks. The EVM forcibly credits the target's balance without invoking any code. The target cannot reject or react to the transfer.

## Exploit

Deploy a contract funded with ETH, then call `selfdestruct(targetAddress)`. The contract is destroyed and its entire balance is force-sent to the target.

```solidity
selfdestruct(payable(target)); // target cannot reject this
```

## Real-World Reference

Any contract that uses `address(this).balance` as an invariant is vulnerable. For example, a game contract that checks `require(address(this).balance == expectedPot)` can be bricked by force-sending extra ETH, making the condition permanently fail. This is documented in [SWC-132: Unexpected Ether Balance](https://swcregistry.io/docs/SWC-132). Note: as of Dencun (EIP-6780), `selfdestruct` only removes code when called in the same transaction as deployment — but the forced ETH transfer still works.