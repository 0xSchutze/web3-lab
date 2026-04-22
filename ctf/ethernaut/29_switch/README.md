# Level 29: Switch

**Target:** [Switch.sol](./Switch.sol)

## Vulnerability

The `onlyOff` modifier reads the function selector from a hardcoded calldata offset (byte 68) using `calldatacopy`. Because Solidity's dynamic-type ABI encoding allows the offset pointer to be forged, an attacker can place a decoy selector at byte 68 (satisfying the modifier) while the EVM's standard decoder follows the forged pointer to an entirely different payload that actually executes.

## Key Concepts

**ABI Dynamic-Type Encoding**
When a function accepts a `bytes` parameter, the Solidity ABI does not embed the data inline. Instead, the first 32 bytes of the argument area hold an *offset* — a pointer to where the actual byte array begins. The EVM reads the offset and jumps to that position to find the length and contents.

**calldatacopy vs calldataload**
- `calldatacopy(dest, offset, length)` — copies an arbitrary slice of calldata into *memory*. The modifier uses this to extract exactly 4 bytes starting at byte 68.
- `calldataload(offset)` — reads 32 bytes from calldata directly onto the *stack*. It cannot be told to read fewer bytes; the stack slot is always 32 bytes wide.

**Offset Manipulation (Calldata Spoofing)**
By forging the offset to `0x60` (96), the EVM's dynamic-type decoder skips bytes 4–99 entirely and treats byte 100 as the start of the `_data` argument. The modifier's fixed-offset read at byte 68 falls inside the skipped zone — a "dead zone" the attacker controls freely.

**Manual Calldata Assembly**
High-level Solidity calls are disallowed here because the compiler would generate a standards-compliant offset (32) and refuse to accept bytes that bypass `onlyOff`. `abi.encodePacked` with raw types lets the attacker construct an arbitrary byte sequence without ABI validation.

## Root Cause

The `onlyOff` modifier trusts a hardcoded calldata position (byte 68) rather than decoding the argument through the same ABI path that `call(_data)` uses. This split read allows the modifier and the inner `call` to observe different selectors embedded in the same transaction.

## Exploit

Calldata is assembled manually so that two different selectors coexist in one transaction:

| Byte Range | Content | Who reads it |
|------------|---------|-------------|
| 0 – 3 | `flipSwitch(bytes)` selector | EVM router |
| 4 – 35 | Forged offset = `0x60` (96) | EVM dynamic decoder |
| 36 – 67 | Zero padding | Neither |
| 68 – 99 | `turnSwitchOff()` selector | `onlyOff` modifier |
| 100 – 131 | Length = 4 | EVM dynamic decoder |
| 132 – 163 | `turnSwitchOn()` selector | `address(this).call(_data)` |

```solidity
bytes memory callData = abi.encodePacked(
    bytes4(keccak256("flipSwitch(bytes)")),        // selector
    uint256(96),                                   // forged offset
    uint256(0),                                    // dead zone padding
    bytes32(bytes4(keccak256("turnSwitchOff()"))), // modifier trap
    uint256(4),                                    // real data length
    bytes4(keccak256("turnSwitchOn()"))            // real payload
);
target.call(callData);
```

The modifier reads `turnSwitchOff` at byte 68 and passes. The inner `call(_data)` follows the offset to byte 100, reads 4 bytes of payload, and executes `turnSwitchOn`.

## Real-World Reference

Calldata spoofing / ABI offset manipulation is the same class of vulnerability that underpins several cross-chain bridge exploits, where `bytes`-typed message payloads were validated at one offset but decoded at another, allowing attackers to pass a legitimate-looking header while embedding a malicious inner call. The Nomad Bridge exploit (August 2022, ~$190M) involved a related pattern of trusting unvalidated message roots that could be replayed with arbitrary payloads.
