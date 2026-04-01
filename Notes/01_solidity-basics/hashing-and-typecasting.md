# Hashing and Typecasting

## The Pipeline

To convert a string into a random number, three steps are chained together:

| Step | Function | Converts |
|------|----------|----------|
| 1 | `abi.encodePacked()` | string → bytes |
| 2 | `keccak256()` | bytes → bytes32 (hash) |
| 3 | `uint()` | bytes32 → uint (typecasting) |

## All in One Line

```solidity
uint randomNumber = uint(keccak256(abi.encodePacked("solidity")));
```

Execution order (inside out):
1. `abi.encodePacked("solidity")` — converts the string to bytes
2. `keccak256(...)` — hashes the bytes into a fixed 32-byte hash
3. `uint(...)` — typecasts the hash into an unsigned integer

## Use Case

Generating pseudo-random DNA from a name:

```solidity
uint dnaDigits = 16;
uint dnaModulus = 10 ** dnaDigits;

function _generateRandomDna(string memory _name) private view returns (uint) {
    uint rand = uint(keccak256(abi.encodePacked(_name)));
    return rand % dnaModulus;
}
```

## Notes

- `keccak256` is Ethereum's built-in hashing function (SHA-3 family)
- The output looks random but is deterministic — same input always gives the same output
- **Not secure for true randomness** — miners can manipulate it (security concern)
