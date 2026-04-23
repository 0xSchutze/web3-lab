# Ethernaut

[OpenZeppelin's Ethernaut](https://ethernaut.openzeppelin.com/) — a wargame played on the Sepolia testnet where each level presents a vulnerable smart contract to exploit.

## Setup

The `lib/` directories are **gitignored** — they are not included in the repository. Each challenge uses a standalone Foundry project with **forge-std** as the only dependency.

To run the exploit scripts after cloning, install the dependency inside each challenge folder:

```bash
cd <challenge_folder>
forge install foundry-rs/forge-std --no-git
```

You will also need a `.env` file (gitignored) with your Sepolia RPC URL and private key for on-chain deployment.

## Repository Structure

Each challenge is a self-contained directory:

```
<number>_<name>/
├── <name>.md              # Write-up: vulnerability analysis, exploit steps, real-world reference
├── <TargetContract>.sol   # Original vulnerable contract from Ethernaut
├── exploit.sol            # On-chain attacker contract (if applicable)
├── IExploit.sol           # Interfaces for target and attacker contracts
├── exploitScript.s.sol    # Foundry deployment/execution script
└── foundry.toml           # Per-challenge Foundry config (src = ".")
```

Challenges solved via browser console only (no Foundry exploit needed) will contain only the `.md` and the target contract.

## Progress

| # | Challenge | Category | Solved | Write-Up |
|---|-----------|----------|--------|----------|
| 01 | [Fallback](./01_fallback/) | Access Control | ✅ | [Notes](./01_fallback/README.md) |
| 02 | [Fal1out](./02_fal1out/) | Access Control (Constructor Bug) | ✅ | [Notes](./02_fal1out/README.md) |
| 03 | [CoinFlip](./03_coinFlip/) | Bad Randomness | ✅ | [Notes](./03_coinFlip/README.md) |
| 04 | [Telephone](./04_telephone/) | Access Control (`tx.origin`) | ✅ | [Notes](./04_telephone/README.md) |
| 05 | [Token](./05_token/) | Integer Underflow | ✅ | [Notes](./05_token/README.md) |
| 06 | [Delegation](./06_delegation/) | Delegatecall Misuse | ✅ | [Notes](./06_delegation/README.md) |
| 07 | [Force](./07_force/) | Forceful ETH Transfer | ✅ | [Notes](./07_force/README.md) |
| 08 | [Vault](./08_vault/) | Information Disclosure | ✅ | [Notes](./08_vault/README.md) |
| 09 | [King](./09_king/) | DoS via Forced Revert | ✅ | [Notes](./09_king/README.md) |
| 10 | [Re-entrancy](./10_%20Re-entrancy/) | Reentrancy | ✅ | [Notes](./10_%20Re-entrancy/README.md) |
| 11 | [Elevator](./11_elevator/) | Interface / Oracle Abuse | ✅ | [Notes](./11_elevator/README.md) |
| 12 | [Privacy](./12_privacy/) | Storage Layout | ✅ | [Notes](./12_privacy/README.md) |
| 13 | [Gatekeeper One](./13_gatekeeper/) | Access Control + Gas | ✅ | [Notes](./13_gatekeeper/README.md) |
| 14 | [Gatekeeper Two](./14_gatekeeper_two/) | Access Control + EVM Lifecycle | ✅ | [Notes](./14_gatekeeper_two/README.md) |
| 15 | [Naught Coin](./15_naught_coin/) | ERC20 Approval Bypass | ✅ | [Notes](./15_naught_coin/README.md) |
| 16 | [Preservation](./16_preservation/) | Delegatecall + Storage Collision | ✅ | [Notes](./16_preservation/README.md) |
| 17 | [Recovery](./17_recovery/) | Contract Address Derivation | ✅ | [Notes](./17_recovery/README.md) |
| 18 | [Magic Number](./18_magic_number/) | EVM Bytecode Engineering | ✅ | [Notes](./18_magic_number/README.md) |
| 19 | [Alien Codex](./19_alien_codex/) | Storage Manipulation | ✅ | [Notes](./19_alien_codex/README.md) |
| 20 | [Denial](./20_denial/) | DoS (Gas Exhaustion) | ✅ | [Notes](./20_denial/README.md) |
| 21 | [Shop](./21_shop/) | Interface / Oracle Abuse | ✅ | [Notes](./21_shop/README.md) |
| 22 | [Dex](./22_dex/) | AMM Price Manipulation | ✅ | [Notes](./22_dex/README.md) |
| 23 | [Dex Two](./23_dex_two/) | DEX Token Injection | ✅ | [Notes](./23_dex_two/README.md) |
| 24 | [Puzzle Wallet](./24_puzzle_wallet/) | Proxy Storage Collision | ✅ | [Notes](./24_puzzle_wallet/README.md) |
| 25 | [Motorbike](./25_motorbike/) | UUPS Proxy — Uninitialized Impl | ✅ | [Notes](./25_motorbike/README.md) |
| 26 | [Double Entry Point](./26_double_entry_point/) | Dual Transfer Path + Forta Bot | ✅ | [Notes](./26_double_entry_point/README.md) |
| 27 | [Good Samaritan](./27_good_samaritan/) | Custom Error Spoofing | ✅ | [Notes](./27_good_samaritan/README.md) |
| 28 | [Gatekeeper Three](./28_gatekeeper_three/) | Access Control (Multi-Gate) | ✅ | [Notes](./28_gatekeeper_three/README.md) |
| 29 | [Switch](./29_switch/) | Calldata Offset Manipulation | ✅ | [Notes](./29_switch/README.md) |
| 30 | [Higher Order](./30_higher_order/) | Assembly Type Confusion | ✅ | [Notes](./30_higher_order/README.md) |
| 31 | [Stake](./31_stake/) | Staking Accounting / CEI Violation | ✅ | [Notes](./31_stake/README.md) |
| 32 | [Impersonator](./32_impersonator/) | ECDSA Signature Malleability | ✅ | [Notes](./32_impersonator/README.md) |
| 33 | MagicAnimalCarousel | Data Packing / Encoding | ⬜ | — |
| 34 | BetHouse | State / Randomness | ⬜ | — |
| 35 | EllipticToken | Cryptography (Elliptic Curve) | ⬜ | — |
| 36 | ImpersonatorTwo | Signature / Auth Bypass v2 | ⬜ | — |
| 37 | Cashback | DeFi Logic Error / Drain | ⬜ | — |
| 38 | UniqueNFT | ERC721 Standard Abuse | ⬜ | — |
| 39 | Forger | Hash Collision / Forgery | ⬜ | — |
| 40 | NotOptimisticPortal | L2 Cross-Chain Bridge | ⬜ | — |

## Tools Used

- **Foundry** (`forge script` + `cast`) for on-chain exploit deployment
- **Browser console** (`web3.js`) for simple interactions
- **Sepolia testnet** for all transactions

## Vulnerability Categories Covered

- Access Control — ownership checks, `tx.origin` misuse, multi-gate bypasses
- Arithmetic — integer overflow/underflow (pre-0.8.0)
- Bad Randomness — predictable on-chain PRNG
- Delegatecall — storage collision, unprotected proxy fallbacks, two-phase hijack
- ERC20 — approval/transferFrom bypass of custom transfer restrictions
- EVM Bytecode — raw opcode authoring, creation vs runtime code separation
- Forceful ETH — `selfdestruct` bypass of `payable` restrictions
- Information Disclosure — reading `private` storage slots via RPC
- On-Chain Forensics — deterministic address derivation via RLP encoding
- UUPS Proxy — uninitialized implementation, EIP-6780 selfdestruct deprecation context
- Dual Entry Point — token migration residue, cross-contract error injection, Forta bot authoring
- Custom Error Spoofing — `try/catch` origin blindness, `INotifyable` callback exploitation
- Calldata Manipulation — ABI dynamic-type offset forgery, split modifier/call read paths
- Assembly Type Confusion — `calldataload` 32-byte word bypass of Solidity type boundaries
- Staking Accounting — CEI violation in ERC-20 staking, unchecked `transferFrom` return, phantom ETH inflation via non-receivable attacker contract
- ECDSA Signature Malleability — raw `ecrecover` without `s < n/2` enforcement, malleable `(r, n-s, v')` counterpart bypasses `usedSignatures` blocklist
