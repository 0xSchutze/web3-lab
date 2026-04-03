# web3-lab

Personal learning repository. Documenting my path from Solidity fundamentals to smart contract security research — through building, breaking, and analyzing real protocols.

---

## Learning Path

The goal is to master development first, then transition into security. Every protocol here was built to understand something specific at the implementation level, not to ship a product.

> **Note:** Folders are numbered chronologically (01 → 04) to demonstrate the learning progression, from foundational concepts to complex protocol architecture.

| Project | Focus | Key Concepts |
|---|---|---|
| [01_simple-contracts](./contracts/01_simple-contracts) | Solidity fundamentals | Structs, mappings, modifiers, events, ERC20/ERC721 basics |
| [02_mini-vault-protocol](./contracts/02_mini-vault-protocol) | Access control & factory patterns | Role-based auth, factory deployment, ERC20 integration, Foundry testing |
| [03_mini-dex-protocol](./contracts/03_mini-dex-protocol) | AMM mechanics & DeFi primitives | x·y=k invariant, LP share math, reserve sync, full-stack Web3 DApp |
| [04_mini-staking-protocol](./contracts/04_mini-staking-protocol) | Reward distribution math | Synthetix model, time-weighted O(1) accumulator, CEI pattern, Foundry invariant tests |

---

## Structure

```
web3-lab/
├── contracts/
│   ├── 01_simple-contracts/       — Solidity fundamentals (structs, mappings, ERC standards)
│   ├── 02_mini-vault-protocol/    — Factory pattern, access control, Foundry testing
│   ├── 03_mini-dex-protocol/      — AMM mechanics, LP math, full-stack DApp
│   └── 04_mini-staking-protocol/  — Synthetix reward math, events, Foundry invariant tests
├── Notes/
│   ├── 01_solidity-basics/        — 20+ reference notes, linked from practice contracts
│   └── 02_defi-fundamentals/      — AMM math, LP mechanics, oracle patterns
├── ctf/                           — CTF solutions: Ethernaut, Damn Vulnerable DeFi
├── pocs/                          — Proof of concept exploits
└── hack-analysis/                 — Real-world hack breakdowns
```

> `ctf/`, `pocs/`, and `hack-analysis/` are part of the upcoming security phase.

---

## Notes

The [`Notes/`](./Notes) directory contains technical reference notes written while building the contracts above. Each concept links back to the practice contract that uses it — so the notes and code teach each other.

- [01 — Solidity Basics](./Notes/01_solidity-basics) — 20+ topics from arrays to ERC721 transfer logic
- [02 — DeFi Fundamentals](./Notes/02_defi-fundamentals) — AMM math, LP mechanics, oracle patterns

---

*0xSchutze — building to understand, then audit.*
