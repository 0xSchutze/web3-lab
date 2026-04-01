// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title SimpleVoting — NFT creation and voting system
/// @notice Covers: struct, nested mapping, events, modifiers, array management

contract SimpleVoting {
    // --- Owner setup (simple Ownable pattern) ---
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // --- Events ---
    event NftCreated(uint nftIndex, string name, address creator);
    event NftDeleted(uint nftIndex, address deletedBy);
    event Voted(address voter, uint nftIndex);
    event VoteRemoved(address voter, uint nftIndex);

    // --- Data structures ---
    struct NFT {
        string name;
        string description;
        uint32 value;
        address creator;
        uint voteCount;
    }

    // All NFTs stored in one array
    NFT[] public nfts;

    // Track how many NFTs each address created
    mapping(address => uint) public nftCount;

    // Track who voted for which NFT: address → nftIndex → voted?
    mapping(address => mapping(uint => bool)) public hasVoted;

    // --- NFT functions ---

    // Anyone can create an NFT
    function createNft(
        string memory _name,
        string memory _description,
        uint32 _value
    ) public {
        nfts.push(NFT(_name, _description, _value, msg.sender, 0));
        nftCount[msg.sender]++;
        emit NftCreated(nfts.length - 1, _name, msg.sender);
    }

    // Only the creator can delete their own NFT (swap & pop)
    function deleteNft(uint _index) public {
        require(_index < nfts.length, "NFT does not exist");
        require(nfts[_index].creator == msg.sender, "Not your NFT");

        // Swap with last element and remove
        nfts[_index] = nfts[nfts.length - 1];
        nfts.pop();
        nftCount[msg.sender]--;

        emit NftDeleted(_index, msg.sender);
    }

    // --- Voting functions ---

    // Vote for an NFT — one vote per user per NFT
    function vote(uint _nftIndex) public {
        require(_nftIndex < nfts.length, "NFT does not exist");
        require(!hasVoted[msg.sender][_nftIndex], "Already voted");

        hasVoted[msg.sender][_nftIndex] = true;
        nfts[_nftIndex].voteCount++;

        emit Voted(msg.sender, _nftIndex);
    }

    // Remove your vote from an NFT
    function removeVote(uint _nftIndex) public {
        require(_nftIndex < nfts.length, "NFT does not exist");
        require(hasVoted[msg.sender][_nftIndex], "Not voted yet");

        hasVoted[msg.sender][_nftIndex] = false;
        nfts[_nftIndex].voteCount--;

        emit VoteRemoved(msg.sender, _nftIndex);
    }

    // --- View functions ---

    // Get total number of NFTs
    function getNftCount() public view returns (uint) {
        return nfts.length;
    }

    // Get vote count for a specific NFT
    function getVoteCount(uint _nftIndex) public view returns (uint) {
        require(_nftIndex < nfts.length, "NFT does not exist");
        return nfts[_nftIndex].voteCount;
    }

    // Check if you voted for a specific NFT
    function checkMyVote(uint _nftIndex) public view returns (bool) {
        return hasVoted[msg.sender][_nftIndex];
    }
}
