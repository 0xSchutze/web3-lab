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
| 01 | [Fallback](./01_fallback/) | Access Control | ✅ | [Notes](./01_fallback/01_fallback.md) |
| 02 | [Fal1out](./02_fal1out/) | Access Control (Constructor Bug) | ✅ | [Notes](./02_fal1out/02_fal1out.md) |
| 03 | [CoinFlip](./03_coinFlip/) | Bad Randomness | ✅ | [Notes](./03_coinFlip/03_coinFlip.md) |
| 04 | [Telephone](./04_telephone/) | Access Control (`tx.origin`) | ✅ | [Notes](./04_telephone/04_telephone.md) |
| 05 | [Token](./05_token/) | Integer Underflow | ✅ | [Notes](./05_token/05_token.md) |
| 06 | [Delegation](./06_delegation/) | Delegatecall Misuse | ✅ | [Notes](./06_delegation/06_delegation.md) |
| 07 | [Force](./07_force/) | Forceful ETH Transfer | ✅ | [Notes](./07_force/07_force.md) |
| 08 | [Vault](./08_vault/) | Information Disclosure | ✅ | [Notes](./08_vault/08_vault.md) |
| 09 | [King](./09_king/) | DoS via Forced Revert | ✅ | [Notes](./09_king/09_king.md) |
| 10 | [Re-entrancy](./10_%20Re-entrancy/) | Reentrancy | ✅ | [Notes](./10_%20Re-entrancy/Re-entrancy.md) |
| 11 | [Elevator](./11_elevator/) | Interface / Oracle Abuse | ✅ | [Notes](./11_elevator/11_elevator.md) |
| 12 | [Privacy](./12_privacy/) | Storage Layout | ✅ | [Notes](./12_privacy/12_privacy.md) |
| 13 | [Gatekeeper One](./13_gatekeeper/) | Access Control + Gas | ✅ | [Notes](./13_gatekeeper/13_gatekeeper.md) |
| 14 | [Gatekeeper Two](./14_gatekeeper_two/) | Access Control + EVM Lifecycle | ✅ | [Notes](./14_gatekeeper_two/14_gatekeeper_two.md) |
| 15 | [Naught Coin](./15_naught_coin/) | ERC20 Approval Bypass | ✅ | [Notes](./15_naught_coin/15_naught_coin.md) |
| 16 | [Preservation](./16_preservation/) | Delegatecall + Storage Collision | ✅ | [Notes](./16_preservation/16_preservation.md) |
| 17 | [Recovery](./17_recovery/) | Contract Address Derivation | ✅ | [Notes](./17_recovery/17_recovery.md) |
| 18 | [Magic Number](./18_magic_number/) | EVM Bytecode Engineering | ✅ | [Notes](./18_magic_number/18_magic_number.md) |
| 19 | [Alien Codex](./19_alien_codex/) | Storage Manipulation | ✅ | [Notes](./19_alien_codex/19_alien_codex.md) |
| 20 | [Denial](./20_denial/) | DoS (Gas Exhaustion) | ✅ | [Notes](./20_denial/20_denial.md) |
| 21 | [Shop](./21_shop/) | Interface / Oracle Abuse | ✅ | [Notes](./21_shop/21_shop.md) |
| 22 | [Dex](./22_dex/) | AMM Price Manipulation | ✅ | [Notes](./22_dex/22_dex.md) |
| 23 | [Dex Two](./23_dex_two/) | DEX Token Injection | ✅ | [Notes](./23_dex_two/23_dex_two.md) |
| 24 | Puzzle Wallet | Proxy + Delegatecall | ⬜ | — |
| 25 | Motorbike | UUPS Proxy | ⬜ | — |
| 26 | DoubleEntryPoint | Detection Bot | ⬜ | — |
| 27 | Good Samaritan | Custom Errors | ⬜ | — |
| 28 | Gatekeeper Three | Access Control | ⬜ | — |
| 29 | Switch | Calldata Manipulation | ⬜ | — |

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
