# EVM Execution Model & Reentrancy

## The EVM Is Single-Threaded

The Ethereum Virtual Machine processes transactions sequentially. No two transactions execute in parallel — they are ordered within a block and run one after another. This eliminates race conditions common in concurrent systems (where two threads modify shared state simultaneously).

What this means in practice:
- No two transactions can observe each other's intermediate state
- A transaction either atomically completes or atomically reverts
- State changes from one transaction are only visible after it fully settles

---

## The Call Stack

When contract A calls a function on contract B, the EVM does not start a new transaction. The call happens **synchronously within the same transaction**, on the same call stack.

The key rule: **A pauses and waits for B to finish before it continues.**

```
Transaction starts
    └─► A.someFunction()
            └─► B.anotherFunction()    ← A is paused here
                    └─► C.thirdFunction()   ← B is paused here
                    └─ C returns           ← B resumes
            └─ B returns               ← A resumes
    └─ A returns
Transaction ends
```

This is **synchronous execution**. The EVM has one execution pointer. When a call is made, control passes to the callee. When the callee returns, control passes back. No parallelism.

---

## Why This Creates Reentrancy

Reentrancy is not two transactions racing. It is one transaction's execution re-entering a function before it has finished.

The precondition is: contract A calls into external code (contract B) **before** updating its own state. If B contains logic that calls back into A, the call stack re-enters A's function while A's state is still in its pre-update form.

### Classic Example: ETH Withdrawal

```solidity
// VULNERABLE
function withdraw() public {
    uint256 balance = balances[msg.sender];  // 1. Read state (100)
    require(balance > 0);

    (bool ok,) = msg.sender.call{value: balance}("");  // 2. Send ETH → control leaves
    require(ok);

    balances[msg.sender] = 0;  // 3. Update state ← never reached if reentered
}
```

If `msg.sender` is a contract with a `receive()` function, step 2 transfers execution to that contract. That contract can then call `withdraw()` again. When it does, step 1 reads the **same balance** (state was never updated at step 3). The attacker drains the contract recursively.

### The receive() Hook

Native ETH transfers to contract addresses automatically invoke the `receive()` function (or `fallback()` if `receive` is absent). This is the mechanism that allows reentrancy on ETH transfers — the transfer itself is the trigger.

```solidity
// Attacker contract
receive() external payable {
    if (address(victim).balance >= 1 ether) {
        victim.withdraw();  // re-enter before state update
    }
}
```

---

## Reentrancy Beyond ETH

Any external call hands control to the callee. Reentrancy is not limited to ETH transfers.

### ERC-721 (NFT) Reentrancy
`safeTransferFrom` checks that the recipient contract implements `onERC721Received`. This is a hook — the recipient's code runs during the transfer. A malicious recipient can call back into the sender's contract before its state is updated.

### ERC-777 Token Reentrancy
ERC-777 adds hooks (`tokensReceived`, `tokensToSend`) that notify contracts on every transfer. This was used to drain UniSwap V1 pools — the hooks fire during the swap, before the pool updates its reserves.

### Flash Loan Callback Reentrancy
`executeOperation` is an externally triggered callback. If the provider does not use a `nonReentrant` guard, an attacker could call `flashLoan()` again from inside `executeOperation` before the first loan's balance check runs.

### Read-Only Reentrancy
The subtlest variant. An attacker reenters a contract (via callback) not to steal directly from it, but to read its **corrupted intermediate state** from a third protocol that uses it as a price source.

During a reentrancy window, the victim's stored price or balance may not reflect reality. A lending protocol that reads from the victim at this moment can be tricked into making incorrect decisions (e.g., accepting undercollateralized positions).

---

## The CEI Pattern (Checks-Effects-Interactions)

The standard defense against reentrancy. Structure every function in this order:

1. **Checks** — validate all inputs and preconditions (`require` statements)
2. **Effects** — update contract state
3. **Interactions** — call external contracts

```solidity
// SECURE — CEI order
function withdraw() public {
    uint256 balance = balances[msg.sender];  // CHECK
    require(balance > 0);

    balances[msg.sender] = 0;  // EFFECT (state updated first)

    (bool ok,) = msg.sender.call{value: balance}("");  // INTERACTION (last)
    require(ok);
}
```

Now if the attacker reenters, `balances[msg.sender]` is already 0 — the `require` at the top fails immediately.

The `nonReentrant` modifier (from OpenZeppelin's `ReentrancyGuard`) is an alternative: it sets a lock flag on entry and clears it on exit, preventing any reentrant call while the function is executing. CEI is preferred when possible because it requires no additional state and costs less gas.

---

## Concurrency vs. Reentrancy

| | Concurrency (Race Condition) | Reentrancy |
|---|---|---|
| Actors | Two separate callers | One caller, same call stack |
| Mechanism | Parallel execution | Recursive re-entry via external call |
| Possible in EVM? | **No** — sequential execution | **Yes** — synchronous callbacks |
| Defense | N/A (not applicable) | CEI pattern, ReentrancyGuard |

---

## Reference

→ Flash loan context: [`contracts/06_flash-loan/`](../../contracts/06_flash-loan/)
→ Historical example: The DAO Hack (2016) — reentrancy on ETH withdrawal, $60M drained
