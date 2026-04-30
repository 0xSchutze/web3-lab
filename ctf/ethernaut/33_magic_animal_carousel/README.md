# Level 33: MagicAnimalCarousel

**Target:** [MagicAnimalCarousel.sol](./MagicAnimalCarousel.sol)
**Exploit:** [exploitScript.s.sol](./exploitScript.s.sol)

## Vulnerability
The contract packs multiple data fields (animalName, nextCrateId, owner) into a single `uint256` variable. However, in the `changeAnimal` function, the 96-bit data returned by `encodeAnimalName` is directly shifted left (`<< 160`) without enforcing size constraints. This causes the data to overflow into the `NEXT_ID_MASK` (bits 160-175) region, allowing the `nextCrateId` value to be manipulated.

## Key Concepts
- **Data Packing / Bitwise Operations:** Storing multiple variables (`uint80`, `uint16`, `uint160`) in a single 256-bit slot using bit shifting (`<<`, `>>`) and masking (`&`, `|`) operators.
- **Bitwise Overflow / Overlap:** Due to incorrect masking or insufficient size validation, the bits of one variable overflow onto adjacent bits in memory, overwriting them (exploiting the bitwise OR operator).
- **Modulo Arithmetic Loop:** Manipulating the `% MAX_CAPACITY` operation—used to loop back to the beginning when max capacity is reached—to redirect the system to a desired ID (such as crate 1).

## Root Cause
The `changeAnimal` function does not truncate the size of the provided animal name when packing it (unlike `setAnimalAndSpin`, which truncates it via `>> 16`). Because of this, when a 12-byte (96-bit) string is passed, the last 2 bytes directly cover the `NEXT_ID` region. Since a bitwise OR (`|`) is used, the attacker can overwrite the next crate ID to a value of their choosing.

## Exploit
The goal of the attack is to redirect the "Goat" animal (added by the system during the validation phase) into a crate we control that is already occupied, rather than an empty crate, forcing a mutation via `XOR`:

1. Call `setAnimalAndSpin("Panther")` to initialize and fill crate 1. The system sets `currentCrateId` to 1, and the `nextCrateId` for crate 1 becomes 2.
2. Call `changeAnimal` with a specially crafted 12-byte payload: `[10 bytes text] + [0xFFFF]`. This overwrites crate 1's `nextCrateId` with `0xFFFF` (65535).
3. Call `setAnimalAndSpin("Tiger")` again. The system writes "Tiger" into crate 65535. The critical breaking point lies in the formula: `(65535 + 1) % 65535 = 1`. This modulo math forces crate 65535's target to loop back to **crate 1**.
4. When the instance is "Submitted", the system attempts to add the "Goat". Since crate 65535's target is 1, it places the Goat into crate 1. However, crate 1 is already occupied. The `"Panther" ^ "Goat"` collision occurs, and the goat is mutated.

## Real-World Reference
Bitwise data packing vulnerabilities often occur in projects heavily focused on gas optimization. Projects like **BadgerDAO** and **SushiSwap** have experienced bit-shifting errors in the past (especially incorrect masking during token decimal calculations). This vulnerability pattern is a major risk for any contract that manually handles memory management at the EVM level (particularly in on-chain NFT metadata rendering).
