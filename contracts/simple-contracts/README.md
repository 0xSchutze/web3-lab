# Simple Contracts

Practice contracts using basic Solidity concepts.

> ⚠️ These contracts are for learning purposes only. They do not hold real ETH and are not written with production-level security. Built to practice core Solidity concepts — feel free to use them as a starting point.

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

## SimpleVoting

An NFT creation and voting system. Users can create NFTs, vote on them, and delete their own NFTs.

**Concepts Used:**
- [struct](../../Notes/solidity-basics/arrays-and-push.md) — `NFT` struct with `creator`, `voteCount`
- [nested mapping](../../Notes/solidity-basics/mapping.md) — `hasVoted[address][nftIndex]`
- [constructor and modifier](../../Notes/solidity-basics/constructor-and-modifer.md) — `onlyOwner` pattern
- [msg.sender vs tx.origin](../../Notes/solidity-basics/msg.sender-and-tx.origin.md) — safe auth checks
- [events and emit](../../Notes/solidity-basics/events-and-emit.md) — `NftCreated`, `Voted`, `NftDeleted`
- [require](../../Notes/solidity-basics/require.md) — ownership checks, vote validation
- swap & pop — array element deletion without gaps

