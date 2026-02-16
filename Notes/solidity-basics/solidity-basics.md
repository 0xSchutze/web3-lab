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

## Practice Contracts

- [SimpleWallet](../../contracts/simple-contracts/SimpleWallet.sol) — account creation, deposit, withdraw (uses struct, mapping, require, events, keccak256)