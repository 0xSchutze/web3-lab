# Shadow Audits

Independent reproduction and analysis of vulnerabilities from platforms like Code4rena and Sherlock.

Independent reproductions of exploits with custom Foundry Proof of Concepts (PoCs).

## Structure

Each audit directory contains:
- `0xSchutze_Report.md`: Breakdown of the vulnerability, the EVM mechanics, and the root cause.
- `PoCs/`: executable Foundry tests demonstrating the exploit.

## Naming Convention & Chronology

> [!NOTE]
> Directories and Proof of Concept (PoC) files in this repository are strictly numbered (e.g., `01_`, `02_`). These numerical prefixes represent the chronological order of execution. They map the exact sequence in which targets were reverse-engineered and exploited, providing a transparent timeline of technical progression. Furthermore, as new PoC files are committed, their corresponding technical breakdowns and retrospectives are synchronously appended to the respective `0xSchutze_Report.md` file. 
> 
> **Important:** The dates in the directory names (e.g., `2024-11` in `01_2024-11-Ethena`) refer exclusively to the time the original public contest took place. They do not represent the timeline of my own shadow audit process.

## Audits

| Protocol | Source | Focus Area | Status |
|----------|--------|------------|--------|
| [Ethena Labs](./01_2024-11-Ethena) | Code4rena | Access Control, Proxy Upgrades | Completed |
| [Renzo Protocol](./02_2024-04-renzo) | Code4rena | EVM Gas Mechanics, Yul/Assembly, Oracle Arbitrage | In Progress |
