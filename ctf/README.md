# CTF & Security Challenges

Hands-on exploit development through Capture The Flag (CTF) challenges and vulnerability training platforms. Each solved challenge includes a detailed write-up and a working Foundry-based exploit where applicable.

## Platforms

| Platform | Description | Status |
|----------|-------------|--------|
| [Ethernaut](./ethernaut/) | OpenZeppelin's wargame — 40 levels covering core smart contract vulnerability patterns | Completed (40/40) |

## Repository Structure

Each platform has its own folder structure documented in its own README. They differ intentionally:

- **Ethernaut** — Small, self-contained challenges. Each level is a single directory with a write-up, the original vulnerable contract, the exploit contract, and a Foundry script. See [ethernaut/README.md](./ethernaut/README.md).

## Methodology

1. **Read** the vulnerable contract — identify the bug category before looking at hints.
2. **Exploit** — write a working proof of concept (PoC) on-chain via Foundry where applicable.
3. **Document** — write a short analysis: what the vulnerability is, how it was exploited, and what the real-world mitigation looks like.
