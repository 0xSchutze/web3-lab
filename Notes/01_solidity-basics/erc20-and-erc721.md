# ERC20 and ERC721 Token Standards

## Why Standards Matter

A token standard defines a common set of functions that all tokens must implement. Any dApp, exchange, or wallet that supports the standard can work with **any** token that follows it — no custom code needed.

## ERC20 — Fungible Token (Currency)

Used for tokens that act like money — every unit is identical and divisible.

```solidity
// Core ERC20 functions
function transfer(address _to, uint256 _amount) external returns (bool);
function balanceOf(address _owner) external view returns (uint256);
function transferFrom(address _from, address _to, uint256 _amount) external returns (bool);
function approve(address _spender, uint256 _amount) external returns (bool);
```

- ✅ Divisible — you can send 0.237 tokens
- ✅ Fungible — my 1 USDT = your 1 USDT (identical)
- Examples: USDT, LINK, UNI

## ERC721 — Non-Fungible Token (NFT / Collectible)

Used for unique items where each token is different.

```solidity
// Core ERC721 functions
function transferFrom(address _from, address _to, uint256 _tokenId) external payable;
function balanceOf(address _owner) external view returns (uint256);
function ownerOf(uint256 _tokenId) external view returns (address);
function approve(address _approved, uint256 _tokenId) external payable;
```

- ❌ Not divisible — you can't send 0.5 of an NFT
- ❌ Not fungible — each token has a unique ID and different properties
- Examples: CryptoKitties, CryptoZombies, Bored Apes

## Key Differences

| | ERC20 | ERC721 |
|--|-------|--------|
| Each token identical? | ✅ Yes | ❌ No, each is unique |
| Divisible? | ✅ Yes (0.001 etc.) | ❌ No, whole units only |
| Has unique ID? | ❌ No | ✅ Yes (`tokenId`) |
| Use case | Currency, governance | Art, collectibles, game items |