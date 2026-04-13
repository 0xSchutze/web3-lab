# CoinFlip

## Vulnerability: Insecure On-Chain Randomness (Weak PRNG)

**Category:** Bad Randomness
**Severity:** High
**Target Contract:** [CoinFlip.sol](./CoinFlip.sol)

## Analysis

The contract uses `blockhash(block.number - 1)` divided by a known constant (`FACTOR`) to determine the coin flip outcome. Both values — the previous block hash and the FACTOR — are publicly accessible on-chain. This means the result of the flip is entirely deterministic and predictable.

```solidity
uint256 blockValue = uint256(blockhash(block.number - 1));
uint256 coinFlip = blockValue / FACTOR;
bool side = coinFlip == 1 ? true : false;
```

Since `blockhash` is public knowledge and `FACTOR` is hardcoded in the contract, any attacker can deploy their own contract that performs the exact same calculation within the same block. Because the attacker's contract and the target contract execute in the same transaction (same block), `block.number - 1` returns the same value for both. As a result, the attacker always knows the correct answer before calling `flip()`.

## Exploit Strategy

1. Deploy an attacker contract that mirrors the same math (`blockhash(block.number - 1) / FACTOR`).
2. The attacker contract computes the result on-chain and passes the correct guess to `CoinFlip.flip()`.
3. Repeat this 10 times across 10 different blocks (one call per block to avoid the `lastHash` replay guard).

**Important:** This exploit must run on-chain (inside a deployed contract), not off-chain (in a Foundry script). If computed off-chain, the block number may change by the time the transaction is mined, making the prediction incorrect.

## Exploit Files

- [exploit.sol](./exploit.sol) — On-chain attacker contract that pre-computes the flip result
- [exploit.s.sol](./exploit.s.sol) — Deploys the attacker and saves its address to `address.txt`
- [finishScript.s.sol](./finishScript.s.sol) — Reads the deployed address and fires one attack per invocation

**Usage (bash loop for 10 consecutive wins):**
```bash
for i in {1..10}; do forge script finishScript.s.sol:AttackCoinFlip --rpc-url $RPC --private-key $PK --broadcast; sleep 15; done
```

## Key Takeaway

Never use `blockhash`, `block.timestamp`, or any other on-chain value as a source of randomness. These values are publicly visible and can be predicted or manipulated. For secure randomness, use a verifiable random function (VRF) such as **Chainlink VRF**.