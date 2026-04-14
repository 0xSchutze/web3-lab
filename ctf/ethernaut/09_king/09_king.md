# Level 09: King

**Target:** [King.sol](./King.sol)

## Vulnerability

Denial of Service (DoS) via forced revert on ETH transfer.

The `receive()` function uses `transfer()` to pay out the previous king before updating state. If the recipient contract has no `receive()` function or one that always reverts, the `transfer()` call fails and the entire transaction reverts — permanently locking the throne.

```solidity
// King.sol — vulnerable pattern
receive() external payable {
    require(msg.value >= prize || msg.sender == owner);
    payable(king).transfer(msg.value);  // if this reverts, nobody can become king
    king = msg.sender;
    prize = msg.value;
}
```

## Root Cause

`transfer()` forwards exactly 2300 gas and **propagates reverts** to the caller. Using `call()` instead would allow the caller to handle failures gracefully (Pull over Push pattern).

## Exploit

Deploy a contract with a reverting `receive()`. Send ETH equal to the current prize — this contract becomes king. Any future attempt to dethrone it fails because `transfer()` to this contract always reverts.

## Real-World Reference

The **King of the Ether Throne** (KotET) contract suffered exactly this bug — a contract that couldn't receive ETH permanently blocked the game. The **GovernMental** Ponzi scheme (2016) had a similar DoS issue where accumulated gas costs in a loop made the payout transaction exceed the block gas limit, locking ~1100 ETH for months. The fix is the "Pull over Push" pattern: instead of pushing ETH to recipients, let them withdraw (pull) it themselves. [KotET Post-Mortem](https://www.kingoftheether.com/postmortem.html)