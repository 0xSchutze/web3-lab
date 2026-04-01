# Ternary Operator

The ternary operator is a concise, one-line way to write simple `if/else` statements. It is highly preferred by Auditors and Senior Developers because it makes code cleaner, reduces lines, and can occasionally save Gas.

## Syntax

```solidity
condition ? valueIfTrue : valueIfFalse;
```
- `?` represents "If the condition is true".
- `:` represents "Else (If the condition is false)".

## Example (Junior vs Senior)

### Junior Approach (if/else)
```solidity
IERC20 tokenOut;

if (isTokenA == true) {
    tokenOut = tokenB;
} else {
    tokenOut = tokenA;
}
```

### Senior Approach (Ternary)
```solidity
// Done in one single line
IERC20 tokenOut = isTokenA ? tokenB : tokenA;
```

## Abstracting Variables (Alias Pattern)
In complex algorithms like DEX Swaps, we use ternary operators to assign "Input" and "Output" roles to variables, rather than hardcoding specific token names. This allows us to write strict mathematical formulas without repeating them inside `if/else` blocks.

```solidity
uint256 reserveIn = isTokenA ? reserveA : reserveB;
```
