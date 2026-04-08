# DeFi Fundamentals (Core Architecture)

Welcome to the Advanced Web3 Engineering section. While "Solidity Basics" covers the syntax of the language, **DeFi Fundamentals** covers the core mathematical algorithms and smart contract design patterns that power multi-billion dollar protocols like Uniswap, Aave, and Yearn Finance.

These are the "Load-Bearing Pillars" of Decentralized Finance.

## Topics

- [Automated Market Makers (AMM) & $x \times y = k$](./amm-math.md)
- [Tokenized Vaults & ERC4626 (Shares vs Assets)](./vaults-erc4626.md)
- [Staking Rewards & O(1) Accumulator Math](./staking-rewards-math.md)
- [Factory Pattern (Smart Contract Architecture)](./factory-pattern.md)
- [Oracle Architecture & Chainlink Price Feeds](./oracle-architecture.md)
- [Market Mechanics: CEX, DEX and Lending](./market-mechanics.md)
- [Flash Loan Mechanics](./flash-loan-mechanics.md)
- [EVM Execution Model & Reentrancy](./evm-execution-model.md)

## Practice Contracts

- [Mini DEX Protocol](../../contracts/03_mini-dex-protocol) — Demonstrating liquidity provision and AMM swap math.
- [Mini Vault Protocol](../../contracts/02_mini-vault-protocol) — Demonstrating ERC4626 concepts and Factory Patterns.
- [Mini Staking Protocol](../../contracts/04_mini-staking-protocol) — Demonstrating Synthetix reward mechanics and precision math.
- [Oracle Price Feed](../../contracts/05_oracle-price-feed) — Chainlink integration, precision math, mock testing and deploy script.
- [Flash Loan](../../contracts/06_flash-loan) — Atomicity, callbacks, zero-collateral borrowing, reentrancy context.
