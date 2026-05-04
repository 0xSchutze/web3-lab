# Level 39: Forger

**Target:** [Forger.sol](https://github.com/OpenZeppelin/ethernaut/blob/master/contracts/src/levels/Forger.sol)
**Exploit Script:** [exploitScript.s.sol](./exploitScript.s.sol)

## Vulnerability
The `Forger` contract attempts to prevent signature reuse by storing the hash of the used signature (`keccak256(signature)`). However, it uses OpenZeppelin's `ECDSA.recover` which supports multiple signature formats. An attacker can mathematically manipulate the original 65-byte signature into a valid 64-byte "compact" signature (EIP-2098). Since the byte arrays differ in length and content, their hashes are different, allowing the same logical signature to be used twice to bypass the `signatureUsed` check.

## Key Concepts
- **Signature Malleability:** The ability to alter a cryptographic signature without access to the private key, such that the new signature remains valid for the original message.
- **EIP-2098 Compact Signatures:** A standard that allows 65-byte ECDSA signatures `(r, s, v)` to be represented in 64 bytes `(r, vs)`. This is done by embedding the `v` parity bit into the highest bit of the `s` value.
- **Flawed Replay Protection:** Using the hash of the *signature itself* instead of the hash of the *message* or a dedicated `nonce` mechanism to prevent replay attacks.

## Root Cause
The root cause is a misunderstanding of what should be marked as "used". The contract marks the specific byte array of the signature as used (`signatureUsed[keccak256(signature)] = true`). Because `ECDSA.recover` will successfully validate both the standard 65-byte format and the compact 64-byte format of the *same* signature, an attacker can simply submit the alternative format. The hashes of the two byte arrays will differ, completely bypassing the replay protection mechanism.

## Exploit
1. **Analyze Original Signature:** Extract the provided 65-byte signature from the contract comments. Identify the `v` value (`0x1c` or 28) and the starting byte of the `s` value (`0x40`).
2. **Craft Compact Signature:** 
   - Apply EIP-2098 rules: Since `v == 28`, flip the highest bit of the `s` value. `0x40` (binary `0100 0000`) becomes `0xc0` (binary `1100 0000`).
   - Truncate the final byte (`v`) to reduce the signature length to 64 bytes.
3. **Execution Flow:**
   - Call `createNewTokensFromOwnerSignature` with the original 65-byte signature. Mints 100 tokens.
   - Call `createNewTokensFromOwnerSignature` with the newly crafted 64-byte compact signature.
   - The contract calculates a different `keccak256(signature)`, passes the `signatureUsed` check, and `ECDSA.recover` correctly authenticates the owner.
   - Mints another 100 tokens, achieving a total of 200 tokens (Win condition: `> 100`).

## Real-World Reference
Signature malleability was a significant issue in early Ethereum protocols (pre-EIP-2) where attackers could intercept transactions and replay them with manipulated signatures to drain funds or cause Denial of Service. The specific flaw of hashing the signature instead of the message for replay protection is a common anti-pattern in poorly audited airdrop or whitelist contracts.