# Automated Market Makers (AMM) & CPMM Math

Unlike traditional Web2 centralized exchanges (like Binance) that use an **Order Book** (matching buyers with sellers), Web3 Decentralized Exchanges (DEXs like Uniswap V2) use **Automated Market Makers (AMMs)**.

The most famous algorithm is the **Constant Product Market Maker (CPMM)**.

## The Golden Rule: $x \times y = K$

The entire pricing mechanism revolves around a simple inverse proportion formula:
- **$x$** = The reserve (quantity) of Token A in the pool.
- **$y$** = The reserve (quantity) of Token B in the pool.
- **$K$** = The constant product (which must remain the same before and after a swap, excluding fees).

### Slippage (Price Impact)
When a user buys a large chunk of Token A from the pool, the reserve of Token A (`x`) drops significantly. To maintain the constant $K$, the price of Token A algorithmically skyrockets. This built-in mechanic prevents a "Whale" from ever fully draining the pool, as the token price will approach infinity as the reserve approaches zero.

## 1. Adding Liquidity (Becoming an LP)

Investors deposit token pairs into the Smart Contract to earn trading fees. In return, the contract mints them a "receipt" called an **LP Token** (Liquidity Provider Token).

### Genesis Minting (The First Depositor)
The first person sets the initial ratio (Price). They receive shares based on the geometric mean of their deposit:
`shares = Math.sqrt(amountA * amountB)`

### Proportional Minting (Subsequent Depositors)
Anyone joining later must deposit tokens at the exact current ratio of the pool. Their shares are calculated using cross-multiplication against the `totalSupply` of existing LP tokens:
`shareA = (amountA * totalSupply) / reserveA`
`shareB = (amountB * totalSupply) / reserveB`
*(The contract always takes the `Math.min` of the two to penalize unbalanced/malicious deposits).*

## 2. Swapping (Trading Mechanism)

When a user swaps tokens, the contract deducts a fee (e.g., 0.3%) *before* calculating the exact amount of tokens to return. 
To avoid float/decimal errors in Solidity, we use **Basis Points** (multiplying by 1000):

```solidity
uint256 amountInWithFee = amountIn * 997; // 0.3% fee deducted
uint256 amountOut = (amountInWithFee * reserveOut) / ((reserveIn * 1000) + amountInWithFee);
```

## 3. Removing Liquidity (Burning LP)
When an investor wants to leave, they burn (`_burn`) their LP tokens. The contract calculates their proportional percentage of the *current* pool (which now includes accumulated fees) and returns both underlying assets:
`amountA = (amountLP * reserveA) / totalSupply;`

> **Security Note:** Always calculate incoming token amounts by measuring the manual difference in the contract's balance (`balanceOf(address(this)) - reserve`) before and after the transfer. This protects the AMM against **Fee-on-Transfer (Poison)** tokens.
