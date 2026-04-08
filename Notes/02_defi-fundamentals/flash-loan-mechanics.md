# Flash Loan Mechanics

## What Is a Flash Loan?

A flash loan is an uncollateralized loan that must be repaid within the exact same transaction it was taken in. No credit check. No identity. No collateral. The only rule: return the principal plus fee before the transaction ends, or the entire transaction reverts.

This sounds paradoxical. The reason it works is EVM atomicity: a transaction either completes in full or reverts in full. The blockchain has no memory of a partially executed state. If the borrower cannot repay, the ledger treats the loan as if it never happened — so the lender bears zero financial risk.

---

## The Lifecycle

Every flash loan follows the same sequence within a single transaction:

```
requestFlashLoan(token, amount)
    └─► Provider.flashLoan(receiver, token, amount)
            │
            ├─ 1. Read balanceBefore
            ├─ 2. Check balanceBefore >= amount
            ├─ 3. Transfer amount → receiver
            ├─ 4. Call receiver.executeOperation()   ← control switches here
            │         (receiver does its work here)
            │         (must transfer amount + fee back to provider)
            ├─ 5. Read balanceAfter
            └─ 6. Require balanceAfter >= balanceBefore + fee
```

Step 4 is where the borrowed capital is used. Everything after step 3 and before step 6 is in the borrower's hands. They can interact with any protocol, any contract, any logic. Step 6 is the only enforcement mechanism — a pure mathematical check.

---

## Why the Balance Check Works

The provider does not track "who owes what." It simply reads its own token balance before and after the callback and requires that it increases by at least the fee amount.

This is more robust than tracking repayment explicitly because:
- It cannot be manipulated by sending a different token
- It works regardless of how the repayment was routed
- It does not depend on any state the receiver reports back

If the receiver fails to repay, the `require` fails, and every state change — including the original transfer — is reverted by the EVM.

---

## Fee Calculation

```solidity
fee = amount * FEE_BASIS_POINTS / BASIS_POINTS_DIVISOR
    = amount * 9 / 10000
    = 0.09% of amount
```

Basis points (bps) are the standard financial unit for small percentages:
- 1 bps = 0.01%
- 9 bps = 0.09%
- 100 bps = 1%

Aave v2 uses 9 bps. Uniswap v2 uses 30 bps (same as its swap fee). Balancer v2 historically used 0 bps.

The fee can be low because the protocol takes on zero credit risk — repayment is enforced by the EVM, not by legal contract or reputation.

---

## Provider / Receiver Architecture

Flash loan systems separate concerns into two contracts with distinct responsibilities:

| Role | Contract | Responsibility |
|---|---|---|
| Lender | `FlashLoanProvider` | Hold liquidity, enforce repayment, collect fee |
| Borrower | `FlashLoanReceiver` | Receive funds, execute strategy, repay |

The provider does not know what the receiver does with the money. It only knows:
1. Did I get my funds back?
2. Was the fee included?

This is **Inversion of Control**: the provider defines the rules of the callback (the `IFlashLoanReceiver` interface), and the borrower implements them however they want.

The interface separating them (`IFlashLoanProvider`) is what allows the receiver to be written independently of the provider's full implementation. In production, a receiver would import Aave's interface — not Aave's full codebase.

---

## The `approve` Model vs. Balance Check Model

Two repayment approaches exist in production protocols:

**Balance check model (Uniswap-style):**
- Provider transfers funds to receiver
- Receiver executes logic, then directly transfers `amount + fee` back to provider
- Provider verifies its own balance increased

**Pull model (Aave v2-style):**
- Provider transfers funds to receiver
- During `executeOperation`, receiver calls `token.approve(provider, amount + fee)`
- Provider calls `token.transferFrom(receiver, provider, amount + fee)` to pull the funds back

Both are safe. The balance check model is simpler. The pull model is more explicit about the repayment flow.

---

## Use Cases

### Arbitrage
A price discrepancy exists between two DEXes: Token A is $10 on UniSwap and $10.10 on SushiSwap. The profit per unit is small. A flash loan amplifies this:

1. Borrow 1,000,000 USDC
2. Buy Token A on UniSwap
3. Sell Token A on SushiSwap
4. Repay 1,000,000 + fee USDC
5. Keep the profit

No personal capital required. The entire arbitrage is atomic — it either succeeds profitably or reverts with no loss (except gas).

### Liquidation
In lending protocols (Aave, MakerDAO), if a user's collateral value falls below a threshold, their position can be liquidated. A liquidator repays their debt and receives their collateral at a discount. Flash loans allow anyone to liquidate large positions without holding the required capital upfront.

### Collateral Swap
A user with 100 ETH locked as collateral on MakerDAO wants to switch to WBTC. Normally this requires repaying the DAI debt first. With a flash loan:
1. Borrow DAI
2. Repay the DAI debt
3. Withdraw the ETH collateral
4. Swap ETH → WBTC
5. Re-deposit WBTC as new collateral
6. Borrow new DAI to repay flash loan

All in one transaction.

### Protocol Exploits (Attack Use Case)
Flash loans are the most common amplification tool in DeFi attacks. A flash loan gives a temporarily unlimited capital base to any attacker. See the Oracle Manipulation section in `oracle-architecture.md` for how this plays out against protocols that use on-chain spot prices.

---

## What Flash Loans Cannot Do

- **Steal from a mathematically secure protocol.** If a protocol's repayment check is correct, a flash loan cannot bypass it — the revert unwinds everything.
- **Cross transaction boundaries.** A flash loan cannot borrow in block N and repay in block N+1. The atomicity guarantee requires repayment within the same transaction.
- **Escape gas limits.** Complex nested strategies consume gas. The block gas limit caps how complex a single flash loan can be.

---

## Reference Implementation

→ [`contracts/06_flash-loan/`](../../contracts/06_flash-loan/)
