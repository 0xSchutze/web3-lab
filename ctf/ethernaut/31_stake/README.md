# Level 31: Stake

**Target:** [Stake.sol](./Stake.sol)
**Exploit:** [exploit.sol](./exploit.sol) | [exploitScript.s.sol](./exploitScript.s.sol)

## Vulnerability

`Stake` contract tracks staking balances in `UserStake` and a global `totalStaked` counter, but `StakeWETH` updates both accounting variables **before** verifying the actual ERC-20 transfer succeeded. Additionally, the ETH staking path (`StakeETH`) allows a malicious contract to be registered as a staker while keeping the ETH locked inside the attacker contract — inflating `totalStaked` without a corresponding increase in the contract's real ETH balance.

## Key Concepts

**Check-Effect-Interaction (CEI) Violation**
`StakeWETH` increments `totalStaked` and `UserStake[msg.sender]` before executing the `transferFrom` call. If the transfer fails (or is silently ignored via an unchecked return value), the accounting is permanently corrupted: the user appears to have staked funds they never actually sent.

**Return Value Not Checked**
The `transferFrom` result (`transfered`) is returned to the caller but never `require`'d inside the function. A failed ERC-20 transfer silently inflates balances.

**Phantom ETH Staking via Contract**
`StakeETH` marks `msg.sender` as a staker and adds `msg.value` to `totalStaked`. If `msg.sender` is a malicious contract that forwards ETH into `StakeETH` but immediately refuses any ETH withdrawal (no `receive` function), the Stake contract's `Unstake` call will fail for that address — the ETH is trapped inside the attacker contract, yet `totalStaked` reflects a balance that cannot be recovered.

**Win Conditions (validateInstance)**
To pass this level, all three conditions must hold simultaneously:
1. `totalStaked > address(Stake).balance` — Stake contract believes it holds more ETH than it actually does.
2. `UserStake[player] > 0` — Player is registered as a staker.
3. `Stakers[player] == true` — Player is in the staker set.

## Root Cause

Two independent accounting bugs compound each other:
1. In `StakeWETH`, state is mutated before the external `transferFrom` call, and the return value is not enforced with `require`.
2. In `StakeETH`, there is no mechanism to verify that the staking contract can actually refund (via `Unstake`) the ETH that was credited — allowing a non-receivable contract to inflate `totalStaked` permanently.

## Exploit

The attack is executed in a single broadcast transaction sequence:

**Step 1 — Deploy the attacker contract and stake ETH from it**
```solidity
// Exploit.sol: a contract with no receive() function
function attack() external payable {
    IExploit(target).StakeETH{value: 0.0025 ether}();
}
```
The attacker contract calls `StakeETH` with 0.0025 ETH. This ETH is transferred into the Stake contract and `totalStaked` increases. However, when `Unstake` is later called for this contract's address, the `call{value: amount}("")` will revert because `Exploit` has no `receive()` function — the ETH stays locked, permanently orphaning those funds in `totalStaked`.

**Step 2 — Stake WETH without transferring funds**
```solidity
IExploit(weth).approve(target, type(uint256).max);
IExploit(target).StakeWETH(0.001 ether + 1 wei);
```
Player approves the Stake contract to move WETH, then calls `StakeWETH`. The accounting is updated first; the actual `transferFrom` executes but the result is not enforced. Even if WETH is actually transferred, the net effect is:

| State Variable | Before | After |
|---|---|---|
| `totalStaked` | `X` | `X + 0.0025 ETH + 0.001 ETH + 1 wei` |
| `address(Stake).balance` | `X` | `X + 0.0025 ETH` (WETH is ERC-20, not ETH) |
| `UserStake[player]` | `0` | `0.001 ETH + 1 wei` |
| `Stakers[player]` | `false` | `true` |

**Step 3 — Unstake player's WETH position to zero out real balance**
```solidity
IExploit(target).Unstake(0.001 ether + 1 wei);
```
Player withdraws the WETH position. This sends ETH out of the contract (reducing `address(Stake).balance`), while `totalStaked` remains inflated by the 0.0025 ETH locked inside the attacker contract. All three win conditions are satisfied.

## Real-World Reference

**Reentrancy-adjacent accounting bugs — various DeFi protocols (2020–2023)**
While not a reentrancy attack, this is a classic instance of the broader CEI violation family. The Qubit Finance hack (January 2022, ~$80M) exploited a similar pattern where a cross-chain bridge contract registered deposits without verifying actual asset receipt, inflating the internal accounting and allowing attackers to mint unbacked assets on the destination chain.
