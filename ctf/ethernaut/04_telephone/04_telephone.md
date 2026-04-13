# Telephone

## Vulnerability: `tx.origin` for Authorization

**Category:** Access Control
**Severity:** High
**Target Contract:** [Telephone.sol](./Telephone.sol)

## Analysis

The `changeOwner()` function uses `tx.origin != msg.sender` as its access control check. This condition is satisfied when the call is routed through an intermediary contract rather than called directly by an EOA (Externally Owned Account).

- **`tx.origin`**: The original EOA that initiated the entire transaction chain.
- **`msg.sender`**: The immediate caller of the current function (can be a contract or an EOA).

When a user calls the function directly, `tx.origin == msg.sender`, so the condition fails and ownership doesn't change. However, when the call is relayed through an attacker contract, `tx.origin` remains the user's EOA while `msg.sender` becomes the attacker contract's address. This makes `tx.origin != msg.sender` evaluate to `true`, allowing ownership transfer.

## Exploit Files

- [exploit.sol](./exploit.sol) — Intermediary contract that creates the `tx.origin != msg.sender` condition
- [exploitScript.s.sol](./exploitScript.s.sol) — Deploys and executes in a single transaction

## Real-World Impact: Phishing Attacks

In production code, the dangerous pattern is the reverse: using `require(tx.origin == owner)` for authorization. An attacker can trick the real owner into interacting with a malicious contract (e.g., a fake NFT mint). The malicious contract then silently calls the victim's contract. Since `tx.origin` is the real owner (who initiated the transaction), the access check passes, and the attacker drains funds.

## Key Takeaway

Never use `tx.origin` for authorization. Always use `msg.sender`. The `tx.origin` global variable cannot distinguish between a legitimate direct call and a phished relayed call.