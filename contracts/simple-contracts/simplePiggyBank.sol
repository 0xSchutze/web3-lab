// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title SimplePiggyBank — a shared piggy bank contract
/// @notice Covers: payable, msg.value, withdraw pattern, address(this).balance, transfer

contract SimplePiggyBank {
    address private _owner;

    // Track how much each address deposited
    mapping(address => uint) public deposits;

    // Track total number of depositors
    uint public depositorCount;

    // Events
    event Deposited(address indexed depositor, uint amount);
    event Withdrawn(address indexed owner, uint amount);

    // Set deployer as owner
    constructor() {
        _owner = msg.sender;
    }

    // Check if caller is owner
    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    // Only owner can call
    modifier onlyOwner() {
        require(isOwner(), "Not the owner");
        _;
    }

    // Anyone can deposit ETH — minimum 0.001 ether
    function deposit() external payable {
        require(msg.value >= 0.001 ether, "Minimum 0.001 ETH");

        // Track first-time depositors
        if (deposits[msg.sender] == 0) {
            depositorCount++;
        }

        deposits[msg.sender] += msg.value;

        emit Deposited(msg.sender, msg.value);
    }

    // Only owner can break the piggy bank and withdraw all ETH
    function withdraw() external onlyOwner {
        uint amount = address(this).balance;
        require(amount > 0, "Nothing to withdraw");

        (bool success, ) = payable(_owner).call{value: amount}("");
        require(success, "Transfer failed");

        emit Withdrawn(_owner, amount);
    }

    // View total ETH in the piggy bank
    function getBalance() external view returns (uint) {
        return address(this).balance;
    }

    // View how much you deposited
    function getMyDeposit() external view returns (uint) {
        return deposits[msg.sender];
    }
}
