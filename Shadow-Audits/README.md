# Shadow Audits

Independent shadow audits of historical Code4rena and Sherlock contests. Includes custom Proof of Concepts (PoCs) for both independent discoveries and assimilated findings.

## Structure

Each audit directory contains:
- `0xSchutze_Report.md`: Breakdown of the vulnerability, EVM mechanics, and root cause.
- `PoCs/`: Executable Foundry tests demonstrating the exploit.

## Chronology

> [!NOTE]
> Directories and PoC files are strictly numbered (e.g., `01_`, `02_`) to map the exact chronological sequence of exploitation. As new PoCs are developed, their technical breakdowns and retrospectives are added directly to the protocol's `0xSchutze_Report.md`.
> 
> **Important:** The dates in the directory names (e.g., `2024-11` in `01_2024-11-Ethena`) refer to when the original public contest took place, not my shadow audit execution timeline.

## Methodology

> [!TIP]
> **Time-Boxed Recon:** The reconnaissance phase for each target is strictly time-boxed to 3-4 hours. Instead of line-by-line reads, the focus is entirely on isolating high-impact vectors within this window. The remaining time is spent engineering the Foundry PoCs.

## Audits

| Protocol | Source | Focus Area | Status |
|----------|--------|------------|--------|
| [Ethena Labs](./01_2024-11-Ethena) | Code4rena | Access Control, Proxy Upgrades | Completed |
| [Renzo Protocol](./02_2024-04-renzo) | Code4rena | EVM Gas Mechanics, Yul/Assembly, Oracle Arbitrage | Completed |
| [Malda](./03_2025-07-malda) | Sherlock | Cross-Chain Bridges, Lending Accounting, Replay Attacks | In Progress |
