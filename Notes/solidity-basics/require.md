# Require

## What It Is

A guard statement that checks a condition before executing the rest of the function. If the condition is `false`, the transaction reverts and all changes are undone.

## Syntax

```solidity
require(condition, "Error message");
```

## Examples

Only allow one item per user:

```solidity
function createItem(string memory _name) public {
    require(ownerItemCount[msg.sender] == 0, "You already have an item");
    // rest of the function only runs if condition is true
}
```

Only allow the owner to call a function:

```solidity
function withdraw() public {
    require(msg.sender == owner, "Not the owner");
    // withdraw logic
}
```

Validate input:

```solidity
function setAge(uint _age) public {
    require(_age > 0, "Age must be positive");
    require(_age < 150, "Invalid age");
    age = _age;
}
```

## Notes

- If `require` fails, the transaction **reverts** — no state changes are saved
- Gas spent up to that point is **lost** (not refunded)
- The error message string is optional but recommended for debugging
- Used for input validation, access control, and state checks

## == vs =

| Operator | Meaning | Example |
|----------|---------|---------|
| `=` | Assignment (set a value) | `score = 10;` |
| `==` | Comparison (check if equal) | `require(score == 10);` |

`require` always uses `==` (comparison), never `=` (assignment).
