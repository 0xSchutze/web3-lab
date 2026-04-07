# 05 — Oracle Price Feed

A Chainlink price feed integration demonstrating external data consumption, on-chain decimal normalization, mock-based testing, and automated deployment scripting.

## What This Does

- Reads the ETH/USD price from a Chainlink price feed via `AggregatorV3Interface`
- Computes the USD value of a given ETH amount, accounting for decimal precision mismatch (`1e8` Chainlink vs `1e18` EVM)
- Uses `MockV3Aggregator` to simulate price feeds in tests — no live network required
- Includes a deploy script targeting Sepolia testnet

## Key Concepts

| Concept | Implementation |
|---------|---------------|
| On-chain Oracle consumption | `AggregatorV3Interface.latestRoundData()` |
| Decimal normalization | `price * 1e10` to align 8-decimal Chainlink price to 18-decimal EVM standard |
| `int256` → `uint256` casting | Asset prices cannot be negative; cast is semantically correct and safe |
| Mock testing | `MockV3Aggregator(decimals, initialPrice)` injected via constructor |
| Deploy script | `vm.startBroadcast()` / `vm.stopBroadcast()` with Sepolia Chainlink address |

## Structure

```
src/
└── PriceReader.sol         # Oracle reader + USD conversion logic

test/
└── PriceReader.t.sol       # Full test suite using MockV3Aggregator

script/
└── PriceReader.s.sol       # Sepolia deployment script
```

## Setup

```shell
cd web3-lab/contracts/05_oracle-price-feed
forge install foundry-rs/forge-std smartcontractkit/chainlink-brownie-contracts
forge build
```

## Testing

```shell
cd web3-lab/contracts/05_oracle-price-feed
forge test -vvvv
```

## Deploy (Sepolia)

```shell
forge script script/PriceReader.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast
```

### Loading keys from environment variables

Create a `.env` file in this directory:

```
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY
PRIVATE_KEY=0xYOUR_PRIVATE_KEY
```

Then load it before running the script:

```shell
source .env
forge script script/PriceReader.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast
```

> **Never commit your `.env` file.** Add it to `.gitignore`.

## Deep Dive

For a detailed theoretical breakdown of how Oracles function under the hood, why they use 8/18 decimals, and how they become attack surfaces, read the associated technical note:
- [Oracle Architecture & Chainlink Price Feeds](../../Notes/02_defi-fundamentals/oracle-architecture.md)

## Dependencies

- [chainlink-brownie-contracts](https://github.com/smartcontractkit/chainlink-brownie-contracts) — Chainlink interfaces and MockV3Aggregator

## Reference

- Sepolia ETH/USD Feed: `0x694AA1769357215DE4FAC081bf1f309aDC325306`
- [Chainlink Price Feed Docs](https://docs.chain.link/data-feeds)
