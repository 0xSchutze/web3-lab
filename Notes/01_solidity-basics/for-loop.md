# For Loop

A for loop repeats code a set number of times. It has 3 parts:

```solidity
for (uint i = 0; i < 5; i++) {
//   ↑ START      ↑ CONDITION  ↑ INCREMENT
//   set counter  keep going?  move to next
}
```

- **`i`** = just a counter variable (could be named anything)
- **`i++`** = add 1 to the counter after each round
- Without `i++` the loop runs forever (infinite loop)

## Example — Find a User's Zombies

```solidity
function getZombiesByOwner(address _owner) external view returns (uint[] memory) {
    uint[] memory result = new uint[](ownerZombieCount[_owner]);
    uint counter = 0;

    for (uint i = 0; i < zombies.length; i++) {
        if (zombieToOwner[i] == _owner) {
            result[counter] = i;
            counter++;
        }
    }
    return result;
}
```

Two counters work together:
- `i` → scans ALL zombies (0, 1, 2, 3...)
- `counter` → tracks position in the result array (only increments on match)

## Notes

- For loops are used for any repetitive task, not just array scanning
- In `view` functions, for loops cost **no gas** when called externally
- Be careful with large arrays — looping through millions of items is slow
