// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.20;

import "./Token.sol";

/**
 * @title Launchpad
 * @author 0xSchutze / Web3 Security Lab
 * @notice A permissionless token factory for deploying fair-launch ERC20 tokens.
 * @dev Deploys the `Token` contract and assigns total supply securely to the msg.sender.
 */
contract Launchpad {

    /**
     * @notice Emitted upon successful fair-launch deployment of a new token.
     * @param tokenAddress The freshly generated EVM contract address.
     * @param name The immutable name string of the asset.
     * @param symbol The ticker designation.
     * @param totalSupply The max minted supply allocated exactly at block zero.
     * @param creator The msg.sender initializing the pipeline.
     */
    event TokenCreated(
        address indexed tokenAddress, 
        string name, 
        string symbol, 
        uint256 totalSupply, 
        address indexed creator
    );

    /**
     * @notice Deploys a new ERC20 token with a fixed supply cap.
     * @param _name The name of the token.
     * @param _symbol The symbol of the token.
     * @param _totalSupply The total supply of the token (max 1 Trillion).
     * @return newTokenAddress The address of the deployed token contract.
     */
    function createToken(string memory _name, string memory _symbol, uint256 _totalSupply) external returns (address newTokenAddress) {
        require(_totalSupply <= 1e12 * 1e18, "Launchpad: Supply exceeds 1 Trillion cap");
        newTokenAddress = address(new Token(_name, _symbol, _totalSupply, msg.sender));
        emit TokenCreated(newTokenAddress, _name, _symbol, _totalSupply, msg.sender);
    }
}