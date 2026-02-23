# msg Global Variable

`msg` is a built-in global variable that contains information about the current transaction.

## msg.sender

The address that **directly called** this function. Used for ownership and access control.

```solidity
require(msg.sender == owner, "Not owner");
```

For detailed notes: [msg.sender](./msg.sender.md) | [msg.sender vs tx.origin](./msg.sender-and-tx.origin.md)

## msg.value

The amount of **ETH sent** with the current function call (in wei). Only available inside `payable` functions.

```solidity
function buy() external payable {
    require(msg.value >= 0.01 ether, "Not enough ETH");
}
```

> [!WARNING]
> `msg.value` is NOT the caller's total balance — it's only the amount they sent with this specific transaction.

## Other msg properties

| Property | Type | What It Is |
|----------|------|-----------|
| `msg.sender` | `address` | Who called the function |
| `msg.value` | `uint` | ETH sent with the call (in wei) |
| `msg.data` | `bytes` | The full calldata (advanced) |