<div align="center">
  <h1>Mini Staking Protocol</h1>
  <p><strong>A self-directed study laboratory project exploring time-weighted O(1) reward math distribution based on the Synthetix linear staking architecture.</strong></p>
</div>

---

> [!WARNING]  
> **Not for Production**  
> This protocol is built explicitly to study the internal mechanics of standard DeFi architectures. The smart contracts within have not been formally audited and may contain intentional or unintentional vulnerabilities. Do not deploy or use with real value.

## Implementation Details
This protocol implements a classic linear staking model. A naive approach to distributing rewards to a changing pool of stakers would require iterating through an array of all users (a gas-heavy `for-loop`).

To avoid the block gas limit, this architecture bounds time-deltas to a global accumulator function (`rewardPerTokenStored`). The reward share is dynamically calculated using the difference between the global pool state and the user's last known snapshot state, maintaining **O(1) time complexity**.

### Technical Constraints Addressed
During development, several standard Ethereum Virtual Machine (EVM) constraints were mapped and accounted for in the contract logic:

- **State Sync & Reentrancy**: Implemented the Checks-Effects-Interactions (CEI) pattern. User balances (`totalStakingToken`, `rewardTokenBalance`) are explicitly zeroed or decremented prior to any external `transfer()` execution.
- **Precision Truncation**: Solidity's lack of floating-point arithmetic causes truncation on temporal division. This is natively handled by pre-multiplying numerator variables by a `1e18` scale factor before distributing blocks over time.
- **Unchecked Call Risks**: Standard ERC20 token interactions (`transfer`, `transferFrom`) evaluate to a boolean rather than reverting automatically. These are wrapped in logical `require` validations to ensure state revert on partial failure.
- **Contract Code Size Limits**: Heavy modifier logic (`updateReward`) processing continuous snapshot data was refactored into an `internal` helper function (`_updateReward`) to preserve contract bytecode limits upon deployment.

## Installation & Setup
Requires [Foundry](https://getfoundry.sh/). No external library dependencies.

```bash
# Clone the repository and navigate into the project
git clone https://github.com/0xSchutze/web3-lab.git
cd web3-lab/contracts/04_mini-staking-protocol

# Install dependencies
forge install foundry-rs/forge-std

# Compile
forge build

# Run the invariant test suite
forge test -vvv
```

## Invariant Tests
The test suite validates that reward distribution remains mathematically precise across multiple stakers, time windows, and stake amounts.

<details>
<summary>View Core Distribution Proof</summary>

*Scenario: A pool distributes rewards at a rate of 20 tokens/second over a 5-second window (100 total). Alice enters at T=0 with 10 tokens. Bob enters at T=2 with 30 tokens. Expected distribution: Alice receives 55, Bob receives 45 — proportional to capital locked per second elapsed.*

```text
[PASS] test_StakingMathematics() (gas: 325143)
Logs:
  Alice's rewards: 55
  Bob's rewards: 45
```
</details>

---
*Part of the `web3-lab` research progression: Vaults → AMMs → Staking.*
