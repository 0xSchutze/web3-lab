# Level 04: Telephone

**Target:** [Telephone.sol](./Telephone.sol)

## Vulnerability

The `changeOwner()` function uses `tx.origin != msg.sender` as its access control — a condition trivially satisfied by routing the call through an intermediary contract.

```solidity
function changeOwner(address _owner) public {
    if (tx.origin != msg.sender) {
        owner = _owner;
    }
}
```

## Root Cause

Using `tx.origin` for authorization. `tx.origin` always refers to the original EOA, while `msg.sender` changes at each call depth. Any intermediary contract creates the `!=` condition.

## Exploit

Deploy a contract that calls `changeOwner()` — `tx.origin` remains the EOA while `msg.sender` becomes the exploit contract, satisfying the condition.

## Real-World Reference

`tx.origin` phishing is a well-documented attack vector. An attacker tricks the real owner into interacting with a malicious contract (e.g., a fake NFT mint). The malicious contract silently calls the victim's contract — since `tx.origin` is the real owner, any `require(tx.origin == owner)` check passes. This was flagged as a common vulnerability in the [SWC Registry (SWC-115)](https://swcregistry.io/docs/SWC-115).