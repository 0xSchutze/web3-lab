# Arrays and Push

## Array vs Struct

- `struct` — defines the shape of your data (like a table schema)
- `array` — stores multiple instances of that data (like rows in a table)

## Defining a Struct

```solidity
struct Person {
    string name;
    uint age;
}
```

This creates a data structure like:

| name (string) | age (uint) |
|----------------|------------|
|                |            |

## Creating an Array

```solidity
// Person[] → array of Person structs
// public → anyone can read it
// persons → the variable name
Person[] public persons;
```

## Adding Data with Push

```solidity
function _addPerson(string memory _name, uint _age) private {
    persons.push(Person(_name, _age));
}
```

After calling `_addPerson("Jackson", 24)`:

| name (string) | age (uint) |
|----------------|------------|
| Jackson        | 24         |

## Notes

- `memory` — required for string parameters, keeps data temporary (like RAM)
- `private` — only this contract can call this function
- `push` — appends a new entry to the end of the array
- `_name` — underscore prefix is a naming convention for function parameters

## Gas and Struct Packing

**Gas** is the fee you pay for every operation on the blockchain. More storage = more gas = more money. So we optimize structs to use less storage.

Smaller uint types (`uint32`, `uint16`) save gas **only inside structs** — group them together so Solidity packs them into one storage slot:

```solidity
// ✅ Packed — uint32s are next to each other, fits in one slot
struct Efficient {
    uint32 a;
    uint32 b;
    uint c;
}

// ❌ Not packed — uint32s are separated, wastes storage slots
struct Wasteful {
    uint32 a;
    uint c;       // breaks the packing
    uint32 b;
}
```

> [!NOTE]
> Outside structs, `uint32` costs the **same gas** as `uint256`. Only use smaller types inside structs for optimization.