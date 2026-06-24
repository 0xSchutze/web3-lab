# 0xSchutze - Ethena Labs Shadow Audit Report

## 1. Introduction & Scope
- **Protocol:** Ethena Labs (2024-11)
- **Audit Type:** Shadow Audit (Reverse Engineering & Independent Verification)
- **Researcher:** 0xSchutze

This report contains independent discoveries and reverse-engineered proofs of concept (PoCs) for critical/medium vulnerabilities found within the Ethena Labs smart contracts. The methodology involves an initial independent audit followed by a detailed review of the official Code4rena findings.

---

## 2. My Discoveries (Independent Findings)
*This section contains vulnerabilities that I independently discovered and validated prior to reading the official report.*

> *No independent discoveries were made during this audit. All findings below are reverse-engineered from the official report.*

---

## 3. Assimilated Discoveries (Reverse-Engineered Findings)
*This section contains critical/medium vulnerabilities from the official report that I initially missed. I have reverse-engineered the root causes and written my own original Foundry PoCs to demonstrate the exploits.*

### [M-01] Blacklisted users can bypass frozen state by abusing `burn()` when `transferState == WHITELIST_ENABLED`

**Description & Business Impact:**
The `_beforeTokenTransfer` hook in `UStb.sol` contains a logic bug in the `WHITELIST_ENABLED` state branch. When a user attempts to burn tokens (`to == address(0)`), the contract checks if the sender has `WHITELISTED_ROLE`, but completely omits the `!hasRole(BLACKLISTED_ROLE)` check.

Because of this missing check, a blacklisted user can bypass the freeze mechanism. Although they cannot transfer funds to another wallet (which is correctly blocked by the normal transfer branch), they can call `burn()` to destroy their frozen balance. This prevents the protocol admins from recovering the confiscated funds via `redistributeLockedAmount`, causing a permanent loss of assets (griefing).

**Retrospective / Missed Vector:**
I verified that the `WHITELIST_ENABLED` branch checks for `WHITELISTED_ROLE` and moved on. I never asked the follow-up question: does this path also check for `BLACKLISTED_ROLE`? A user can simultaneously hold both roles — whitelisted before, blacklisted after an emergency. My audit stopped at confirming the presence of the expected check. I didn't audit for the absence of a check that also needed to be there.

**Proof of Concept (Foundry):**
The complete executable PoC can be found in [`PoCs/01_Ethena_M01_PoC.t.sol`](./PoCs/01_Ethena_M01_PoC.t.sol).
Below is the core exploit execution demonstrating the vulnerability:

```solidity
// Admin applies protocol-wide whitelist restriction.
vm.prank(admin);
ustb.updateTransferState(IUStbDefinitions.TransferState.WHITELIST_ENABLED);

// The WHITELIST_ENABLED branch in _beforeTokenTransfer omits the blacklist check for burn().
// Therefore, Alice can destroy her frozen tokens, causing permanent asset loss.
vm.prank(alice);
ustb.burn(ALICE_BALANCE);

uint256 balanceAfter = ustb.balanceOf(alice);
assertEq(balanceAfter, 0, "Frozen assets successfully destroyed");
```


---

### [M-02] Non-whitelisted users can redeem collateral by bypassing checks in the `MINTER_CONTRACT` branch

**Description & Business Impact:**
A second logic bug exists inside the `WHITELIST_ENABLED` state of `_beforeTokenTransfer`. When a redemption is triggered via the `MINTER_CONTRACT`, the system checks if the user is blacklisted (`!hasRole(BLACKLISTED_ROLE, from)`) but completely forgets to check if the user is whitelisted (`hasRole(WHITELISTED_ROLE, from)`).

Because of this omission, an ordinary (unwhitelisted) user can successfully submit a redemption request. The off-chain Redeemer bot submits the burn transaction on their behalf, and the contract accepts it despite the strict whitelist-only lock. This breaks the core invariant that only whitelisted users can burn UStb during a protocol lockdown.

**Retrospective / Missed Vector:**
I was unaware of the off-chain redemption mechanic: that an ordinary user submits a redemption request which the Redeemer bot executes via `MINTER_CONTRACT`. Without that protocol-level context, I had no reason to audit whether the `MINTER_CONTRACT` branch independently enforced the `WHITELIST_ENABLED` invariant. The attack path was invisible to me because I didn't know a normal user could trigger that branch.

**Proof of Concept (Foundry):**
The complete executable PoC can be found in [`PoCs/02_Ethena_M02_PoC.t.sol`](./PoCs/02_Ethena_M02_PoC.t.sol).
Below is the core exploit execution demonstrating the vulnerability:

```solidity
// Admin applies protocol-wide whitelist restriction.
vm.prank(admin);
ustb.updateTransferState(IUStbDefinitions.TransferState.WHITELIST_ENABLED);

// The MINTER_CONTRACT branch in _beforeTokenTransfer omits the whitelist check.
// Therefore, the minter can burn Alice's tokens despite the lockdown.
vm.prank(minter);
ustb.burnFrom(alice, ALICE_BALANCE); 

uint256 balanceAfter = ustb.balanceOf(alice);
assertEq(balanceAfter, 0, "Unauthorized redemption successful");
```
