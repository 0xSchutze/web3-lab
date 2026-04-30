# Level 35: EllipticToken

**Target:** [EllipticToken.sol](./EllipticToken.sol)
**Exploit:** [exploitScript.s.sol](./exploitScript.s.sol)
**Signature Forge:** [forge_signature.py](./forge_signature.py)

## Vulnerability

`EllipticToken.permit()` passes the raw `uint256 amount` directly to `ECDSA.recover()` as a `bytes32` without hashing it first. This violates the ECDSA standard and enables **Existential Forgery**: an attacker can construct a mathematically valid `(amount, signature)` pair that resolves to any target address without knowledge of the target's private key.

## Key Concepts

**ECDSA Existential Forgery (Missing Hash Step)**

The standard ECDSA verification flow requires the message to be hashed before signing:

```
signer = ecrecover(keccak256(message), v, r, s)   // correct
signer = ecrecover(bytes32(message), v, r, s)      // vulnerable — EllipticToken.permit()
```

When the hash step is skipped, the attacker controls the "hash" input directly. This breaks a fundamental ECDSA security assumption: the signer cannot be held responsible for a message they did not hash.

**Public Key Recovery from Hardcoded Factory Source**

Alice's address (`0xA11CE84AcB91Ac59B0A4E2945C9157eF3Ab17D4e`) is provided directly in the level description. Her `redeemVoucher` signatures are **hardcoded** in `EllipticTokenFactory.sol`, which is publicly available on the Ethernaut GitHub repository. They do not appear in Etherscan calldata because `redeemVoucher` is called as an internal transaction from within `createNewLevelInstance` — only the outer call is visible on-chain.

In a real-world scenario, if a contract's `redeemVoucher` were called in a normal top-level transaction, both the target address and the signatures would be permanently visible in the transaction's input data. The attack surface would be identical: once a signature is used on-chain, the signer's ECDSA public key point `Q` can be recovered by anyone using standard elliptic curve arithmetic.

**Existential Forgery via Free Signature Construction**

Given a public key point `Q` on secp256k1, an attacker can produce a valid `(h, r, s)` tuple for any desired signer address using:

```
R   = u1·G + u2·Q        (choose arbitrary u1, u2)
r   = R.x mod n
s   = r · u2⁻¹ mod n
h   = u1 · r · u2⁻¹ mod n   (this becomes the "amount" passed to the contract)
```

`ECDSA.recover(bytes32(h), sig(r, s, v))` will return Alice's address, granting the caller unlimited allowance.

## Root Cause

`permit()` line 49 casts the caller-supplied `amount` directly to `bytes32` and hands it to `ECDSA.recover()`:

```solidity
// EllipticToken.sol — line 49
address tokenOwner = ECDSA.recover(bytes32(amount), tokenOwnerSignature);
```

The correct implementation would require `amount` to be committed inside a domain-separated hash before being used as the ECDSA message digest, preventing any attacker-controlled relationship between the input and the recovered address.

## Exploit

**Attack flow:**

1. Obtain Alice's `redeemVoucher` signature from `EllipticTokenFactory.sol` (hardcoded, publicly available on the Ethernaut GitHub repository). Recover Alice's public key point `Q` from this signature using standard ECDSA public key recovery.
2. Run `forge_signature.py` to produce `(forgedAmount, forgedSig)` via Existential Forgery such that `ECDSA.recover(bytes32(forgedAmount), forgedSig) == ALICE`.
3. Call `permit(forgedAmount, player, forgedSig, spenderSig)` — the contract grants `player` an allowance of `forgedAmount` from Alice's account.
4. Call `transferFrom(ALICE, player, aliceBalance)` to drain all 10 ETK.

**State change:**

| Step | Alice Balance | Player Allowance |
|------|--------------|-----------------|
| Initial | 10 ETK | 0 |
| After `permit()` | 10 ETK | 53300...9571 ETK |
| After `transferFrom()` | 0 ETK | unchanged |

**Critical section of the exploit script:**

```solidity
// Forged values: ECDSA.recover(bytes32(forgedAmount), forgedTokenOwnerSignature) == ALICE
uint256 forgedAmount = 53300743415126771190813074077432648373918225301719409543247181011795344659571;
bytes memory forgedTokenOwnerSignature = hex"377cad...79d1b";

TARGET.permit(forgedAmount, player, forgedTokenOwnerSignature, spenderSignature);
TARGET.transferFrom(ALICE, player, TARGET.balanceOf(ALICE));
```

## Real-World Reference

This class of vulnerability falls under **ECDSA Signature Malleability / Missing Hash** in smart contract audit checklists (SWC-117, SWC-122). While no single high-profile exploit is exclusively attributed to a missing hash step in `permit()`, the pattern is a well-documented audit finding in ERC-20 permit extensions and off-chain signature systems. OpenZeppelin's ECDSA library enforces `s < n/2` and requires a pre-hashed digest precisely to prevent this class of forgery. Any contract that bypasses this by passing raw values to `ecrecover` is exploitable by this technique.
