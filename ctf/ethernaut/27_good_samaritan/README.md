# Level 27: Good Samaritan

**Target:** [GoodSamaritan.sol](./GoodSamaritan.soll)
**Exploit:** [exploit.sol](./exploit.sol)

## Vulnerability

The GoodSamaritan contract uses a `try/catch` block to handle `NotEnoughBalance()` errors from the Wallet. When this error is caught, the contract assumes the wallet is nearly empty and transfers the entire remaining balance. An attacker can spoof this custom error from within the `INotifyable.notify()` callback to trick the contract into draining the full wallet.

## Key Concepts

**Custom Error Spoofing:** Solidity custom errors are identified solely by their 4-byte selector (e.g., `keccak256("NotEnoughBalance()")`). Any contract can define and revert with an identically-named error. The `catch` block cannot distinguish between the legitimate error from Wallet and a spoofed one from an external contract.

**Callback Exploitation (INotifyable):** The Coin contract calls `INotifyable(dest_).notify(amount)` on every transfer to a contract address. This callback gives the recipient control flow during the transfer, creating an opportunity to manipulate the caller's error-handling logic.

**try/catch Error Source Blindness:** Solidity's `try/catch` catches errors that bubble up through the entire call chain. It does not verify the origin contract of the error, only the error's selector. This is a fundamental design limitation that enables cross-contract error injection.

## Root Cause

The `GoodSamaritan.requestDonation()` function catches `NotEnoughBalance()` errors without verifying the error's origin. Any contract in the call chain (including the transfer recipient's `notify` callback) can revert with this error, causing `transferRemainder()` to execute and drain the wallet.

## Exploit

1. Deploy an attacker contract implementing `INotifyable.notify(uint256 amount)`.
2. Call `GoodSamaritan.requestDonation()`.
3. GoodSamaritan calls `wallet.donate10(attacker)`, which triggers `coin.transfer(attacker, 10)`.
4. Coin calls `attacker.notify(10)` — the attacker checks `amount <= 10` and reverts with `NotEnoughBalance()`.
5. The spoofed error bubbles up to GoodSamaritan's `catch` block, which calls `wallet.transferRemainder(attacker)`.
6. Wallet sends the entire balance (1,000,000 coins). Coin calls `attacker.notify(1000000)`.
7. This time `amount > 10`, so `notify()` returns silently. The attacker receives all funds.

| Step | Function | amount | notify() Action |
|------|----------|--------|-----------------|
| 1 | donate10 | 10 | revert NotEnoughBalance() |
| 2 | transferRemainder | 1,000,000 | accept silently |

```solidity
function notify(uint256 amount) external {
    if (amount <= 10) {
        revert NotEnoughBalance();  // Spoof — triggers transferRemainder
    }
    // Full balance arrives here — accept silently
}
```

## Real-World Reference

Custom error spoofing is a subset of the broader "error injection" attack class. While this exact pattern is less common in production audits, the underlying principle — trusting error selectors without verifying their origin — appears in protocols that use `try/catch` for fallback logic. The Coin callback mechanism mirrors the ERC-777 `tokensReceived` hook, which famously enabled reentrancy in the Uniswap V1 / imBTC incident (April 2020, ~$300K).
