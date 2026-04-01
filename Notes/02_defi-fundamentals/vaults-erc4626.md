# Tokenized Vaults & ERC4626 (Shares vs Assets)

A **Vault** is a Smart Contract designed to hold user tokens (Assets) and put them to work (via Lending, Staking, or Yield Farming) to generate passive income (Yield).

The industry standard structure for Vaults is **ERC4626**.

## The Core Concept: Shares vs Assets

When you deposit your real money (Assets) into a Bank (Vault), the Bank gives you a piece of paper (A "Share") proving you own a percentage of the vault.
- **Assets:** The underlying physical token (e.g., WETH, USDC).
- **Shares:** The receipt token representing your percentage ownership of the Vault pool.

### The Exchange Rate Formula

The conversion between Shares and Assets is dynamic. It is calculated via strict cross-multiplication:

$$ \text{Shares to Mint} = \frac{\text{Assets Deposited} \times \text{Total Shares}}{\text{Total Assets in Vault}} $$

### How Yield (Interest) is Generated

1. **Day 1 (1:1 Ratio)**: Alice deposits 100 USDC. The vault is empty, so it mints her 100 Shares. (1 Share = 1 USDC).
2. **Yield Generation**: The Vault takes Alice's 100 USDC and lends it out. Over a year, it earns 50 USDC in interest.
3. **The Silent Growth**: The Vault now contains **150 USDC** total assets, but the Total Shares remain **100**.
4. **Day 365 (Value Appreciation)**: Bob wants to deposit 150 USDC. Due to the formula: `(150 * 100) / 150 = 100`. Bob deposits 150 USDC but only gets 100 Shares!

> **Why?** Because 1 Share is now worth 1.5 USDC. The Shares absorb the value of the yield *without needing to mint new tokens*. Alice can now burn her original 100 Shares and receive 150 USDC back.

## Mitigation of Inflation Attacks
In early Vaults, hackers could manipulate the exchange rate by executing a "Donate Attack" (sending assets directly to the vault without minting shares), making the first share virtually impossible to afford for new legitimate users. Modern implementations (like OpenZeppelin's ERC4626) mitigate this by introducing internal mathematical buffers (Virtual Assets/Shares) to smooth the exchange rate upon initial creation.
