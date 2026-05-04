# Level 36: Cashback

**Target:** [Cashback.sol](./Cashback.sol)
**Exploit:** [exploit.sol](./exploit.sol)
**Script:** [exploitScript.s.sol](./exploitScript.s.sol)

## Vulnerability

The `Cashback` contract's `onlyDelegatedToCashback` modifier validates the caller by reading the first 23 bytes of `msg.sender.code` and checking whether the embedded address matches the Cashback instance. This check can be bypassed by deploying a custom proxy whose first 23 bytes encode the expected EIP-7702 delegation prefix while the actual execution logic delegates to an attacker-controlled contract. Combined with EIP-7702 account delegation and direct storage manipulation, the attacker can spoof the nonce to 9999, trigger the SUPERCASHBACK_NONCE mint, and drain all cashback tokens.

## Key Concepts

**EIP-7702 Account Delegation (Type 4 Transactions)**
EIP-7702 allows EOAs to temporarily delegate their execution context to a smart contract by setting a 23-byte code prefix (`0xef0100 || address`). The `--auth` flag in `cast send` attaches a signed authorization to the transaction, making the EOA behave as if it has the target contract's code for the duration of the call. This is the mechanism the level expects the player to use legitimately but which can be weaponized with arbitrary delegation targets.

**Bytecode-Level Modifier Bypass**
The `onlyDelegatedToCashback` modifier uses `mload(add(code, 0x17))` to extract the delegated address from the caller's bytecode. A hand-crafted proxy embeds the Cashback address at exactly that offset while routing actual execution to `AttackerLogic` via a `JUMP` over the address bytes, followed by an EIP-1167-style `DELEGATECALL` tail.

**Solidity Storage Layout & Inheritance**
The `Cashback` contract uses a custom `layout at 0x442a...00` directive. Since it inherits `ERC1155` (which has 3 state variables: `_balances`, `_operatorApprovals`, `_uri`), the `nonce` variable is not at the base slot but at `base + 3`. The `NonceSetter` must write to slot `0x442a...03`, not `0x442a...00`.

**Transient Storage (EIP-1153)**
The `unlock` modifier uses transient storage (`tstore`/`tload`) to gate access to `accrueCashback` through the `onlyUnlocked` modifier. The attacker bypasses this by having `AttackerLogic.isUnlocked()` unconditionally return `true`, since the Cashback contract calls `Cashback(payable(msg.sender)).isUnlocked()` — which delegates to the proxy's logic.

## Root Cause

The `onlyDelegatedToCashback` modifier treats bytecode content as proof of delegation identity. It reads 23 bytes at a fixed offset and trusts that the address found there is the actual delegation target. This is a fundamentally flawed assumption: any contract can be deployed with arbitrary bytecode that satisfies the 23-byte pattern while delegating execution elsewhere. The modifier conflates "has the right bytes at offset 0x17" with "is genuinely delegated to Cashback."

## Exploit

The exploit is a three-phase operation spanning a Foundry script and two `cast send` transactions:

### Phase 1 — Proxy Deployment & Token Theft (Foundry Script)

1. Deploy `Exploit`, which internally deploys `AttackerLogic`.
2. `Exploit.deployProxy()` creates an 86-byte contract via `CREATE`:

| Offset | Bytes | Purpose |
|--------|-------|---------|
| 0-2 | `JUMP 0x28` | Skip over the embedded address |
| 3-22 | `<Cashback address>` | Satisfies `onlyDelegatedToCashback` |
| 23-39 | `00...00` (17 bytes) | Consumed by `PUSH31` inside the address |
| 40 | `JUMPDEST` | Safe landing zone after the jump |
| 41-85 | EIP-1167 proxy tail | `DELEGATECALL` to `AttackerLogic` |

3. The proxy calls `accrueCashback(NATIVE, 200 ether)` — Cashback mints 1 ETH worth of NATIVE tokens. The first `consumeNonce()` returns 10000, triggering the Super Cashback NFT mint.
4. The proxy calls `accrueCashback(FREE, 25000 ether)` — Cashback mints 500 FREE tokens.
5. `sweep()` transfers all ERC1155 tokens and the NFT to the player's EOA.

### Phase 2 — Nonce Manipulation (cast send)

```bash
cast send $PLAYER "setNonce()" \
    --auth <NonceSetter address> \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL
```

This delegates the player's EOA to `NonceSetter` via EIP-7702 and calls `setNonce()`, which writes `9999` directly to storage slot `0x442a...03` (the actual nonce slot, offset by 3 due to ERC1155 inheritance).

### Phase 3 — Final Delegation & Second NFT Mint (cast send)

```bash
cast send $PLAYER "payWithCashback(address,address,uint256)" \
    0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE \
    0x0000000000000000000000000000000000000000 0 \
    --auth <Cashback address> \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL
```

This re-delegates the player's EOA to the real Cashback contract. Calling `payWithCashback` with amount 0 triggers `accrueCashback`, which calls `consumeNonce()` on the player (now running Cashback code), incrementing the nonce from 9999 to 10000 — the `SUPERCASHBACK_NONCE` threshold. This mints the second NFT directly to the player.

### Validation Conditions (CashbackFactory.validateInstance)

| Condition | How Satisfied |
|-----------|---------------|
| `balanceOf(player, NATIVE_ID) == 1 ether` | Phase 1 — proxy accrues max NATIVE cashback, sweeps to player |
| `balanceOf(player, FREE_ID) == 500 ether` | Phase 1 — proxy accrues max FREE cashback, sweeps to player |
| `ownerOf(uint160(player)) == player` | Phase 3 — second NFT minted directly to player |
| `balanceOf(player) >= 2` | Phase 1 (first NFT via proxy, swept) + Phase 3 (second NFT) |
| `player.code.length == 23` | Phase 3 — `--auth <Cashback>` sets EIP-7702 delegation |
| `bytes23(player.code) == expectedCode` | Phase 3 — delegation prefix matches `ef0100 || Cashback` |

## Real-World Reference

This level targets EIP-7702 (Pectra upgrade, May 2025), a mechanism that fundamentally blurs the line between EOAs and smart contracts. While no major real-world exploit of EIP-7702 delegation has been publicly disclosed at the time of writing, the underlying pattern — trusting bytecode content as an identity proof rather than verifying delegation authority through a secure registry — mirrors the class of vulnerabilities seen in early EIP-1167 proxy deployments and metamorphic contract attacks (e.g., Tornado Cash governance takeover via `CREATE2` + `SELFDESTRUCT` redeployment). As EIP-7702 adoption grows, contracts that inspect `msg.sender.code` for delegation validation without a cryptographic authority check will be prime targets.
