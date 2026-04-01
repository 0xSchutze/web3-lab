# Time Units

Solidity has built-in time units that convert to seconds:

```solidity
1 seconds == 1
1 minutes == 60
1 hours   == 3600
1 days    == 86400
1 weeks   == 604800
```

## Usage — Cooldown Example

```solidity
uint cooldownTime = 1 days;
uint lastAction;

function doSomething() public {
    require(block.timestamp >= lastAction + cooldownTime, "Wait 24 hours");
    lastAction = block.timestamp;
    // rest of the logic
}
```

## Notes

- `block.timestamp` returns the current block's time in seconds (Unix timestamp)
- Time units are just syntactic sugar — `1 days` is the same as writing `86400`
- Useful for cooldowns, vesting schedules, and time-locked functions
- `now` was an alias for `block.timestamp` but is deprecated in Solidity 0.7+
