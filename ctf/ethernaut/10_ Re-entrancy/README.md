# Level 10: Re-entrancy

**Target:** [Re-entrancy.sol](./Re-entrancy.sol)

## Vulnerability

Classic re-entrancy: state is updated **after** an external call, allowing recursive draining before balances are decremented.

```solidity
// Reentrance.sol — vulnerable pattern
function withdraw(uint _amount) public {
    if (balances[msg.sender] >= _amount) {
        (bool result,) = msg.sender.call{value: _amount}("");  // external call first
        if (result) {
            balances[msg.sender] -= _amount;  // state update after — too late
        }
    }
}
```

## Root Cause

Violation of the Checks-Effects-Interactions (CEI) pattern. The balance is decremented after the ETH is sent, so a malicious `receive()` can call `withdraw()` again before the first decrement executes.

## Exploit

1. Donate a small amount to register a balance in the target.
2. Call `withdraw()` — target sends ETH to our contract.
3. In `receive()`, recursively call `withdraw()` again before balance updates.
4. Drain continues until `target.balance == 0`.

## Real-World Reference

**The DAO Hack (June 2016) — $60M drained.** The DAO's `splitDAO()` function sent ETH before updating internal balances, enabling recursive re-entrancy. This single exploit was so catastrophic that the Ethereum community hard-forked the entire chain to reverse it, creating Ethereum (ETH) and Ethereum Classic (ETC). Modern mitigations include the CEI pattern, OpenZeppelin's `ReentrancyGuard` (mutex lock), and Solidity 0.8+'s built-in checks. [The DAO Analysis](https://hackingdistributed.com/2016/06/18/analysis-of-the-dao-exploit/)