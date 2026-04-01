# Interface

### How can you interact with other contracts?

**1. Import a contract you already have locally:**
```solidity
import "./MyContract.sol";
```

**2. Interact with a deployed contract on the blockchain using an interface:**

```solidity
// Define what functions you need from the external contract
contract KittyInterface {
    function getKitty(uint256 _id) external view returns (uint256 genes);
}

// Set the contract address
address ckAddress = 0x06012c8cf97BEaD5deAe237070F9587f8E7A266d;

// Create a reference to the external contract
KittyInterface kittyContract = KittyInterface(ckAddress);

// Now you can call functions on it
kittyContract.getKitty(42);
```

### Import vs Inherit (is)

| | `import` only | `import` + `is` |
|--|--------------|-----------------|
| What | Makes the file available | Inherits all functions/variables |
| Use | Call it as a separate contract | Use its functions as your own |
| Modify | Cannot change its functions | Can override functions |

### Security Note

> [!WARNING]
> Hardcoding a contract address is risky — if that contract has a bug, you can't update the address.

Solution: use an `onlyOwner` function to update the address:

```solidity
KittyInterface kittyContract;

function setKittyContractAddress(address _address) external onlyOwner {
    kittyContract = KittyInterface(_address);
}
```

For more on constructor and modifier: [constructor-and-modifier](./constructor-and-modifer.md)
