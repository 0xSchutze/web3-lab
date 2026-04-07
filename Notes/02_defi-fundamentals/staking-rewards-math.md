# Staking Rewards & O(1) Accumulator Math

*Context: Implemented and tested in [04_mini-staking-protocol](../../contracts/04_mini-staking-protocol).*

Distributing continuous rewards to multiple users in a smart contract is a classic engineering problem. If 1,000 users are staking and a new block is mined, updating every user's balance individually would require a `for` loop of 1,000 iterations. This would consume massive amounts of gas and eventually result in an "Out of Gas" revert, bricking the contract.

To solve this, DeFi protocols (like Synthetix) use the **Global Accumulator Pattern** (O(1) complexity).

---

## 1. The Core Concept: `rewardPerToken`

Instead of pushing rewards to users, the protocol simply tracks **how many rewards one single staked token has earned since the beginning of time**. 

Whenever a user stakes, withdraws, or claims, the contract takes a "snapshot" of the current global `rewardPerToken` and saves it to the user's specific state.

### The Math:

```solidity
rewardPerToken = lastRewardPerToken + (timeElapsed * rewardRate) / totalStakedSupply
```

1. We calculate how many total rewards were minted in the `timeElapsed` (`timeElapsed * rewardRate`).
2. We divide those rewards equally among the `totalStakedSupply`.
3. We add this slice to the running total (`rewardPerTokenStored`).

### User Reward Calculation:

When Alice wants to claim her rewards, we look at:
1. The **current** global `rewardPerToken`.
2. The **snapshot** of `rewardPerToken` from the last time Alice interacted.

The difference between these two numbers is precisely how many rewards *one token* earned while Alice was staking. We multiply this difference by Alice's balance.

```solidity
aliceReward = aliceBalance * (currentRewardPerToken - aliceUserRewardPerTokenPaid) + aliceSavedRewards;
```

**Why this is elegant:** This math works instantly regardless of whether there are 10 users or 1,000,000 users. It is perfectly $O(1)$.

---

## 2. The Precision Loss Trap (1e18 Scaling)

Smart contracts do not support floating-point numbers (decimals). If you divide `5` by `10`, the result in Solidity is `0`. 

Look at the `rewardPerToken` formula:
`(timeElapsed * rewardRate) / totalSupply`

What if only 1 second has passed, the `rewardRate` is `100`, but the `totalSupply` is `10,000`?
`(1 * 100) / 10,000 = 0`

The rewards are truncated to `0`. Over time, stakers lose massive amounts of rewards to this "precision loss."

### The Solution: Upscaling and Downscaling

To fix this, we mathematically "shift the decimal point" by multiplying the numerator by a huge number (usually `$1 \times 10^{18}$`), perform the division, and then divide it back down when paying the user.

**The scaled formula:**
```solidity
// Upscale before division
rewardPerToken += (timeElapsed * rewardRate * 1e18) / totalSupply;
```

Now, instead of `100 / 10000 = 0`, we have:
`(100 * 1000000000000000000) / 10000 = 10000000000000000`

When we calculate the user's actual reward, we downscale it:
```solidity
// Downscale after multiplication
reward = (balance * (rewardPerToken - userSnapshot)) / 1e18;
```

**Security Insight:** Precision loss vulnerabilities are extremely common in audit reports. Always ensure that in any division operation, the numerator is significantly larger than the denominator. Scale up before dividing, and scale down only at the very end.

---

## 3. The CEI Pattern in Claiming

When users claim their rewards, the contract must transfer tokens. To prevent Reentrancy attacks, the **Checks-Effects-Interactions (CEI)** pattern is strictly enforced.

*For a detailed explanation of how CEI prevents Reentrancy, read the dedicated note: [CEI Pattern](../01_solidity-basics/cei-pattern.md).*
