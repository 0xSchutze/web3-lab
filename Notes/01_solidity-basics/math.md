# Math in Solidity (No Floats)

Solidity does **not** support floating-point numbers (decimals like `0.5` or `99.7`). All mathematical operations must be done using integers.

## Basis Points (Bypassing Decimals)

To calculate percentages (like a 0.3% fee) without decimals, we multiply the numbers by large constants (like `1000` or `10000`). This concept is known in finance as "Basis Points" (bps).

```solidity
// To calculate 0.3% fee, we multiply by 997 and divide by 1000
uint256 amountWithFee = amount * 997;
uint256 finalResult = amountWithFee / 1000;
```

## OpenZeppelin Math Library

Solidity doesn't have built-in advanced math functions like square root or finding the minimum/maximum of two numbers. We use OpenZeppelin's `Math.sol` library.

```solidity
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Returns the smaller of the two numbers
uint256 minVal = Math.min(100, 50); // Returns 50

// Calculates the geometric mean (square root)
uint256 root = Math.sqrt(100); // Returns 10
```

## Constant Product Formula ($x \times y = k$)

The backbone of Automated Market Makers (AMM) like Uniswap. It mathematically guarantees that a pool can never be fully drained.

- $x$: Reserve of token A
- $y$: Reserve of token B
- $k$: The constant invariant

When a user swaps tokens (increasing $x$), $y$ must decrease in a way that $k$ remains constant. As the reserve of $y$ approaches zero, its price approaches infinity.
