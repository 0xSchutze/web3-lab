# 07 — Upgradeable Proxy

A minimal, fully-tested implementation of the EIP-1967 Transparent Upgradeable Proxy pattern, built from scratch using inline assembly (Yul) — without inheriting from OpenZeppelin or any external library.

Built to understand the mechanics at the EVM level: how `delegatecall` works, why storage slots must be isolated, and what makes a proxy truly upgradeable.

---

## Architecture

```
User
 │
 ▼
UpgradableProxy  ──delegatecall──►  CounterV1 / CounterV2
 │                                   (code only, no state)
 │
 └── EIP-1967 Storage Slots
       ├── _IMPLEMENTATION_SLOT  →  address of current implementation
       └── _ADMIN_SLOT           →  address of admin (upgrade authority)
```

The proxy holds all state. The implementation holds only logic.
When upgraded, the proxy points at a new implementation — the state is untouched.

---

## How It Works

### delegatecall

`delegatecall` borrows the code of the target contract and executes it
inside the caller's storage context. The implementation's variables never
change; every write goes to the proxy's storage.

```
Proxy.delegatecall(Counter.increment)
    → Counter's bytecode runs
    → but writes to Proxy's storage slot 0
    → Counter's own storage: untouched
```

### Storage Isolation (EIP-1967)

Normal Solidity variables are assigned slots in declaration order (slot 0, 1, 2…).
If the proxy stored `address implementation` at slot 0 and the implementation
stored `uint256 counter` at slot 0, a `delegatecall` would corrupt the
implementation address.

EIP-1967 prevents this by storing proxy-critical data at pseudo-random slots
derived from a keccak256 hash — mathematically guaranteed to never collide
with sequentially assigned slots:

```solidity
bytes32 constant _IMPLEMENTATION_SLOT =
    bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

bytes32 constant _ADMIN_SLOT =
    bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
```

These slots are read and written exclusively via inline assembly (`sload` / `sstore`),
since Solidity's type system cannot target arbitrary storage positions.

### Upgrade Flow

```
Admin calls upgradeTo(newImpl)
    └─► onlyOwner modifier reads _ADMIN_SLOT via sload
    └─► require(msg.sender == admin)
    └─► sstore(_IMPLEMENTATION_SLOT, newImpl)

Next call to proxy:
    └─► fallback() → _delegate()
    └─► sload(_IMPLEMENTATION_SLOT) → newImpl address
    └─► delegatecall to newImpl
    └─► state from V1 is intact, new logic applies
```

---

## Project Structure

```
src/
├── UpgradableProxy.sol    # EIP-1967 proxy: delegatecall, upgrade, ownership
├── CounterV1.sol          # Implementation V1 (increment)
└── CounterV2.sol          # Implementation V2 (increment + decrement)

test/
└── Proxy.t.sol            # 4 tests: delegatecall, upgrade, access control, ownership

script/
├── IProxy.sol             # Minimal interface for upgrade scripts
├── CounterV1.s.sol        # Deploy V1 implementation, write address to deployments.json
├── Proxy.s.sol            # Deploy proxy (reads IMPLEMENTATION_ADDRESS + ADMIN_ADDRESS from env)
└── UpgradeProxy.s.sol     # Deploy V2 + call upgradeTo on existing proxy (reads PROXY_ADDRESS from env)
```

---

## Setup

```bash
cd contracts/07_upgradeable-proxy
forge install foundry-rs/forge-std --no-git
forge build
forge test -vvvv
```

---

## Deployment (Sepolia)

```bash
# 1. Deploy V1 implementation
forge script script/CounterV1.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY

# 2. Deploy the proxy (reads addresses from .env)
#    Required: IMPLEMENTATION_ADDRESS, ADMIN_ADDRESS
forge script script/Proxy.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY

# 3. Upgrade to V2 (caller must be proxy admin)
#    Required: PROXY_ADDRESS
forge script script/UpgradeProxy.s.sol --rpc-url $RPC_URL --broadcast --private-key $ADMIN_PRIVATE_KEY
```

---

## Key Concepts Demonstrated

| Concept | Where |
|---|---|
| `delegatecall` — code borrowed, storage stays in proxy | `UpgradableProxy.sol` — `_delegate()` |
| EIP-1967 storage slot isolation | `UpgradableProxy.sol` — `_IMPLEMENTATION_SLOT`, `_ADMIN_SLOT` |
| Inline assembly (`sload` / `sstore`) for arbitrary slot access | `UpgradableProxy.sol` — all assembly blocks |
| `fallback()` as the delegation entry point | `UpgradableProxy.sol` — `fallback()` / `receive()` |
| Access control via assembly-read admin slot | `UpgradableProxy.sol` — `onlyOwner` modifier |
| Storage persistence across upgrades | `test/Proxy.t.sol` — `test_UpgradeToWithAdmin` |
| Interface-based upgrade scripting | `script/IProxy.sol`, `script/UpgradeProxy.s.sol` |
| Deployment address persistence via `vm.writeJson` | `script/CounterV1.s.sol` |
