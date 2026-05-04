# Level 38: UniqueNFT

**Target:** [UniqueNFT.sol](./UniqueNFT.sol)
**Exploit:** [exploit.sol](./exploit.sol)

## Vulnerability
The `UniqueNFT` contract suffers from a Check-Effects-Interactions (CEI) violation in its internal `_mintNFT` function and lacks reentrancy protection on the `mintNFTEOA` function. Additionally, it uses a flawed `tx.origin == msg.sender` check to verify if the caller is an Externally Owned Account (EOA), which can be bypassed using EIP-7702 (Pectra upgrade) account delegation.

## Key Concepts
- **EIP-7702 Delegation:** Allows an EOA to temporarily delegate its code to a smart contract for the duration of a transaction. This enables an EOA to have smart contract capabilities (like receiver hooks) while maintaining `tx.origin == msg.sender`.
- **Check-Effects-Interactions (CEI) Violation:** Calling an external contract (or a hook like `onERC721Received`) before updating the internal state (like user balances).
- **ERC721 Receiver Hook (`onERC721Received`):** A standard callback executed by the ERC721 contract to ensure the receiving address can handle NFTs. This callback transfers execution flow to the receiver.
- **Missing Reentrancy Guard:** Omitting the `nonReentrant` modifier on functions that perform external calls, leaving them vulnerable to recursive execution.

## Root Cause
The root cause is twofold:
1. The developer relied on `tx.origin == msg.sender` to prevent smart contracts from interacting with `mintNFTEOA()`. With EIP-7702, this assumption is broken.
2. Inside `_mintNFT()`, the `ERC721Utils.checkOnERC721Received` hook is called *before* the `_mint` function updates the state. This means the `balanceOf(msg.sender) == 0` check will pass multiple times if the hook reenters the minting function.

## Exploit
1. **Prepare Exploit Logic:** Create an `Exploit` contract containing an `onERC721Received` hook.
2. **Reentrancy Loop:** Inside the hook, check a state counter (`mintCount`). If it's less than 1, call the target's `mintNFTEOA()` again. This causes a reentrant call.
3. **Storage Considerations:** Ensure any state variables accessed by the delegated EOA (like the `target` address) are marked `constant` so they are hardcoded into the bytecode, bypassing the empty storage slots of the EOA.
4. **EIP-7702 Delegation:** Deploy the `Exploit` contract. Use `cast send --auth <EXPLOIT_ADDRESS>` to temporarily delegate the player's EOA to the `Exploit` logic while simultaneously calling `mintNFTEOA()`.
5. **Execution Flow:**
   - EOA (acting as Exploit) calls `mintNFTEOA()`.
   - Target checks `tx.origin == msg.sender` (Passes, because it is an EOA).
   - Target calls `_mintNFT()`, checks `balanceOf == 0` (Passes).
   - Target triggers `checkOnERC721Received` on the EOA.
   - EOA's delegated logic (`onERC721Received`) executes and calls `mintNFTEOA()` again.
   - Target checks `balanceOf == 0` (Passes, because state hasn't updated yet).
   - Target mints the second NFT.
   - The execution unwinds, and the player ends up with 2 NFTs, passing the validation.

## Real-World Reference
CEI violations leading to reentrancy during ERC721/ERC1155 hooks are common. A notable example is the **Revest Finance Hack (2022)**, where an attacker exploited a missing reentrancy guard and a CEI violation during the ERC1155 `onERC1155Received` hook to mint excess shares and drain the protocol of ~$2M. Similarly, the **Hashmasks** project faced issues where users could bypass mint limits due to reentrancy in the minting logic before state updates.