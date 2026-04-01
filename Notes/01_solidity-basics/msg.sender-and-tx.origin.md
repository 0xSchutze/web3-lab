# msg.sender and tx.origin difference

> [!WARNING]
> tx.origin is dangerous in most situations. Always use msg.sender for authentication.

The difference between msg.sender and tx.origin:

**`msg.sender`** checks who **directly called** this contract.
**`tx.origin`** checks who **started the entire chain** — always the original user (EOA).

## Attack Scenario

### With tx.origin check (vulnerable):

```
User clicks "Get Free NFTs" button
  → triggers MaliciousContract
    → MaliciousContract calls TargetContract.withdraw()
      → tx.origin == User (the real owner) ✅
      → permission granted → funds stolen!
```

The target contract gives permission because `tx.origin` points to the real user at the start of the chain.

### With msg.sender check (safe):

```
User clicks "Get Free NFTs" button
  → triggers MaliciousContract
    → MaliciousContract calls TargetContract.withdraw()
      → msg.sender == MaliciousContract ❌ (not the owner)
      → permission denied → attack blocked!
```

The target contract blocks it because `msg.sender` checks the **last caller**, which is the malicious contract — not the real user.

## Rule

- Auth check → always `msg.sender`
- Never use `tx.origin` for access control
