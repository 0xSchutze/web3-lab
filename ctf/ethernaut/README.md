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
├── <name>.md              # Write-up: vulnerability analysis, exploit steps, key takeaway
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
| 09 | King | DoS | ⬜ | — |
| 10 | Re-entrancy | Reentrancy | ⬜ | — |
| 11 | Elevator | Interface Abuse | ⬜ | — |
| 12 | Privacy | Storage Layout | ⬜ | — |
| 13 | Gatekeeper One | Access Control | ⬜ | — |
| 14 | Gatekeeper Two | Access Control | ⬜ | — |
| 15 | Naught Coin | ERC20 Approval | ⬜ | — |
| 16 | Preservation | Delegatecall + Storage | ⬜ | — |
| 17 | Recovery | Contract Address Prediction | ⬜ | — |
| 18 | MagicNumber | EVM Bytecode | ⬜ | — |
| 19 | Alien Codex | Storage Manipulation | ⬜ | — |
| 20 | Denial | DoS (Gas) | ⬜ | — |
| 21 | Shop | Interface Abuse | ⬜ | — |
| 22 | Dex | DEX Price Manipulation | ⬜ | — |
| 23 | Dex Two | DEX Token Injection | ⬜ | — |
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

- Access Control — improper ownership checks, `tx.origin` misuse
- Arithmetic — integer overflow/underflow (pre-0.8.0)
- Bad Randomness — predictable on-chain PRNG
- Delegatecall — storage collision, unprotected proxy fallbacks
- Forceful ETH — `selfdestruct` bypass of `payable` restrictions
- Information Disclosure — reading `private` storage slots via RPC
