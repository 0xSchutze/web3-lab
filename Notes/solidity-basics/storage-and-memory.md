# Storage and Memory

## storage

Refers directly to the blockchain data. Changes are **permanent** and cost gas.

```solidity
Player storage player = players[_playerId];
player.score += 10;  // modifies the original score permanently on-chain
```

## memory

Creates a temporary **copy** of the data. Changes are lost when the function ends.

```solidity
Player memory player = players[_playerId];
player.score += 10;  // only modifies the copy, original stays the same
```

## When to Use

| Keyword | Use When | Gas Cost |
|---------|----------|----------|
| `storage` | You want to modify the original data | Higher (writes to blockchain) |
| `memory` | You only need to read or do temporary calculations | Lower (temporary) |

## Required Usage

- `string`, `bytes`, `array`, `struct` parameters in functions **must** specify `memory` or `storage`
- Function parameters are typically `memory`
- State variables are always `storage` by default

```solidity
function getName(string memory _input) public pure returns (string memory) {
    return _input;
}
```