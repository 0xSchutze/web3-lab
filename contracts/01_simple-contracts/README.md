# Simple Contracts

Practice contracts using basic Solidity concepts.

> ⚠️ These contracts are for learning purposes only. They do not hold real ETH and are not written with production-level security. Built to practice core Solidity concepts — feel free to use them as a starting point.

## SimpleWallet

A basic wallet contract with account creation, deposit, and withdrawal.

**Concepts Used:**
- [struct](../../Notes/01_solidity-basics/arrays-and-push.md) — `Account` struct
- [mapping](../../Notes/01_solidity-basics/mapping.md) — `addressToId`, `accountCount`
- [arrays and push](../../Notes/01_solidity-basics/arrays-and-push.md) — `accounts[]`
- [msg.sender](../../Notes/01_solidity-basics/msg.md) — caller identification
- [require](../../Notes/01_solidity-basics/require.md) — input validation, access control
- [events and emit](../../Notes/01_solidity-basics/events-and-emit.md) — `AccountCreated`, `Deposited`, `Withdrawn`
- [hashing and typecasting](../../Notes/01_solidity-basics/hashing-and-typecasting.md) — `keccak256` for ID generation
- [return, view, pure](../../Notes/01_solidity-basics/return.md) — `getBalance()` as view function
- [storage and memory](../../Notes/01_solidity-basics/storage-and-memory.md) — `string memory` parameters

## simpleOwnable

Basic ownership pattern — sets deployer as owner, restricts functions with `onlyOwner` modifier.

**Concepts Used:**
- [constructor](../../Notes/01_solidity-basics/constructor-and-modifer.md) — sets owner at deploy
- [modifier](../../Notes/01_solidity-basics/constructor-and-modifer.md) — `onlyOwner` guard
- [events and emit](../../Notes/01_solidity-basics/events-and-emit.md) — `OwnershipTransferred`
- [msg.sender](../../Notes/01_solidity-basics/msg.md) — deployer identification

## SimpleVoting

An NFT creation and voting system. Users can create NFTs, vote on them, and delete their own NFTs.

**Concepts Used:**
- [struct](../../Notes/01_solidity-basics/arrays-and-push.md) — `NFT` struct with `creator`, `voteCount`
- [nested mapping](../../Notes/01_solidity-basics/mapping.md) — `hasVoted[address][nftIndex]`
- [constructor and modifier](../../Notes/01_solidity-basics/constructor-and-modifer.md) — `onlyOwner` pattern
- [msg.sender vs tx.origin](../../Notes/01_solidity-basics/msg.sender-and-tx.origin.md) — safe auth checks
- [events and emit](../../Notes/01_solidity-basics/events-and-emit.md) — `NftCreated`, `Voted`, `NftDeleted`
- [require](../../Notes/01_solidity-basics/require.md) — ownership checks, vote validation
- swap & pop — array element deletion without gaps

## SimpleTodo

A personal task manager. Users can create, complete, rename, and delete their own tasks.

**Concepts Used:**
- [struct](../../Notes/01_solidity-basics/arrays-and-push.md) — `Task` struct with `owner` field
- [modifier with params](../../Notes/01_solidity-basics/constructor-and-modifer.md) — `onlyTaskOwner(_taskId)` custom guard
- [function visibility](../../Notes/01_solidity-basics/function-visibility.md) — `external` for cheaper gas
- [for loop](../../Notes/01_solidity-basics/for-loop.md) — scan all tasks to find user's tasks
- [mapping](../../Notes/01_solidity-basics/mapping.md) — `taskCount` per address
- [delete](../../Notes/01_solidity-basics/arrays-and-push.md) — reset task data without swap & pop
- [view functions](../../Notes/01_solidity-basics/return.md) — gas-free task queries
- [calldata](../../Notes/01_solidity-basics/storage-and-memory.md) — cheap external string parameters

## SimplePiggyBank

A shared piggy bank. Anyone can deposit ETH, only the owner can withdraw all funds.

**Concepts Used:**
- [payable](../../Notes/01_solidity-basics/payable.md) — `deposit()` receives ETH
- [msg.value](../../Notes/01_solidity-basics/msg.md) — check how much ETH was sent
- [withdraw pattern](../../Notes/01_solidity-basics/payable.md) — `payable(_owner).transfer()`
- [address(this).balance](../../Notes/01_solidity-basics/payable.md) — total ETH in contract
- [mapping](../../Notes/01_solidity-basics/mapping.md) — `deposits` tracks each address
- [modifier](../../Notes/01_solidity-basics/constructor-and-modifer.md) — `onlyOwner` guard
- [events and emit](../../Notes/01_solidity-basics/events-and-emit.md) — `Deposited`, `Withdrawn`
- [require](../../Notes/01_solidity-basics/require.md) — minimum deposit check

## SimpleNFT

A basic NFT collection. Mint unique tokens, transfer ownership, and approve other addresses.

**Concepts Used:**
- [ERC721 Transfer Logic](../../Notes/01_solidity-basics/erc721-transfer-logic.md) — `transferFrom`, `_transfer`, ownership mapping
- [ERC20 and ERC721](../../Notes/01_solidity-basics/erc20-and-erc721.md) — token standards, interface implementation
- [interface](../../Notes/01_solidity-basics/interface.md) — `IERC721` interface inheritance
- [mapping](../../Notes/01_solidity-basics/mapping.md) — `nftToOwner`, `nftToApproved`, `ownerToCount`
- [modifier](../../Notes/01_solidity-basics/constructor-and-modifer.md) — `onlyOwnerOf` with parameter
- [events and emit](../../Notes/01_solidity-basics/events-and-emit.md) — `Transfer`, `Approval`
- [require](../../Notes/01_solidity-basics/require.md) — owner/approved check with `||`

## SimpleDex

A single-pair Automated Market Maker (AMM) implementing the Constant Product Formula ($x * y = k$). Users can add liquidity and swap tokens with slippage and a 0.3% fee built into the smart contract execution.

**Concepts Used:**
- [Constant Product AMM Math](../../Notes/01_solidity-basics/math.md) — $x * y = k$ and `Math.sqrt` / `Math.min`
- [Fee-on-Transfer Protection](../../Notes/01_solidity-basics/erc20-and-erc721.md) — actual balance checks via `balanceOf(address(this))`
- [Ternary Operator](../../Notes/01_solidity-basics/ternary.md) — gas optimization (`condition ? true : false`)
- [Implicit Returns](../../Notes/01_solidity-basics/return.md) — named returns saving gas
- [ERC20 Interface](../../Notes/01_solidity-basics/interface.md) — cross-contract logic and `transferFrom`
