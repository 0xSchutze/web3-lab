# msg Global Variable

`msg` is a built-in global variable that contains information about the current transaction.

| Property | Type | What It Is |
|----------|------|-----------|
| `msg.sender` | `address` | Who called the function |
| `msg.value` | `uint` | ETH sent with the call (in wei) |
| `msg.data` | `bytes` | The full calldata (advanced) |

## msg.sender

The address that **directly called** this function. It can be:
- An **EOA** (Externally Owned Account) — a personal wallet
- A **contract address** — another smart contract

### Ownership and Access Control

```solidity
mapping(address => uint) public balances;

function deposit(uint _amount) public {
    balances[msg.sender] = _amount;
}
```

```solidity
mapping(uint => address) public itemOwner;
mapping(address => uint) public ownerItemCount;

function createItem(uint _id) public {
    itemOwner[_id] = msg.sender;
    ownerItemCount[msg.sender]++;
}
```

### Security Note

- If Contract A calls Contract B, then inside B `msg.sender` = Contract A's address (not the original user)
- For the difference with `tx.origin` and why it matters for security: [msg.sender vs tx.origin](./msg.sender-and-tx.origin.md)

## msg.value

The amount of **ETH sent** with the current function call (in wei). Only available inside `payable` functions.

```solidity
function buy() external payable {
    require(msg.value >= 0.01 ether, "Not enough ETH");
}
```

> [!WARNING]
> `msg.value` is NOT the caller's total balance — it's only the amount they sent with this specific transaction.