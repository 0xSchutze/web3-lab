# CEI (Checks-Effects-Interactions) Pattern

The **Checks-Effects-Interactions (CEI)** pattern is the most critical design pattern in Solidity. It is the primary defense against **Reentrancy Attacks**, which have drained billions of dollars from smart contracts.

The rule is simple: when writing a function that modifies state and makes an external call (like transferring ETH or an ERC20 token), you must strictly follow this order:

1. **Checks:** Validate conditions (e.g., `require` statements).
2. **Effects:** Update the contract's state variables.
3. **Interactions:** Make external calls to other contracts or addresses.

## Why is CEI necessary? (The Reentrancy Attack)

Imagine a contract that allows users to withdraw their deposits. A naive (and vulnerable) implementation looks like this:

```solidity
// Vulnerable to reentrancy
function withdraw() external {
    uint256 balance = userBalances[msg.sender];
    require(balance > 0, "No balance to withdraw"); // 1. Check

    // 2. Interaction (Before Effect)
    (bool success, ) = msg.sender.call{value: balance}("");
    require(success, "Transfer failed");

    // 3. Effect (Updating state AFTER the transaction)
    userBalances[msg.sender] = 0; 
}
```

**The Attack:**
If `msg.sender` is a malicious smart contract, the `call` triggers its `fallback()` or `receive()` function. The attacker's code runs *while the `withdraw` function is paused waiting for the transfer to finish*. 

Inside their `fallback()`, the attacker simply calls `withdraw()` *again*. 
Because `userBalances[msg.sender]` hasn't been set to `0` yet (Step 3 hasn't executed), the `require(balance > 0)` check passes again. The contract sends the money again. This loop continues until the contract is drained.

## The Secure CEI Implementation

By swapping Steps 2 and 3, we completely eliminate the vulnerability:

```solidity
// Secure using CEI pattern
function withdraw() external {
    uint256 balance = userBalances[msg.sender];
    require(balance > 0, "No balance to withdraw"); // 1. Checks
    
    // 2. Effects (Update state BEFORE external call)
    userBalances[msg.sender] = 0;

    // 3. Interactions (External call happens last)
    (bool success, ) = msg.sender.call{value: balance}("");
    require(success, "Transfer failed");
}
```

Now, if the attacker's `fallback()` tries to re-enter `withdraw()`, the first step (`uint256 balance = userBalances[msg.sender];`) will return `0`, and the `require` statement will revert the attack transaction.

## Summary

Never update your contract's internal state *after* making an external call. Assume that any external call hands execution control over to a potentially malicious entity. 

**Always update your state as if the external call has already succeeded, and revert if it actually fails.**
