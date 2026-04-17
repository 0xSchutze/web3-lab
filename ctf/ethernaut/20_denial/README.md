# Level 20: Denial

**Target:** [Denial.sol](./Denial.sol)
**Exploit:** [exploit.sol](./exploit.sol)

## Vulnerability

Denial of Service via gas exhaustion. The `withdraw()` function sends funds to a partner using low-level `call`, which forwards nearly all remaining gas (63/64 per EIP-150). A malicious partner can consume all forwarded gas with an infinite loop in `receive()`, causing the subsequent `owner.transfer()` to fail due to insufficient gas — permanently blocking withdrawals.

## Key Concepts

**`call` vs `transfer`/`send`:** `transfer` and `send` cap gas at 2300 — not enough for complex logic, but enough to prevent most gas-drain attacks. `call` forwards up to 63/64 of available gas by default, making it dangerous when the recipient is untrusted.

**EIP-150 (63/64 rule):** When a contract calls another, it can forward at most 63/64 of its remaining gas. The remaining 1/64 is reserved for the caller to continue after the call returns (or reverts). An attacker that consumes all 63/64 leaves the caller with too little gas to execute `transfer()`, which requires ~2300 gas minimum.

**`receive()` as attack surface:** Any ETH sent via `call` (with no calldata) triggers `receive()`. There is no restriction on complexity — an infinite loop is valid Solidity.

## Exploit

```solidity
contract Exploit {
    receive() external payable {
        while (true) {}  // consume all forwarded gas
    }
}
```

Then register this contract as the withdraw partner:

```solidity
IExploit(target).setWithdrawPartner(address(exploit));
```

When `withdraw()` is called, `partner.call{value: ...}("")` triggers `receive()`, the loop exhausts the 63/64 gas allocation, and `owner.transfer(...)` has no gas left to execute.

## Root Cause

Unrestricted `call` to an untrusted external address, combined with no gas limit on the call. The fix is either: (1) add a gas cap `partner.call{value: ..., gas: 2300}("")`, (2) use a pull-payment pattern instead of push, or (3) add a reentrancy guard that limits loop depth.

## Real-World Reference

Push-payment patterns with uncapped `call` remain a live risk in protocols that iterate over recipient arrays (e.g., reward distributors, airdrop contracts). The **GovernMental Ponzi (2016)** was a real case where a `send` loop became permanently stuck because one recipient was a contract with a failing fallback, blocking all payouts. The modern equivalent uses `call` with no gas cap, which shifts the risk from revert-blocking to gas-drain DoS.
