# 06 — Flash Loan

A minimal, fully-tested implementation of the flash loan pattern, demonstrating atomic uncollateralized borrowing within the EVM.

Built to understand the mechanics at the execution level — not as a production protocol, but as a precise model of how the pattern works and why it is safe by design.

---

## Architecture

```
IFlashLoanProvider          IFlashLoanReceiver
       │                           │
       ▼                           ▼
FlashLoanProvider ──────► FlashLoanReceiver
   (liquidity pool)         (callback handler)
       │                           │
       └───── IERC20 / MockERC20 ──┘
```

Two roles, two contracts, one interface each:

- **`FlashLoanProvider`** — holds the liquidity pool and issues loans. Enforces repayment via a post-callback balance check. No trust in the receiver — only mathematics.
- **`FlashLoanReceiver`** — implements `executeOperation`, the callback invoked mid-loan. Custom logic (arbitrage, liquidation, collateral swap) is inserted here before repayment.

---

## How It Works

The entire lifecycle runs in a single transaction:

```
requestFlashLoan()
    └─► flashLoan()
            ├─ Check pool has sufficient liquidity
            ├─ Transfer `amount` to receiver
            ├─ Call receiver.executeOperation()   ← logic happens here
            ├─ Check balanceAfter >= balanceBefore + fee
            └─ Emit FlashLoanExecuted
```

If the receiver fails to return `amount + fee` before `executeOperation` returns, the final balance check fails and the **entire transaction reverts atomically** — the provider's balance is restored as if the loan never occurred. This is the property that makes flash loans risk-free for the protocol.

Fee rate: **9 basis points (0.09%)**, matching Aave v2.

---

## Project Structure

```
src/
├── FlashLoanProvider.sol     # Liquidity pool and loan dispatcher
├── FlashLoanReceiver.sol     # Callback receiver and repayment logic
├── MockERC20.sol             # Minimal ERC20 for local testing
├── IERC20.sol                # ERC20 interface (subset)
├── IFlashLoanProvider.sol    # Provider interface (for receiver-side imports)
└── IFlashLoanReceiver.sol    # Receiver interface (enforced by provider)

test/
└── FlashLoan.t.sol           # Two integration tests: success + forced revert

script/
├── MockERC20.s.sol           # Deploy and mint initial supply
├── FlashLoanProvider.s.sol   # Deploy the liquidity pool
└── FlashLoanReceiver.s.sol   # Deploy receiver (reads PROVIDER_ADDRESS from env)
```

---

## Setup

```bash
cd contracts/06_flash-loan
forge install foundry-rs/forge-std --no-git
forge build
forge test -vvvv
```

---

## Key Concepts Demonstrated

| Concept | Where |
|---|---|
| Atomic flash loan lifecycle | `FlashLoanProvider.sol` |
| Callback pattern (`executeOperation`) | `IFlashLoanReceiver.sol`, `FlashLoanReceiver.sol` |
| Post-callback balance validation | `FlashLoanProvider.sol` — final `require` |
| `immutable` for trust-sensitive addresses | `FlashLoanReceiver.sol` — `provider` |
| Caller authentication in callbacks | `FlashLoanReceiver.sol` — `msg.sender == provider` |
| Interface-based decoupling | `IFlashLoanProvider.sol` used by Receiver |
| Forced revert on non-repayment | `test/FlashLoan.t.sol` — `test_FlashLoanFail` |
