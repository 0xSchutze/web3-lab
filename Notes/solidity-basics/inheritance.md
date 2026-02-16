# Inheritance

## What It Is

A contract can inherit all functions and state variables from another contract using the `is` keyword. This avoids code duplication.

## Syntax

```solidity
import "./BaseContract.sol";

contract Child is BaseContract {
    // Child has access to all public/internal functions and variables from BaseContract
}
```

## Example

```solidity
// Base contract
contract Animal {
    string public species;

    function setSpecies(string memory _species) public {
        species = _species;
    }
}

// Child contract — inherits everything from Animal
contract Dog is Animal {
    function bark() public pure returns (string memory) {
        return "Woof!";
    }
}
```

`Dog` can call both `bark()` (its own) and `setSpecies()` (inherited from `Animal`).

## Visibility and Inheritance

| Visibility | Accessible in child? |
|------------|---------------------|
| `public` | Yes |
| `internal` | Yes |
| `private` | No — only in the original contract |
| `external` | Only via `this.functionName()` |

## Multiple Inheritance

A contract can inherit from multiple parents:

```solidity
contract Child is Parent1, Parent2 {
    // has access to both Parent1 and Parent2
}
```

## Notes

- Use `import` to bring in the parent contract file
- Inheritance reduces code duplication and makes contracts modular
- Child contracts can **override** parent functions (advanced topic)
