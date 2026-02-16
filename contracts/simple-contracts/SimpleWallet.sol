// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title SimpleWallet — A basic wallet contract for learning Solidity
/// @notice Covers: struct, mapping, array, require, events, keccak256, view

contract SimpleWallet {
    uint idModulus = 10 ** 12;

    // Custom data type to store account info
    struct Account {
        string name;
        uint balance;
    }

    // Events — notify frontend when something happens
    event AccountCreated(
        uint accountId,
        string accountName,
        address accountAddress
    );
    event Deposited(address account, uint amount);
    event Withdrawn(address account, uint amount);

    // Mappings — link addresses to data
    mapping(address => uint) public addressToId;
    mapping(address => uint) public accountCount;

    // Array — stores all accounts
    Account[] public accounts;

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
        require(accountCount[msg.sender] == 0, "You already have an account");

        uint id = _generateRandomId(_name);
        accounts.push(Account(_name, 0));
        addressToId[msg.sender] = id;
        accountCount[msg.sender]++;

        emit AccountCreated(id, _name, msg.sender);
    }

    // Add funds to your account
    function deposit(uint _amount) public {
        require(accountCount[msg.sender] > 0, "No account found");
        require(_amount > 0, "Amount must be positive");

        uint index = accountCount[msg.sender] - 1;
        accounts[index].balance += _amount;

        emit Deposited(msg.sender, _amount);
    }

    // Withdraw funds from your account
    function withdraw(uint _amount) public {
        require(accountCount[msg.sender] > 0, "No account found");

        uint index = accountCount[msg.sender] - 1;
        require(accounts[index].balance >= _amount, "Not enough balance");

        accounts[index].balance -= _amount;

        emit Withdrawn(msg.sender, _amount);
    }

    // Check your current balance — view only, no gas cost
    function getBalance() public view returns (uint) {
        require(accountCount[msg.sender] > 0, "No account found");

        uint index = accountCount[msg.sender] - 1;
        return accounts[index].balance;
    }
}
