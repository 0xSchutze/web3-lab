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