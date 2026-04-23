# Level 32: Impersonator

**Target:** [Impersonator.sol](./Impersonator.sol)
**Exploit:** [exploitScript.s.sol](./exploitScript.s.sol)

## Vulnerability

`ECLocker` validates signatures using the raw `ecrecover` precompile without enforcing the lower-half constraint on `s` (`s < n/2`). This makes the contract vulnerable to ECDSA signature malleability: an attacker can derive a second, mathematically valid signature from the original one, bypass the `usedSignatures` blocklist, and call `changeController` to set `controller` to `address(0)` — allowing anyone to open the lock.

## Key Concepts

**ECDSA Signature Malleability**
The secp256k1 elliptic curve is symmetric. For any valid signature `(r, s, v)`, a second signature `(r, n - s, v')` exists that recovers the same public key. If a contract blocklists signatures only by their raw `(r, s, v)` tuple, the malleable counterpart produces a different blocklist hash and passes through unchecked.

**secp256k1 Curve Order (n)**
```
n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
```
The original `s` and `n - s` represent two symmetric points on the curve that both recover to the same public key.

**`ecrecover` Returns `address(0)` on Failure**
Solidity's built-in `ecrecover` precompile does not revert on an invalid or manipulated signature — it silently returns `address(0)`. Once `controller` is set to `address(0)`, any subsequent `open()` call with a deliberately invalid signature will produce `address(0)` from `ecrecover`, match `controller`, and succeed. The door is permanently open to everyone.

**EIP-2 and the Contract-Level Gap**
The Ethereum network has rejected high-`s` transactions at the protocol layer since the Homestead hard fork (EIP-2). However, the `ecrecover` precompile does not enforce this rule — it is a protocol-level filter only. OpenZeppelin's `ECDSA.tryRecover` re-applies the `s < n/2` check inside the contract; bypassing it by calling `ecrecover` directly reintroduces the vulnerability.

## Root Cause

The developer used the raw `ecrecover` precompile instead of OpenZeppelin's `ECDSA.tryRecover`, which enforces `s < n/2`. The absence of this single check allows the mathematically equivalent malleable signature to produce a different `usedSignatures` hash, bypass the blocklist, and pass `_isValidSignature` with the original controller's recovered address intact.

## Exploit

**Step 1 — Parse the original signature from the `NewLock` event log**

The `signature` field is a 96-byte ABI-encoded array. Layout:

| Byte Range | Field | Value |
|---|---|---|
| 0 – 63 | `r` | `0x1932...3B91` |
| 64 – 127 | `s` | `0x7848...FF2` |
| 128 – 191 | `v` (right-padded) | `0x...1B` (= 27) |

**Step 2 — Compute the malleable counterpart and call `changeController`**

```solidity
uint256 n     = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;
bytes32 new_s = bytes32(n - uint256(s)); // 0x87b7...814f
uint8   new_v = v == 27 ? 28 : 27;       // 28

// new_s is not in usedSignatures → _isValidSignature passes.
// ecrecover still recovers the original controller address.
// controller is set to address(0).
ECLocker(target).changeController(new_v, r, new_s, address(0));
```

**Win Condition (`validateInstance`):**
```solidity
return locker.controller() == address(0);
```

## Real-World Reference

**Transaction Malleability — Mt. Gox (2014)**
This is the contract-level analogue of the Transaction Malleability attack that contributed to the collapse of the Mt. Gox exchange. Attackers mutated the `s` value of in-flight transactions to change their transaction ID (txid) without invalidating the signature. Withdrawal tracking systems keyed on txid failed to recognise the settled transaction, allowing repeated withdrawal requests for the same funds. Ethereum addressed this at the network layer with EIP-2; however, contracts using raw `ecrecover` without a lower-half `s` check silently reintroduce the same class of vulnerability.
