# Force

## Vulnerability: Forceful ETH Transfer via `selfdestruct`

**Category:** Unexpected Ether Reception
**Severity:** Medium

## Analysis

The `Force` contract has an empty body — no `receive()`, no `fallback()`, no `payable` functions. Under normal circumstances, any attempt to send ETH to this contract would revert because there is no mechanism to accept it.

However, `selfdestruct(address)` bypasses all of these checks. When a contract calls `selfdestruct(targetAddress)`, the EVM destroys the calling contract and forcibly transfers its entire ETH balance to the target address. The target contract has no ability to reject this transfer — it cannot revert, and neither `receive()` nor `fallback()` is invoked.

## Exploit Files

- [exploit.sol](./exploit.sol) — Payable contract that self-destructs into the target
- [exploitScript.s.sol](./exploitScript.s.sol) — Deploys with 1 wei and triggers `selfdestruct`

## Key Takeaway

Never assume that `address(this).balance == 0` just because your contract has no `payable` functions. ETH can be forcefully sent to any contract via `selfdestruct` (and also via pre-calculated `CREATE2` addresses or coinbase rewards). Any invariant that relies on tracking exact contract balances must account for this edge case.

**Note:** As of Solidity 0.8.24 / the Dencun upgrade, `selfdestruct` only transfers ETH but no longer removes the contract's code (except when called in the same transaction as deployment). The full removal behavior is being deprecated.