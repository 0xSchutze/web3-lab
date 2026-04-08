// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/// @title MockERC20
/// @notice Minimal ERC20 token implementation for testing and local simulation only.
/// @dev Not audited. Not intended for production use.
contract MockERC20 {

    string public name     = "MockToken";
    string public symbol   = "MCK";
    uint8  public decimals = 18;
    uint256 public totalSupply;

    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => uint256) public balanceOf;

    /// @notice Transfers `amount` tokens from the caller to `to`.
    /// @param to Recipient address.
    /// @param amount Number of tokens to transfer.
    function transfer(address to, uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "MockERC20: insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
    }

    /// @notice Transfers `amount` tokens from `from` to `to` using the caller's allowance.
    /// @param from Source address.
    /// @param to Recipient address.
    /// @param amount Number of tokens to transfer.
    function transferFrom(address from, address to, uint256 amount) external {
        require(balanceOf[from] >= amount, "MockERC20: insufficient balance");
        require(allowance[from][msg.sender] >= amount, "MockERC20: insufficient allowance");
        balanceOf[from] -= amount;
        allowance[from][msg.sender] -= amount;
        balanceOf[to] += amount;
    }

    /// @notice Approves `spender` to spend up to `amount` tokens on behalf of the caller.
    /// @param spender Address authorized to spend.
    /// @param amount Maximum amount the spender may use.
    function approve(address spender, uint256 amount) external {
        allowance[msg.sender][spender] = amount;
    }

    /// @notice Mints `amount` new tokens to `to`. For test setup only.
    /// @param to Recipient address.
    /// @param amount Number of tokens to mint.
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }
}