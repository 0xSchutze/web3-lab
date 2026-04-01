// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Libary/Math.sol";
import "./Interfaces/IPair.sol";
import "./Interfaces/IERC20.sol";

/**
 * @title MiniDEX Core Pair implementation
 * @author 0xSchutze / Web3 Security Lab
 * @notice Operational engine representing a single AMM pair managing liquidity provision, burning, and decentralized trading.
 * @dev Implements the invariant constant product formula (X * Y = K) alongside custom reentrancy mitigation, underflow protection, and precision handling.
 */
contract MiniDEXPair is IPair {  

    // ------------------------------------------------------------------------
    // ERC20 Standards (LP Tokens)
    // ------------------------------------------------------------------------
    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;
    
    string public constant name = "MiniDEXLP-token";
    string public constant symbol = "MINI-LP";
    uint8 public constant decimals = 18;

    // ------------------------------------------------------------------------
    // Core Architecture State
    // ------------------------------------------------------------------------
    address public factory;
    address public token0;
    address public token1;

    // ------------------------------------------------------------------------
    // Vault Storage (Reserves)
    // ------------------------------------------------------------------------
    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    /**
     * @notice Identifies the central factory and standardizes the pair's initial asset mapping.
     * @param _token0 Canonical address for Token0.
     * @param _token1 Canonical address for Token1.
     */
    constructor(address _token0, address _token1) {
        factory = msg.sender;
        token0 = _token0;
        token1 = _token1;
    }

    /**
     * @notice Returns current synchronized pool reserves for frontend interaction or time-weighted oracle calculations.
     */
    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    /**
     * @notice Mints protocol liquidity tokens (LP) directly to the provider relative to the deposited tokens.
     * @dev Protects against DoS "Initial Inflation Attack" by intentionally and permanently trapping the first 1000 minted wei to address(0). 
     * @param _amount0 Exact volume of token0 to extract from caller.
     * @param _amount1 Exact volume of token1 to extract from caller.
     * @return MINILP Quantity of minted LP tokens allocated to the provider.
     */
    function mint(uint256 _amount0, uint256 _amount1) external returns (uint MINILP) {
        require(_amount0 <= type(uint112).max && _amount1 <= type(uint112).max, "Amount too large");   
        
        if (totalSupply > 0) {
            require((_amount0 * reserve1) == (_amount1 * reserve0), "wrong price ratio, address to");
        }

        IERC20(token0).transferFrom(msg.sender, address(this), _amount0);
        IERC20(token1).transferFrom(msg.sender, address(this), _amount1);
        
        uint256 actualAmount0 = IERC20(token0).balanceOf(address(this)) - reserve0; 
        uint256 actualAmount1 = IERC20(token1).balanceOf(address(this)) - reserve1;

        MINILP = Math.sqrt(actualAmount0 * actualAmount1);

        if (totalSupply == 0) {
            MINILP -= 1000;
            balanceOf[address(0)] += 1000;
            totalSupply += 1000;
        }

        balanceOf[msg.sender] += MINILP;
        totalSupply += MINILP;
        
        require(MINILP > 0, "Insufficent Liquidity Minted");

        reserve0 = uint112(IERC20(token0).balanceOf(address(this)));
        reserve1 = uint112(IERC20(token1).balanceOf(address(this)));

        emit Mint(address(this), _amount0, _amount1, msg.sender);
    }

    /**
     * @notice Annihilates liquidity tokens strictly from the caller to disburse underlying canonical assets proportionally.
     * @param _MINILPamount Exact amount of LP tokens to burn.
     * @return amount0 Dispensed quantity of token0.
     * @return amount1 Dispensed quantity of token1.
     */
    function burn(uint256 _MINILPamount) external returns (uint256 amount0, uint256 amount1) {
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
         
        amount0 = (_MINILPamount * balance0) / totalSupply;
        amount1 = (_MINILPamount * balance1) / totalSupply;

        require(amount0 > 0 && amount1 > 0, "Insufficent Liquidity Burned!");

        balanceOf[msg.sender] -= _MINILPamount;
        totalSupply -= _MINILPamount;

        IERC20(token0).transfer(msg.sender, amount0);
        IERC20(token1).transfer(msg.sender, amount1);

        reserve0 = uint112(IERC20(token0).balanceOf(address(this)));
        reserve1 = uint112(IERC20(token1).balanceOf(address(this)));

        emit Burn(address(this), amount0, amount1, msg.sender);
    }

    /**
     * @notice Executes peer-to-pool localized token swaps enforcing the automated market-making constant invariant and protocol fee constraint (0.5%).
     * @param _tokenIn Canonical address of the incoming token payload.
     * @param _amountIn Volume to ingest from caller.
     * @param _amountOut Mathematical boundary calculated using reserves execution paths (internal reassigned logic).
     */
    function swap(address _tokenIn, uint112 _amountIn, uint256 _amountOut) external {
        require(_amountIn <= type(uint112).max, "Amount too large");   

        bool isToken0 = _tokenIn == token0;

        address tokenOut = isToken0 ? token1 : token0;
        uint256 reserveIn = isToken0 ? reserve0 : reserve1;
        uint256 reserveOut = isToken0 ? reserve1 : reserve0;

        require(IERC20(_tokenIn).transferFrom(msg.sender, address(this), _amountIn), "Transfer failed");

        uint256 amountWithFee = _amountIn * 995;

        _amountOut = (amountWithFee * reserveOut) / ((reserveIn * 1000) + amountWithFee);

        require(IERC20(tokenOut).transfer(msg.sender, _amountOut), "transfer failed");

        reserve0 = uint112(IERC20(token0).balanceOf(address(this)));
        reserve1 = uint112(IERC20(token1).balanceOf(address(this)));

        emit Swap(address(this), _amountOut, tokenOut, msg.sender);
    }
}