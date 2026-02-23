# Payable

## What It Is

`payable` is a function modifier that allows a function to receive ETH. If someone tries to send ETH to a function without `payable`, the transaction reverts.

## Receiving ETH — payable function

```solidity
function buySomething() external payable {
    require(msg.value == 0.001 ether, "Must send exactly 0.001 ETH");
    // logic here
}
```

- `msg.value` — the amount of ETH sent with the function call
- `ether` — built-in unit (1 ether = 10^18 wei)

## Sending ETH — address payable + call

To send ETH to an address, that address must be `address payable`:

```solidity
// Convert address to payable and send ETH
(bool success, ) = payable(msg.sender).call{value: 0.001 ether}("");
require(success, "Transfer failed");
```

> [!WARNING]
> `.transfer()` is deprecated — it has a fixed 2300 gas limit that can cause failures. Always use `.call{value:}` instead.

## Withdraw Pattern

A common pattern for letting the owner withdraw all ETH from the contract:

```solidity
function withdraw() external onlyOwner {
    uint amount = address(this).balance;
    require(amount > 0, "Nothing to withdraw");

    (bool success, ) = payable(_owner).call{value: amount}("");
    require(success, "Transfer failed");
}
```

- `address(this)` — the contract's own address
- `address(this).balance` — total ETH stored in the contract
- `.call{value: amount}("")` — sends ETH (modern, safe method)
- `(bool success, )` — check if the transfer worked

## Notes

- A function **without** `payable` rejects any ETH sent to it
- `address` cannot receive ETH — only `address payable` can
- `msg.value` is only available inside `payable` functions
- Use `.call{value:}` instead of `.transfer()` for sending ETH
