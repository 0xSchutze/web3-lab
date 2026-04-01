# Events and Emit

## What They Are

Events allow a smart contract to send signals to the frontend (or any external listener). They are logged on the blockchain but cannot be read by other contracts.

## Defining an Event

```solidity
event Transfer(address indexed from, address indexed to, uint amount);
```

## Emitting an Event

```solidity
function transfer(address _to, uint _amount) public {
    balances[msg.sender] -= _amount;
    balances[_to] += _amount;

    emit Transfer(msg.sender, _to, _amount);
}
```

## Listening from Frontend

Using ethers.js or web3.js, the frontend can subscribe to events:

```javascript
contract.on("Transfer", (from, to, amount) => {
    console.log(`${from} sent ${amount} to ${to}`);
});
```

## Notes

- Events are **cheap** compared to storing data in state variables
- `indexed` parameters (max 3) can be filtered/searched by the frontend
- Events cannot be read from within a contract — they are for external use only
- Common use cases: logging transfers, notifying UI of state changes, creating activity feeds
