// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Staking Token
/// @author 0xSchutze
/// @notice A standard ERC20 token implementation used as the staking asset
contract StakingToken {
    string public name = "Staking-Token";
    string public symbol = "STK";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor() {
        totalSupply = 10000000 * 1e18;
        balanceOf[msg.sender] = totalSupply;
    }

    /// @notice Transfers tokens from caller to a receiver
    /// @param to The address of the receiver
    /// @param amount The amount of tokens to transfer
    /// @return success Returns true if the operation succeeds
    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    /// @notice Transfers tokens on behalf of a user
    /// @param from The address holding the tokens
    /// @param to The receiver address
    /// @param amount The amount of tokens to transfer
    /// @return success Returns true if the operation succeeds
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(amount <= allowance[from][msg.sender], "Insufficient allowance");
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    /// @notice Approves a spender to use the caller's tokens
    /// @param spender The address of the approved spender
    /// @param amount The amount of tokens approved
    /// @return success Returns true if the operation succeeds
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
}
