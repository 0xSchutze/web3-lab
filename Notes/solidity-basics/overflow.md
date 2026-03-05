# Overflow and Underflow

## What Is Overflow?

Every `uint` has a maximum value based on its size. When you exceed that limit, it wraps around to 0.

```solidity
uint8 number = 255;   // max value for uint8
number++;             // expected: 256, actual: 0 (overflow!)
```

| Type | Bits | Max Value |
|------|------|-----------|
| `uint8` | 8 | 255 |
| `uint16` | 16 | 65,535 |
| `uint32` | 32 | 4,294,967,295 |
| `uint256` | 256 | 2^256 - 1 (astronomically large) |

## What Is Underflow?

The opposite — subtracting below 0 wraps to the max value.

```solidity
uint8 number = 0;
number--;             // expected: -1, actual: 255 (underflow!)
```

## Solidity 0.8+ — Automatic Protection

In Solidity 0.8 and above, overflow and underflow **automatically revert** the transaction. No extra code needed.

```solidity
// 0.8+ — safe by default
uint8 x = 255;
x++;    // REVERT (not 0)

uint8 y = 0;
y--;    // REVERT (not 255)
```

## unchecked — Disabling Protection

Some developers use `unchecked` blocks to save gas, which **removes the protection:**

```solidity
unchecked {
    uint8 x = 255;
    x++;    // = 0 (old behavior, dangerous!)
}
```

> [!WARNING]
> When auditing contracts, always search for `unchecked` blocks — these are potential overflow/underflow vulnerabilities.

## SafeMath — Old Solidity Solution (pre-0.8)

Before 0.8, OpenZeppelin's SafeMath library was used to add overflow checks manually:

```solidity
using SafeMath for uint256;

// Instead of:  count++
count = count.add(1);    // reverts on overflow

// Instead of:  count--
count = count.sub(1);    // reverts on underflow
```

SafeMath is no longer needed in 0.8+, but old contracts still use it.

## Security Note

- Solidity 0.8+ = safe by default ✅
- `unchecked` blocks = check during audits ⚠️
- Pre-0.8 contracts without SafeMath = vulnerable 🔴