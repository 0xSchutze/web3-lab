# Simple Contracts

Practice contracts using basic Solidity concepts.

## SimpleWallet

A basic wallet contract with account creation, deposit, and withdrawal.

**Concepts Used:**
- [struct](../../Notes/solidity-basics/arrays-and-push.md) — `Account` struct
- [mapping](../../Notes/solidity-basics/mapping.md) — `addressToId`, `accountCount`
- [arrays and push](../../Notes/solidity-basics/arrays-and-push.md) — `accounts[]`
- [msg.sender](../../Notes/solidity-basics/msg.sender.md) — caller identification
- [require](../../Notes/solidity-basics/require.md) — input validation, access control
- [events and emit](../../Notes/solidity-basics/events-and-emit.md) — `AccountCreated`, `Deposited`, `Withdrawn`
- [hashing and typecasting](../../Notes/solidity-basics/hashing-and-typecasting.md) — `keccak256` for ID generation
- [return, view, pure](../../Notes/solidity-basics/return.md) — `getBalance()` as view function
- [storage and memory](../../Notes/solidity-basics/storage-and-memory.md) — `string memory` parameters
