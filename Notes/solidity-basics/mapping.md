# Mapping

## What It Is

A key-value data structure that maps one type to another. Similar to a dictionary or hash table.

## Syntax

```solidity
mapping(keyType => valueType) visibility name;
```

## Examples

Map a wallet address to a balance:

```solidity
mapping(address => uint) public balances;
```

Map an ID to an owner address:

```solidity
mapping(uint => address) public itemToOwner;
```

Map an address to a boolean (track if something was done):

```solidity
mapping(address => bool) public hasVoted;
```

## Reading and Writing

```solidity
// write
balances[msg.sender] = 100;

// read
uint myBalance = balances[msg.sender];

// increment
balances[msg.sender] += 50;
```

## Notes

- Default value is always `0` (for uint), `false` (for bool), `address(0)` (for address)
- Cannot be iterated (no for loop over all keys)
- Cannot get the length or list of all keys
- Commonly used with `msg.sender` for ownership and access control

## Nested Mapping

A mapping inside a mapping — useful when tracking two dimensions:

```solidity
// Track who voted for which NFT
mapping(address => mapping(uint => bool)) public hasVoted;

// Usage:
hasVoted[msg.sender][nftIndex] = true;   // Alice voted for NFT #3
hasVoted[msg.sender][nftIndex];          // did Alice vote for NFT #3?
```

Use when one key isn't enough — like tracking votes per user per item.

