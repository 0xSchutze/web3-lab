# Level 03: CoinFlip

**Target:** [CoinFlip.sol](./CoinFlip.sol)

## Vulnerability

The coin flip outcome is derived from `blockhash(block.number - 1)` divided by a hardcoded constant. Both values are publicly accessible on-chain, making the result fully deterministic and predictable.

```solidity
uint256 blockValue = uint256(blockhash(block.number - 1));
uint256 coinFlip = blockValue / FACTOR;
bool side = coinFlip == 1 ? true : false;
```

## Root Cause

Using on-chain block data as a source of randomness. Any contract executing in the same block has access to the same `blockhash`, so it can pre-compute the result before calling `flip()`.

## Exploit

Deploy an attacker contract that mirrors the same math in the same block, then passes the correct guess to `flip()`. Repeat across 10 blocks (one call per block due to the `lastHash` replay guard).

```bash
for i in {1..10}; do forge script finishScript.s.sol --rpc-url $RPC --private-key $PK --broadcast; sleep 15; done
```

Must run on-chain (inside a deployed contract). Off-chain computation risks block number changing before the tx is mined.

## Real-World Reference

The SmartBillions lottery (2017) used `blockhash` for randomness and was drained of 400 ETH. Miners and MEV bots can also manipulate `block.timestamp` within a ~15 second window to influence outcomes. Secure randomness requires an off-chain oracle like [Chainlink VRF](https://docs.chain.link/vrf).