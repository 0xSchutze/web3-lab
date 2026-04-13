# CTF & Security Challenges

Hands-on exploit development through Capture The Flag (CTF) challenges and vulnerability training platforms. Each solved challenge includes a detailed write-up and, where applicable, a working Foundry-based exploit.

## Platforms

| Platform | Description | Status |
|----------|-------------|--------|
| [Ethernaut](./ethernaut/) | OpenZeppelin's wargame — 29 levels covering core smart contract vulnerabilities | In Progress |
| Damn Vulnerable DeFi | DeFi-specific exploit scenarios (flash loans, lending, governance) | Not Started |
| Valves Security | Pattern-based auditor training derived from 50,000 real audit findings | Not Started |

## Repository Structure

Each challenge follows this layout:

```
<platform>/<challenge_number>_<challenge_name>/
├── <number>_<name>.md       # Write-up: vulnerability analysis, exploit steps, key takeaway
├── exploit.sol              # On-chain attacker contract (if needed)
├── exploitScript.s.sol      # Foundry deployment/execution script
├── IExploit.sol             # Interface for target and attacker contracts
└── foundry.toml             # Per-challenge Foundry config
```

## Methodology

1. **Read** the vulnerable contract — identify the bug category before looking at hints.
2. **Exploit** — write a working proof of concept (PoC), preferably on-chain via Foundry.
3. **Document** — write a short analysis covering: what the vulnerability is, how it was exploited, and what the real-world mitigation looks like.
