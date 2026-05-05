# CTF & Security Challenges

Hands-on exploit development through Capture The Flag (CTF) challenges and vulnerability training platforms. Each solved challenge includes a detailed write-up and a working Foundry-based exploit where applicable.

## Platforms

| Platform | Description | Status |
|----------|-------------|--------|
| [Ethernaut](./ethernaut/) | OpenZeppelin's wargame — 40 levels covering core smart contract vulnerability patterns | Completed (40/40) |
| Valves Security | 372 challenges across 19 categories, derived from 50,000 real audit findings. Solved in browser. | In Progress |
| [Damn Vulnerable DeFi](./damn-vulnerable-defi/) | 18 DeFi-specific exploit scenarios: flash loans, oracle manipulation, governance attacks | Not Started |

## Repository Structure

Each platform has its own folder structure documented in its own README. They differ intentionally:

- **Ethernaut** — Small, self-contained challenges. Each level is a single directory with a write-up, the original vulnerable contract, the exploit contract, and a Foundry script. See [ethernaut/README.md](./ethernaut/README.md).
- **Valves** — Solved in browser, no on-chain deployment. Only notes are tracked here.
- **Damn Vulnerable DeFi** — Larger, multi-contract DeFi systems. Each challenge uses a full Foundry project structure with `src/`, `test/`, and a detailed write-up.

## Methodology

1. **Read** the vulnerable contract — identify the bug category before looking at hints.
2. **Exploit** — write a working proof of concept (PoC) on-chain via Foundry where applicable.
3. **Document** — write a short analysis: what the vulnerability is, how it was exploited, and what the real-world mitigation looks like.
