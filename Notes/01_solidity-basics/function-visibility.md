# Visibility Modifiers

Controls who can call a function or access a variable.

| Modifier | Contract itself | Child contracts (`is`) | Users / Other contracts |
|----------|:-:|:-:|:-:|
| **private** | ✅ | ❌ | ❌ |
| **internal** | ✅ | ✅ | ❌ |
| **public** | ✅ | ✅ | ✅ |
| **external** | ❌ | ❌ | ✅ |

## When to Use

- **`private`** — helper functions that only this contract needs
- **`internal`** — functions that child contracts should also use
- **`public`** — functions that anyone can call (inside + outside)
- **`external`** — functions only called from outside (cheaper gas than public)

## Example

```solidity
function _calculateFee(uint amount) private returns (uint) { }   // only this contract
function _updateBalance(address user) internal { }                // this + child contracts
function deposit() public payable { }                             // everyone
function getBalance() external view returns (uint) { }            // only outside calls
```

## Notes

- In Solidity 0.5.0+, visibility is **required** for all functions (compiler error if missing)
- State variables default to `internal` if not specified
- `external` is slightly cheaper than `public` because it doesn't copy arguments to memory
