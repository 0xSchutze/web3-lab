# Market Mechanics: CEX, DEX and Lending

## Price Discovery in Crypto Markets

There is no central authority that determines asset prices. Every exchange reflects only the price at which its most recent trade was executed. Prices across exchanges converge because of **arbitrage**.

**Arbitrage:** When the same asset trades at different prices on two markets, traders buy on the cheaper exchange and sell on the more expensive one. This increases demand (and price) on the cheap side and increases supply (pushing price down) on the expensive side until both converge. In crypto, this happens in milliseconds via automated bots.

Chainlink exploits this property: rather than relying on one exchange, it aggregates prices across many and takes the median, making it resilient to single-exchange anomalies.

---

## CEX Architecture (Centralized Exchange)

Exchanges like Binance or Coinbase are Web2 companies operating traditional SQL databases.

| Step | What Happens |
|------|-------------|
| Deposit | User sends real ETH to Binance's hot wallet. Binance credits the user's balance in its internal database. |
| Trading | All trades are internal database operations: subtracting from one account, adding to another. Zero on-chain activity. Zero gas. |
| Withdrawal | User requests a withdrawal. Binance sends a real on-chain transaction from its hot wallet to the user's wallet. |

**Implication:** Funds held on a CEX are not under the user's control. The user holds an IOU — a promise from the exchange. If the exchange freezes funds or collapses, the user has no recourse at the protocol level. This is the origin of "not your keys, not your coins."

CEXes can process millions of transactions per second precisely because they never touch the blockchain until a withdrawal occurs.

---

## DEX Architecture (Decentralized Exchange — AMM Model)

DEXes like Uniswap have no order book and no company running a database. Price is determined entirely by the **ratio of assets in a liquidity pool**.

**Constant Product Formula:**
```
x * y = k
```
Where `x` and `y` are the reserves of two tokens and `k` is a constant. Any trade that changes `x` must change `y` proportionally to maintain `k`.

**Price from reserves:**
```
price of token A (in token B) = reserve_B / reserve_A
```

**Price Impact:** Every trade moves the reserves, which changes the price for the next trader. Large trades relative to pool size cause significant **slippage**.

**Price anchoring to real world:**  
A DEX pool has no external data connection. Its prices are kept aligned with the broader market by arbitrageurs who trade against the pool whenever it deviates from prices on CEXes. When an arbitrage opportunity is closed, the pool price reflects market consensus.

---

## WETH and Native Token Wrapping

ETH predates the ERC20 standard. It cannot be used directly in DEX pools or DeFi protocols because it lacks the `transfer`, `approve`, and `transferFrom` functions that the ERC20 interface requires.

**WETH (Wrapped Ether)** is an ERC20 contract where:
- Users deposit ETH and receive WETH 1:1.
- WETH behaves like any other ERC20 token.
- Users can unwrap WETH back to ETH at any time.

This allows ETH to participate in DeFi protocols without changing the core protocol. Solana designed its native token (SOL) to be more composable from the start, reducing but not eliminating the need for wrapped versions (WSOL still exists internally).

---

## Lending Protocol Mechanics

Lending protocols (Aave, Compound) enable users to borrow assets without selling their collateral.

### Why Borrow Instead of Selling?

| Scenario | Sell (Swap) | Borrow (Lending) |
|----------|-------------|------------------|
| Need liquidity | Get cash now, lose upside exposure | Get cash now, keep upside exposure |
| Tax event | Yes — selling is a taxable disposition in most jurisdictions | No — borrowing is not a sale |
| Re-entry cost | Must buy back at (potentially higher) market price | Repay loan + interest, reclaim original asset |

### Overcollateralization

Lending protocols require borrowers to lock more collateral than the value they borrow. This eliminates counterparty risk — if the borrower defaults, the protocol can liquidate the collateral.

```
Collateral value deposited:  $30,000 ETH
Maximum borrow (80% LTV):    $24,000 USDC
```

### Liquidation

A **health factor** tracks the ratio of collateral value to borrowed value. If the collateral price falls (as reported by an Oracle) and the health factor drops below 1, the position becomes liquidatable:

1. Liquidator bots monitor all open positions.
2. When a position is underwater, a liquidator calls the liquidation function.
3. The protocol sells a portion of the collateral at a discount (liquidation bonus) to repay the debt.
4. The liquidator keeps the bonus as incentive.

**Oracle dependency:** Liquidations are triggered by the Oracle-reported price. A manipulated Oracle price can trigger mass false liquidations or prevent legitimate ones — this is a primary attack vector against lending protocols.

### Liquidity Sources for Borrowers

The USDC a borrower receives does not come from the protocol — it comes from **depositors (lenders)** who supply assets to earn yield.

Variable interest rates are set algorithmically by **Utilization Rate**:
```
Utilization = Total Borrowed / Total Supplied
```
- Low utilization → low interest rates (incentivizes borrowers)
- High utilization → high interest rates (incentivizes lenders to supply more, borrowers to repay)

If utilization reaches 100%, borrowing is paused (transaction reverts) until more supply enters the pool.

### No Fixed Repayment Schedule

There is no maturity date in DeFi lending. A borrower can hold a position indefinitely as long as the health factor stays above 1. The only mechanism forcing repayment is the threat of liquidation as interest accrues and/or collateral value declines.

---

## Two-Sided Market Summary

```
Lender  →  supplies USDC  →  earns 5% APY
Borrower → deposits ETH   →  borrows USDC → pays 7% APY
Protocol →                →  keeps 2% spread
```

Every percentage point the borrower pays flows through the protocol to the lender minus the protocol fee. No trust is required between the two parties — the smart contract enforces both sides of the agreement.
