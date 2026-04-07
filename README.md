# web3-lab

Personal learning repository. Documenting my path from Solidity fundamentals to smart contract security research — through building, breaking, and analyzing real protocols.

Every protocol here was built to understand something specific at the implementation level, not to ship a product.

---

## What's Here

**[`contracts/`](./contracts)** — Protocol implementations. Each folder is a self-contained Foundry project with its own README, test suite, and deploy script. Organized chronologically to reflect the learning progression — from foundational Solidity to advanced DeFi mechanics.

**[`Notes/`](./Notes)** — Technical reference notes written while building. Covers Solidity internals, DeFi mechanics, precision math, and security patterns. Each note links back to the contract that uses it.

**[`ctf/`](./ctf)** — CTF solutions with write-ups explaining the vulnerability, the exploit, and the underlying concept. Ethernaut → Damn Vulnerable DeFi.

**[`pocs/`](./pocs)** — Standalone proof-of-concept exploits demonstrating specific vulnerability classes.

**[`hack-analysis/`](./hack-analysis)** — Real-world hack breakdowns with Foundry fork test reproductions.

> `ctf/`, `pocs/`, and `hack-analysis/` are part of the upcoming security phase.

---

## Learning Path

Two phases, executed sequentially.

**Phase 1 — Developer Mastery** (current)
Building progressively complex DeFi protocols from scratch — each one covering a different layer of how decentralized finance actually works. Every protocol is tested with Foundry and shipped with a deploy script.

**Phase 2 — Security Research** (upcoming)
Transitioning from builder to auditor. CTF challenges, hack reproductions, PoC writing, formal audit tooling (Slither, Echidna, Foundry invariants), and competitive audits on CodeHawks and Code4rena.

---

## Notes

The [`Notes/`](./Notes) directory contains technical reference notes written alongside the contracts. Each concept is written in English, links to the contract that uses it, and goes beyond "what is X" into "why does X work this way and where does it break."

- [01 — Solidity Basics](./Notes/01_solidity-basics)
- [02 — DeFi Fundamentals](./Notes/02_defi-fundamentals)

