# Level 34: Bet House

**Target:** [BetHouse.sol](./BetHouse.sol)
**Exploit:** [exploit.sol](./exploit.sol)
**Script:** [exploitScript.s.sol](./exploitScript.s.sol)

## Vulnerability
The `Pool` contract contains a critical execution order flaw in its `withdrawAll()` function. The function sends Ether to the user via a low-level `.call` *before* burning the user's Wrapped Pool Tokens (WPT). Since the external call hands over execution control to the recipient's `fallback/receive` function, an attacker can transfer their WPT out of the contract before the `burn` logic is reached.

## Key Concepts
- **Execution Order (Check-Effects-Interactions):** The EVM executes state changes synchronously. If external calls are made before state updates (like burning tokens), the execution flow can be hijacked.
- **Rescue-Before-Burn:** A form of state desync where an attacker prevents the destruction of assets by moving them out of scope during a paused execution state (reentrancy vector).
- **Global State Collision:** Using a single boolean (`alreadyDeposited`) instead of a mapping restricts operations globally, creating strict but bypassable logic constraints.

## Root Cause
In `withdrawAll()`, the code is structured as follows:
1. Transfer PDT to user.
2. Transfer Ether to user (`msg.sender.call{value: _depositedValue}("")`).
3. Burn WPT from user (`burn(msg.sender, balanceOf(msg.sender))`).

When step 2 occurs, if the receiver is a smart contract, its `receive()` function is triggered. At this exact moment, the attacker still holds their WPT balance. By transferring the WPT to another address inside the `receive()` function, the attacker empties their balance. When execution resumes at step 3, `balanceOf(msg.sender)` returns `0`, causing the contract to burn nothing.

## Exploit
The goal is to accumulate 20 WPT to call `makeBet()` and become a bettor, starting with only 5 PDT:

1. **Deposit:** The Exploit contract deposits 0.001 Ether and 5 PDT into the pool, receiving 15 WPT.
2. **Withdraw & Hijack:** The Exploit contract calls `withdrawAll()`. The pool returns the 5 PDT and then sends the 0.001 Ether.
3. **Rescue:** The Ether transfer triggers the Exploit's `receive()` function. Inside, the Exploit transfers its 15 WPT to the player's EOA before the `burn` line executes.
4. **Second Deposit:** The Exploit contract deposits the refunded 5 PDT again, receiving 5 new WPT.
5. **Consolidate:** The player transfers the rescued 15 WPT back to the Exploit contract, giving it a total of 20 WPT.
6. **Win:** The Exploit locks its deposits and calls `makeBet(player_address)`, successfully bypassing the balance check and winning the level.

## Real-World Reference
This is a textbook violation of the **Check-Effects-Interactions** pattern. While classic Reentrancy aims to drain funds by re-entering the *same* function, this is a **Cross-Function State Desync** where the attacker doesn't re-enter the pool, but simply moves assets before the accounting is finalized. Similar bugs have occurred in older DeFi protocols that attempted to burn LP tokens or collateral *after* returning the underlying assets to the user.
