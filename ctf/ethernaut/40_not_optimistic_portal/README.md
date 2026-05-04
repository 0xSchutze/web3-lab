# Level 40: NotOptimisticPortal

**Target:** [NotOptimisticPortal.sol](./NotOptimisticPortal.sol)
**Exploit:** [exploit.sol](./exploit.sol)
**Script:** [exploitScript.s.sol](./exploitScript.s.sol)
**MPT Generator:** [generate.js](./generate.js)

## Vulnerability
The final Ethernaut challenge combines a **Function Selector Hash Collision** with a flawed execution flow that validates Merkle Patricia Trie (MPT) inclusion proofs *after* allowing untrusted arbitrary code execution. An attacker can hijack the contract's ownership during message execution, elevate their own contract to the Sequencer role, submit a malicious L2 state root, and pass the final MPT inclusion check to mint tokens.

## Key Concepts
- **Function Selector Hash Collision:** The EVM identifies functions using the first 4 bytes of their `keccak256` signature. By appending specific numbers (like `_____610165642`) to a function name, an attacker/developer can forcefully brute-force a collision where a sensitive function shares the exact same 4-byte selector as an expected safe function.
- **Cross-Domain Messaging (L1 <-> L2):** In Optimistic Rollups, proving that an event occurred on L2 requires submitting a Merkle Patricia Trie proof of the account and storage state to the L1 contract.
- **Delayed Validation Pattern:** Allowing arbitrary execution (`call`) before verifying the cryptographic validity of the entire payload.

## Root Cause
The `executeMessage` function executes an array of calls (`_executeOperation`) before reaching the `_verifyMessageInclusion` check. The `_executeOperation` function ensures that if the action is not a governance action, the calldata must start with the `0x3a69197e` selector (which corresponds to `onMessageReceived(bytes)`). 

However, the owner function `transferOwnership_____610165642(address)` was deliberately crafted to have the exact same `0x3a69197e` selector. Because the loop allows the `msg.sender` of the internal call to be `address(this)`, an attacker can instruct the Portal to call itself, bypassing the `onlyOwner` modifier, taking control of the contract, and manipulating the L2 state roots *before* the inclusion proof is ever evaluated.

## Exploit
1. **The Hash Collision:** The selector for `transferOwnership_____610165642(address)` is `0x3a69197e`, matching the required `onMessageReceived` entrypoint.
2. **The MPT Generator (`generate.js`):** Off-chain, the attacker creates a minimal, valid Merkle Patricia Trie containing the `L2_TARGET` account and the specific `messageSlot` mapped to `0x01`. This generates valid `stateTrieProof`, `storageTrieProof`, and a fabricated `stateRoot`.
3. **The Bounce Contract (`exploit.sol`):** A custom contract is deployed with a fallback function that intercepts calls matching `0x3a69197e` and issues commands back to the Portal.
4. **The Execution Chain (`exploitScript.s.sol`):**
   - The script builds a dynamic RLP Block Header containing the fabricated `stateRoot`.
   - `executeMessage` is called with three nested messages:
     1. Target: Portal. Payload: `transferOwnership(ExploitContract)`. (The portal calls itself, makes Exploit contract the Owner).
     2. Target: Exploit. Payload: `Command 1`. (Exploit calls `updateSequencer` to make itself the Sequencer).
     3. Target: Exploit. Payload: `Command 2`. (Exploit calls `submitNewBlock` injecting the fabricated `stateRoot`).
5. **The Climax:** The execution flow exits the loop and hits `_verifyMessageInclusion`. Because the `stateRoot` in the contract now perfectly matches the fabricated MPT proofs provided in the calldata, the verification passes. The contract proceeds to `_mint` 1 ether to the attacker, satisfying the win condition (`totalSupply > 0`).

## Real-World Reference
While intentional hash collisions are rare outside of CTFs, EVM Function Selector Collisions are a known vector. A famous example is the **PolyNetwork Hack ($611M)**, where the attacker exploited a hash collision between a legitimate cross-chain method and an internal keeper mechanism to overwrite public keys and hijack the protocol's asset pool. Additionally, the pattern of executing untrusted code *before* final verification is a classic structural flaw seen in many bridge architectures.