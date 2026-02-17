# Solidity Basics

## Contract Structure

Every Solidity file starts with a version declaration and a contract body:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MyContract {
    // all code goes inside this body
}
```

- `pragma solidity ^0.8.0` — specifies the compiler version
- `contract` — the main building block, similar to a class in other languages

## Data Types

```solidity
uint age = 25;              // unsigned integer (positive numbers only)
string name = "Alice";      // text
bool isActive = true;       // true or false
address owner = msg.sender; // wallet address (20 bytes)
```

## Struct — Custom Data Type

Groups multiple variables into one type:

```solidity
struct Player {
    string name;
    uint score;
}
```

### Struct Packing (Gas Optimization)

Smaller uint types (`uint32`, `uint16`) save gas **only inside structs** — group them together:

```solidity
// ✅ Good — packed, saves gas
struct Efficient {
    uint32 a;
    uint32 b;
    uint c;
}

// ❌ Bad — not packed, wastes gas
struct Wasteful {
    uint32 a;
    uint c;
    uint32 b;
}
```

Outside structs, `uint32` costs the **same gas** as `uint256` — so use `uint` normally.


## Topics

- [Arrays and Push](./arrays-and-push.md)
- [Hashing and Typecasting](./hashing-and-typecasting.md)
- [Return, View and Pure](./return.md)
- [Storage and Memory](./storage-and-memory.md)
- [msg.sender](./msg.sender.md)
- [Mapping](./mapping.md)
- [Require](./require.md)
- [Events and Emit](./events-and-emit.md)
- [Inheritance](./inheritance.md)
- [Interface](./interface.md)
- [Constructor and Modifier](./constructor-and-modifer.md)
- [msg.sender vs tx.origin](./msg.sender-and-tx.origin.md)
- [Time Units](./time-units.md)

## Practice Contracts

- [SimpleWallet](../../contracts/simple-contracts/SimpleWallet.sol) — account creation, deposit, withdraw (uses struct, mapping, require, events, keccak256)
- [SimpleVoting](../../contracts/simple-contracts/SimpleVoting.sol) — NFT creation, voting, deletion (uses nested mapping, modifier, swap & pop)