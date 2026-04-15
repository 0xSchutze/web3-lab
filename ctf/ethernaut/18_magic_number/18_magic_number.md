# Level 18: Magic Number

**Target:** [MagicNum.sol](./MagicNum.sol)

## Vulnerability

Not a vulnerability — this is an **EVM bytecode engineering** challenge. The task is to deploy a contract whose runtime bytecode is at most 10 bytes and returns the value `42` (`0x2a`) when called.

## Key Concepts

**EVM execution layers:** Solidity code compiles through multiple abstraction levels:
1. **Solidity** → High-level, human-readable
2. **Yul (IR)** → Intermediate representation, stack-managed by compiler
3. **EVM Opcodes** → Raw machine instructions (PUSH, MSTORE, RETURN)
4. **Bytecode (Hex)** → Final on-chain binary (`0x602a...`)

**Creation vs Runtime code:** When deploying a contract, the EVM receives a single byte sequence. It executes this as **creation code**, which must `RETURN` the **runtime code** — the bytes that get permanently stored on-chain. The creation code is a bootstrapper; the runtime code is the actual contract.

**Stack machine model:** The EVM has no registers or function parameters. All operations consume and produce values on a LIFO stack. Opcodes like `MSTORE` pop their arguments from the stack, so values must be `PUSH`ed in reverse order.

## Runtime Bytecode (10 bytes)

The solver must store `42` in memory and return it:

```
PUSH1 0x2a    → 602a     (push value 42 onto stack)
PUSH1 0x00    → 6000     (push memory offset 0)
MSTORE        → 52       (store 42 at memory[0x00])
PUSH1 0x20    → 6020     (push return length: 32 bytes)
PUSH1 0x00    → 6000     (push return offset: 0)
RETURN        → f3       (return memory[0x00:0x20])
```
**Runtime bytecode:** `602a60005260206000f3` (10 bytes ✓)

## Creation Bytecode (9 bytes)

The creation code must copy the runtime bytecode into memory and return it to the EVM for storage:

```
PUSH10 <runtime>  → 69602a60005260206000f3  (push all 10 runtime bytes)
PUSH1 0x00        → 6000                    (memory offset 0)
MSTORE            → 52                      (store at memory[0]; right-padded in 32-byte word)
PUSH1 0x0a        → 600a                    (return length: 10 bytes)
PUSH1 0x16        → 6016                    (return offset: 22, since 32-10=22)
RETURN            → f3                      (return the runtime bytes)
```
**Creation bytecode:** `69602a60005260206000f3600052600a6016f3` (19 bytes total)

## Exploit

Deploy the raw bytecode via Yul's `create` opcode in a Foundry script, then register the deployed address as the solver:

```solidity
bytes memory code = hex"69602a60005260206000f3600052600a6016f3";
address solver;
assembly {
    solver := create(0, add(code, 0x20), mload(code))
}
// Register via browser console: await contract.setSolver("0x...")
```

## Root Cause

Solidity's compiler adds substantial overhead (metadata, revert strings, function dispatchers) that makes it impossible to meet the 10-byte constraint. The only way is to bypass the compiler entirely and write raw EVM bytecode — demonstrating that Solidity is an abstraction, and the EVM underneath operates on a fundamentally different (and much more compact) instruction set.

## Real-World Reference

Understanding raw EVM bytecode is essential for: analyzing unverified contracts on-chain, building MEV bots that deploy minimal proxy contracts (EIP-1167 clones are 45 bytes of hand-crafted bytecode), reverse-engineering exploit transactions, and writing gas-optimized assembly in protocols like Uniswap V4 (which uses extensive inline assembly for performance-critical paths).
