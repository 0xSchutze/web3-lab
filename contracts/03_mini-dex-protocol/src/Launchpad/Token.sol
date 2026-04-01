// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.20;

/**
 * @title Mock ERC20 Token
 * @author 0xSchutze / Web3 Security Lab
 * @notice A minimal, standard ERC20 implementation for testing and launchpad distribution.
 * @dev Implements transfer, approve, and transferFrom with rigid balance/allowance checks. No flash-mint features.
 */
contract Token {

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;

    /**
     * @notice Initializes the token and mints the entire payload to the creator.
     * @param _name Token Name.
     * @param _symbol Token Symbol.
     * @param _totalSupply The total supply to mint initially.
     * @param _to The destination address for the minted supply.
     */
    constructor(string memory _name, string memory _symbol, uint256 _totalSupply, address _to) {
        require(_totalSupply <= 1e12 * 1e18, "Token: Supply exceeds 1 Trillion cap");
        name = _name;
        symbol = _symbol;
        totalSupply = _totalSupply;
        balanceOf[_to] += totalSupply;
    }

    /**
     * @notice Transfers standard ERC20 tokens from the caller to another destination.
     * @param to Destination address.
     * @param amount Amount of tokens to transfer in Wei logic.
     * @return Returns true upon successful transfer.
     */
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Token: Not have enough balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    /**
     * @notice Approves a router or spender to extract a specific amount of tokens from the caller.
     * @param spender The address authorized to spend.
     * @param amount The allowance threshold.
     * @return Returns true upon confirmation.
     */
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    /**
     * @notice Forcefully routes tokens from a specified address to another address relying on exact allowance authorization.
     * @param from The address to deduct tokens from.
     * @param to The address to receive the tokens.
     * @param amount The computational amount to transfer.
     * @return Returns true upon successful completion.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(allowance[from][msg.sender] >= amount, "Token: insufficient allowance");
        require(balanceOf[from] >= amount, "Token: transfer amount exceeds balance");
        
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}