# Return, View and Pure

## return

Used to send data back from a function.

```solidity
function getScore() public view returns (uint) {
    return score;
}
```

## view

Reads data from the blockchain but does not modify it. No gas cost when called externally.

```solidity
function getBalance(address _addr) public view returns (uint) {
    return balances[_addr];
}
```

## pure

Does not read or modify any data on the blockchain. Used for calculations only.

```solidity
function calcTotal(uint _a, uint _b) public pure returns (uint) {
    return _a + _b;
}
```

## Syntax Order

```solidity
function name(params) visibility view/pure returns (type) {
    return value;
}
```

- `view` / `pure` comes **before** `returns`
- `returns (uint)` — specifies the return type in parentheses
- A function without `view` or `pure` can modify state (costs gas)
