// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;


interface IPair {

    event Mint(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(address indexed sender, uint _amountOut, address indexed tokenOut, address indexed to );

    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast);
    function mint(uint256 _amount0, uint256 _amount1) external returns (uint MINILP);
    function burn(uint256 _MINILPamount) external  returns (uint256 amount0, uint256 amount1);
    function swap(address _tokenIn, uint112 _amountIn, uint256 amountOut) external;
}