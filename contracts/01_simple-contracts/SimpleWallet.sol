// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title SimpleWallet — A basic wallet contract for learning Solidity
/// @notice Covers: struct, mapping, require, events, keccak256, view

contract SimpleWallet {
    uint idModulus = 10 ** 12;

    // Custom data type to store account info
    struct Account {
        string name;
        uint balance;
        bool exists;
    }

    // Events — notify frontend when something happens
    event AccountCreated(
        uint accountId,
        string accountName,
        address accountAddress
    );
    event Deposited(address account, uint amount);
    event Withdrawn(address account, uint amount);

    // Mapping — each address maps directly to its own Account
    mapping(address => Account) public accounts;
    mapping(address => uint) public addressToId;

    // Generate a pseudo-random ID from name + caller + timestamp
    function _generateRandomId(
        string memory _name
    ) private view returns (uint) {
        uint rand = uint(
            keccak256(abi.encodePacked(_name, msg.sender, block.timestamp))
        );
        return rand % idModulus;
    }

    // Create a new account — only one per address allowed
    function createAccount(string memory _name) public {
        require(!accounts[msg.sender].exists, "You already have an account");

        uint id = _generateRandomId(_name);
        accounts[msg.sender] = Account(_name, 0, true);
        addressToId[msg.sender] = id;

        emit AccountCreated(id, _name, msg.sender);
    }

    // Add funds to your account
    function deposit(uint _amount) public {
        require(accounts[msg.sender].exists, "No account found");
        require(_amount > 0, "Amount must be positive");

        accounts[msg.sender].balance += _amount;

        emit Deposited(msg.sender, _amount);
    }

    // Withdraw funds from your account
    function withdraw(uint _amount) public {
        require(accounts[msg.sender].exists, "No account found");
        require(accounts[msg.sender].balance >= _amount, "Not enough balance");

        accounts[msg.sender].balance -= _amount;

        emit Withdrawn(msg.sender, _amount);
    }

    // Check your current balance — view only, no gas cost
    function getBalance() public view returns (uint) {
        require(accounts[msg.sender].exists, "No account found");
        return accounts[msg.sender].balance;
    }
}
