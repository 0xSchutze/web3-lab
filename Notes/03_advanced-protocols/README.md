# Advanced Protocols

This section covers low-level EVM mechanics and advanced smart contract architecture patterns.
Where **DeFi Fundamentals** focuses on protocol design, **Advanced Protocols** goes deeper —
into the execution model, storage layout, upgradeability, and the tools used by both engineers
and security researchers to understand what a contract is *actually* doing.

## Topics

- [Proxy Pattern & Upgradeability (EIP-1967, delegatecall, storage collision)](./proxy-pattern.md)
- [Yul / Inline Assembly (sload, sstore, calldatacopy, opcodes)](./yul-inline-assembly.md)

## Practice Contracts

- [Upgradeable Proxy](../../contracts/07_upgradeable-proxy) — EIP-1967 Transparent Proxy, sıfırdan Yul ile yazılmış. delegatecall forwarding, admin access control, upgrade + ownership transfer.
