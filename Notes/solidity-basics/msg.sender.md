# msg.sender

## What It Is

`msg.sender` is the address that called the current function. It can be:
- An **EOA** (Externally Owned Account) — a personal wallet
- A **contract address** — another smart contract

## Usage

Assigning ownership of data to the caller:

```solidity
mapping(address => uint) public balances;

function deposit(uint _amount) public {
    balances[msg.sender] = _amount;
}
```

Using it with mapping for access control:

```solidity
mapping(uint => address) public itemOwner;
mapping(address => uint) public ownerItemCount;

function createItem(uint _id) public {
    itemOwner[_id] = msg.sender;
    ownerItemCount[msg.sender]++;
}
```

## Security Note

- `msg.sender` changes depending on who calls the function
- If Contract A calls Contract B, then inside Contract B `msg.sender` = Contract A's address (not the original user)
- `tx.origin` always refers to the original wallet — but using it for authorization is a known vulnerability (phishing attacks)

## msg.sender vs tx.origin

| | `msg.sender` | `tx.origin` |
|--|-------------|-------------|
| What | Direct caller | Original wallet |
| Can be a contract? | Yes | No (always EOA) |
| Safe for auth? | Yes | No (vulnerable to phishing) |
