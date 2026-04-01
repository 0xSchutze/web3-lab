// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./simpleERC721.sol";

/// @title SimpleNFT — basic NFT collection contract
/// @notice Covers: ERC721 interface, transferFrom, approve, mapping, modifier, events

contract SimpleNFT is IERC721 {
    // State variables
    struct Nft {
        string name;
        uint128 createdAt;
    }
    Nft[] public nfts;

    mapping(uint => address) public nftToOwner;
    mapping(uint => address) public nftToApproved;
    mapping(address => uint) public ownerToCount;

    // Only the owner of a specific NFT can call
    modifier onlyOwnerOf(uint _tokenId) {
        require(nftToOwner[_tokenId] == msg.sender, "Not the owner");
        _;
    }

    // Mint a new NFT — max 10 per address
    function mint(string calldata _name) external {
        require(ownerToCount[msg.sender] <= 10, "Max 10 NFTs per address");

        uint tokenId = nfts.length;
        nfts.push(Nft(_name, uint128(block.timestamp)));

        nftToOwner[tokenId] = msg.sender;
        ownerToCount[msg.sender]++;

        emit Transfer(address(0), msg.sender, tokenId);
    }

    // Transfer ownership — only owner or approved can call
    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external override {
        require(
            nftToOwner[_tokenId] == msg.sender ||
                nftToApproved[_tokenId] == msg.sender,
            "Not owner or approved"
        );
        require(ownerToCount[_from] >= 1, "Sender has no NFTs");

        nftToOwner[_tokenId] = _to;
        ownerToCount[_from]--;
        ownerToCount[_to]++;

        // Clear approval after transfer
        nftToApproved[_tokenId] = address(0);

        emit Transfer(_from, _to, _tokenId);
    }

    // Approve another address to transfer your NFT
    function approve(
        address _approved,
        uint256 _tokenId
    ) external override onlyOwnerOf(_tokenId) {
        nftToApproved[_tokenId] = _approved;
        emit Approval(msg.sender, _approved, _tokenId);
    }

    // View: who owns this token?
    function ownerOf(
        uint256 _tokenId
    ) external view override returns (address) {
        return nftToOwner[_tokenId];
    }

    // View: how many NFTs does this address own?
    function balanceOf(
        address _owner
    ) external view override returns (uint256) {
        return ownerToCount[_owner];
    }
}
