// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Interfaces/IFactory.sol";
import "./Mini-DEX-Pair.sol";

/**
 * @title MiniDEX Factory Engine
 * @author 0xSchutze / Web3 Security Lab
 * @notice Permissionless factory for deploying stateless and secure Decentralized Exchange Pairs.
 * @dev Manages the canonical tracking and indexing of all deployed pair instances preventing duplicate storage.
 */
contract MiniDEXFactory is IFactory {

    address public feeTo;
    address public feeToSetter;
    address[] public allPairs;

    mapping(address => mapping(address => address)) public getPair;

    /**
     * @notice Initializes the central DEX factory.
     * @param _feeToSetter The address with authorization to configure protocol-wide fee settings.
     */
    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    /**
     * @notice Registers and deploys a new isolated liquidity pair contract if it does not already exist.
     * @dev Ensures token addresses are unique and sorted deterministically (token0 < token1) to prevent duplicate or phantom pools.
     * @param tokenA The first canonical ERC20 token address.
     * @param tokenB The second canonical ERC20 token address.
     * @return pair The deployed proxy address of the new MiniDEXPair instance.
     */
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, "cant use same tokens");
        
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "token cant be zero address");
        require(getPair[token0][token1] == address(0), "pair exists");

        pair = address(new MiniDEXPair(token0, token1));

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);
        
        emit PairCreated(token0, token1, pair, allPairs.length);

        return pair;
    }
}
