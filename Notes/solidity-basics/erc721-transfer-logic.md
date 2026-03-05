# ERC721 Transfer Logic

## Key Difference

ERC721 transfer does **NOT move ETH** — it only changes the **ownership record** in a mapping. ETH payment (when buying/selling NFTs) happens in a separate marketplace contract (like OpenSea), not in the NFT contract itself.

## transferFrom

Transfers ownership of an ERC721 token to a target address. Only the **owner** or an **approved address** can call this.

```solidity
function transferFrom(address _from, address _to, uint256 _tokenId) external payable;
```

What happens internally:

```solidity
function _transfer(address _from, address _to, uint256 _tokenId) private {
    ownerZombieCount[_to]++;        // new owner count +1
    ownerZombieCount[_from]--;      // old owner count -1
    zombieToOwner[_tokenId] = _to;  // change ownership in mapping
    emit Transfer(_from, _to, _tokenId);
}
```

## approve

Gives another address permission to transfer **one specific token** on your behalf. One-time only — after transfer, the approval is used up.

```solidity
function approve(address _approved, uint256 _tokenId) external payable;
```

**Use case:** When you list an NFT on OpenSea, you `approve` the OpenSea contract. When someone buys it, OpenSea calls `transferFrom` for you.

## Two Ways to Transfer

| Method | How |
|--------|-----|
| Direct | Owner calls `transferFrom` directly |
| Via approve | Owner calls `approve` → approved address calls `transferFrom` |

Both end up running the same `_transfer` logic internally.
