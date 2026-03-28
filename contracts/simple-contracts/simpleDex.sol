// SPDX-License-Identifier: MIT  

pragma solidity ^0.8.20;


import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";


contract SimpleDex is ERC20 {
    IERC20 public immutable balanceToken;
    IERC20 public immutable newToken;
    uint256 public reserveBalanceToken;
    uint256 public reserveNewToken;

    constructor(address _balanceToken, address _newToken) ERC20("MiniDEX LP Token", "MDEX-LP") {

        balanceToken = IERC20(_balanceToken);
        newToken = IERC20(_newToken);
    }

   function addLiquidty(uint256 _amountBalanceToken, uint256 _amountNewToken) external returns (uint256 _liquidtyMinted){
       require(balanceToken.balanceOf(msg.sender) >= _amountBalanceToken, "not have enough balanceToken");
       require(newToken.balanceOf(msg.sender) >= _amountNewToken, "not have enough newToken");
       require(balanceToken.transferFrom(msg.sender, address(this), _amountBalanceToken), "Transfer Failed");
       require(newToken.transferFrom(msg.sender, address(this), _amountNewToken), "Transfer Failed");
       uint256 actualBalanceToken = balanceToken.balanceOf(address(this)) - reserveBalanceToken;
       uint256 actualNewToken = newToken.balanceOf(address(this)) - reserveNewToken;

       if (totalSupply() == 0) {_liquidtyMinted = Math.sqrt(actualBalanceToken * actualNewToken);}
     else { uint256 shareA = (actualBalanceToken * totalSupply()) / reserveBalanceToken;
        uint256 shareB = (actualNewToken * totalSupply()) / reserveNewToken;
        _liquidtyMinted = Math.min(shareA, shareB);}

        _mint(msg.sender, _liquidtyMinted);

        reserveBalanceToken += actualBalanceToken;
       reserveNewToken += actualNewToken;
   }


   function swap(address _tokenIn, uint256 _amountIn) external returns (uint256 _amountOut) {
    require(_tokenIn == address(balanceToken) || _tokenIn == address(newToken), "unknown token");
    bool isBalanceToken = _tokenIn == address(balanceToken);
    
    IERC20 tokenOut = isBalanceToken ? newToken : balanceToken;
    uint256 reserveIn = isBalanceToken ? reserveBalanceToken : reserveNewToken;
    uint256 reserveOut = isBalanceToken ? reserveNewToken : reserveBalanceToken;

    require(IERC20(_tokenIn).transferFrom(msg.sender, address(this), _amountIn), "Transfer failed");
    uint256 amountInActual = IERC20(_tokenIn).balanceOf(address(this)) - reserveIn;


    uint256 amountInWithFee = amountInActual * 997;
    _amountOut = (amountInWithFee * reserveOut) / ((reserveIn * 1000) + amountInWithFee);



   require(IERC20(tokenOut).transfer(msg.sender, _amountOut), "transfer failed");

    reserveBalanceToken = balanceToken.balanceOf(address(this));
        reserveNewToken = newToken.balanceOf(address(this));
   }


   function removeLiquidty(uint256 _amountLP) external returns (uint256 _amountBalanceToken, uint256 _amountNewToken) {
   
    _amountBalanceToken = (_amountLP * reserveBalanceToken) / totalSupply();
    _amountNewToken = (_amountLP * reserveNewToken) / totalSupply();
    _burn(msg.sender, _amountLP);
    require(balanceToken.transfer(msg.sender, _amountBalanceToken), "transfer failed");
    require(newToken.transfer(msg.sender, _amountNewToken), "transfer failed");
    reserveBalanceToken = balanceToken.balanceOf(address(this));
        reserveNewToken = newToken.balanceOf(address(this));
   }

       
      

   





}