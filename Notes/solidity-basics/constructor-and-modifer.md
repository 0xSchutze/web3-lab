# Constructor and Modifier

### Constructor

Runs **once** when the contract is deployed. Cannot be called again.

Common use: setting the contract owner.

```solidity
constructor() {
    _owner = msg.sender;
    emit OwnershipTransferred(address(0), _owner);
}
```

This code runs at deployment — whoever deploys becomes the owner. After that, only the owner can transfer ownership.

### Modifier

Runs **every time** a function is called. Acts as a guard/check before the function body.

```solidity
modifier onlyOwner() {
    require(msg.sender == _owner, "Not owner");
    _;  // ← "now run the actual function"
}
```

`_;` means: "if the require passes, execute the rest of the function."

### Key Difference

| | Constructor | Modifier |
|--|------------|----------|
| When | Once, at deploy | Every function call |
| Purpose | Setup / initialize | Guard / access control |
| Reusable | No | Yes, add to any function |

For the full Ownable contract example: [simpleOwnable](../../contracts/simple-contracts/simpleOwnable.sol)