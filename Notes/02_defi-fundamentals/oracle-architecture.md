# Oracle Architecture & Chainlink Price Feeds

## The Core Problem: Smart Contracts Are Blind

Smart contracts execute on-chain and have no native ability to access external data. A contract cannot call an API, read a database, or observe exchange prices. This limitation is fundamental — any computation that depends on real-world state requires an external data source to push that data on-chain. These data sources are called **Oracles**.

---

## How Chainlink Price Feeds Work

Chainlink operates a decentralized network of off-chain nodes. Each node independently queries major centralized exchanges (Binance, Coinbase, Kraken, etc.) for asset prices at regular intervals. The network then aggregates these values — discarding statistical outliers — and computes a **median price**, which is written to a dedicated on-chain contract (the **Price Feed contract**).

Key properties:
- Data is sourced from multiple exchanges, not a single source of truth.
- Outlier values (e.g., from a price-manipulated exchange) are excluded from the median.
- The on-chain contract holds a simple state variable: `int256 currentPrice`.
- Prices are updated when the deviation threshold is exceeded (typically 0.5% for major pairs).

When your contract calls `priceFeed.latestRoundData()`, it is reading this stored value from a deployed Chainlink contract. It is not making an external network call — it is an on-chain contract-to-contract call.

---

## AggregatorV3Interface

The interface defines the expected function signatures of a Chainlink price feed contract.

```solidity
interface AggregatorV3Interface {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,    // The price
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}
```

By importing this interface and casting an address to it, Solidity knows how to encode the call correctly without needing the full Chainlink contract code.

---

## Decimal Standards

Chainlink uses different decimal precisions depending on the feed type:

| Feed Type | Decimals | Example |
|-----------|----------|---------|
| USD pairs (ETH/USD, BTC/USD) | 8 | `200000000000` = $2000 |
| ETH pairs (LINK/ETH) | 18 | Standard EVM precision |

USD pairs use 8 decimals to match the **Satoshi standard** (Bitcoin's smallest unit), which was the original precision convention in blockchain finance.

---

## Precision Math: Aligning Decimals

ETH amounts in Solidity use 18-decimal precision (`1 ETH = 1e18 wei`). Chainlink USD prices use 8 decimals. When multiplying these together the result carries `18 + 8 = 26` decimal places, which must be normalized.

**getConversionRate logic:**
1. Read the price from Chainlink (8 decimals).
2. Scale it up to 18 decimals by multiplying by `1e10`.
3. Multiply by the ETH amount (also 18 decimals).
4. Divide by `1e18` to eliminate the extra precision.

```
result = (ethAmount * (price * 1e10)) / 1e18
```

**Why `int256` → `uint256` casting is required:**
Chainlink returns `int256` to support feeds that can go negative (e.g., temperature, rate differentials). Asset prices cannot be negative, so casting to `uint256` is both safe and semantically correct.

---

## Oracle Manipulation Attack Surface

Because Chainlink aggregates prices from many sources and uses a median, it is resistant to single-exchange price manipulation. However, protocols that use a single DEX pool as their price source (instead of Chainlink) are vulnerable to **Oracle Manipulation Attacks**:

1. Attacker borrows a large amount of capital (often via Flash Loan).
2. Executes a large trade on a low-liquidity DEX pool, temporarily crashing or spiking the price.
3. The target protocol reads this manipulated price and makes decisions based on it (e.g., incorrectly allowing undercollateralized borrowing).
4. Attacker repays the flash loan in the same transaction, keeping the profit.

This attack pattern is responsible for a significant portion of historical DeFi exploits.

---

## Mock Testing Pattern

In a test environment, Chainlink's node network does not exist. To simulate it:

1. Deploy `MockV3Aggregator` (provided by Chainlink) with an initial price.
2. Inject the mock's address into the contract under test via the constructor.
3. The contract calls `latestRoundData()` on the mock, which returns the preset value.
4. Use `updateAnswer()` on the mock to simulate real-time price changes within tests.

```solidity
// In setUp()
MockV3Aggregator mock = new MockV3Aggregator(8, 2000e8); // 8 decimals, $2000 initial price
PriceReader reader = new PriceReader(address(mock));
```

This pattern eliminates all external dependencies from the test suite and allows precise scenario control, including adversarial price scenarios.

---

## Deploy Scripts (forge script)

A deploy script is a Solidity contract that inherits from `Script` and contains a `run()` function. The `vm.startBroadcast()` / `vm.stopBroadcast()` pair marks the section where real transactions will be sent to the network.

```
vm.startBroadcast()  →  everything here becomes a real on-chain transaction
vm.stopBroadcast()   →  back to simulation
```

Scripts are used instead of direct `forge create` commands because complex deployments require sequencing multiple contracts — passing addresses from one deployment to the next — which cannot be done cleanly from the terminal.

---

## Sepolia Reference

- ETH/USD Price Feed (Sepolia): `0x694AA1769357215DE4FAC081bf1f309aDC325306`
