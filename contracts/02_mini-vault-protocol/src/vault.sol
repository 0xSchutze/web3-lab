// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20} from "./IERC20.sol";

/// @title Vault
/// @author 0xSchutze
/// @notice A multi-asset treasury vault supporting ETH and ERC20 token deposits.
///         Anyone can deposit, only the owner can withdraw.
///         Authorized addresses can manage the whitelist and pause state.
contract Vault {
    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice The owner of this vault
    address public owner;

    /// @notice Whether the vault is currently paused (no deposits allowed)
    bool public paused;

    struct ApprovedList {
        address authorizedAddress;
    }

    /// @notice List of currently authorized addresses (max 3)
    ApprovedList[] public authorizedAddresses;

    /// @notice Returns true if the given address is authorized
    mapping(address => bool) public approvedAddress;

    /// @notice Returns true if the given token is whitelisted for deposit
    mapping(address => bool) public allowedTokens;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposit(uint256 amount, uint256 txDate);
    event Withdraw(address indexed to, uint256 amount, uint256 txDate);
    event DepositToken(
        address indexed from,
        address indexed vault,
        address indexed token,
        uint256 amount
    );
    event WithdrawToken(
        address indexed to,
        address indexed token,
        uint256 amount
    );
    event OwnershipTransferred(address indexed from, address indexed newOwner);
    event AddressAuthorized(address indexed authorizedAddress);
    event AuthorizationRemoved(address indexed who, uint256 date);
    event TokenWhitelisted(
        address indexed token,
        address indexed by,
        uint256 date
    );
    event TokenRemovedFromWhitelist(
        address indexed token,
        address indexed by,
        uint256 date
    );
    event Paused(address indexed by);
    event Unpaused(address indexed by);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier vaultOwnerOnly() {
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier vaultOwnerAndApprovedOnly() {
        require(
            msg.sender == owner || approvedAddress[msg.sender],
            "not authorized"
        );
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "vault is paused");
        _;
    }

    modifier authorizedAddressLimit() {
        require(authorizedAddresses.length < 3, "max 3 authorized addresses");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param _owner The address that will own and control this vault
    constructor(address _owner) {
        require(_owner != address(0), "owner cannot be zero address");
        owner = _owner;
    }

    /*//////////////////////////////////////////////////////////////
                            ETH FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit ETH into the vault (minimum 0.01 ETH)
    function depositEth() external payable whenNotPaused {
        require(msg.value >= 0.01 ether, "minimum deposit is 0.01 ETH");
        emit Deposit(msg.value, block.timestamp);
    }

    /// @notice Withdraw ETH from the vault (owner only)
    /// @param _amount Amount of ETH to withdraw in wei
    function withdrawEth(uint256 _amount) external vaultOwnerOnly {
        require(_amount >= 0.01 ether, "minimum withdrawal is 0.01 ETH");
        require(_amount <= address(this).balance, "insufficient ETH balance");
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        require(success, "ETH transfer failed");
        emit Withdraw(msg.sender, _amount, block.timestamp);
    }

    /// @notice Returns the ETH balance of this vault
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /*//////////////////////////////////////////////////////////////
                           TOKEN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit an ERC20 token into the vault
    /// @dev Token must be whitelisted. Caller must have approved this contract first.
    /// @param _tokenAddress The ERC20 token contract address
    /// @param _amount Amount of tokens to deposit
    function depositToken(
        address _tokenAddress,
        uint256 _amount
    ) external whenNotPaused {
        require(allowedTokens[_tokenAddress], "token not whitelisted");
        require(_amount > 0, "amount must be greater than 0");
        bool success = IERC20(_tokenAddress).transferFrom(
            msg.sender,
            address(this),
            _amount
        );
        require(success, "token transfer failed");
        emit DepositToken(msg.sender, address(this), _tokenAddress, _amount);
    }

    /// @notice Withdraw an ERC20 token from the vault (owner only)
    /// @param _tokenAddress The ERC20 token contract address
    /// @param _amount Amount of tokens to withdraw
    function withdrawToken(
        address _tokenAddress,
        uint256 _amount
    ) external vaultOwnerOnly {
        require(_amount > 0, "amount must be greater than 0");
        require(
            IERC20(_tokenAddress).balanceOf(address(this)) >= _amount,
            "insufficient token balance"
        );
        bool success = IERC20(_tokenAddress).transfer(msg.sender, _amount);
        require(success, "token transfer failed");
        emit WithdrawToken(msg.sender, _tokenAddress, _amount);
    }

    /// @notice Returns the vault's balance of a specific ERC20 token
    /// @param _tokenAddress The ERC20 token contract address
    function getTokenBalance(
        address _tokenAddress
    ) external view returns (uint256) {
        return IERC20(_tokenAddress).balanceOf(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                          TOKEN WHITELIST
    //////////////////////////////////////////////////////////////*/

    /// @notice Add a token to the deposit whitelist
    /// @param _tokenAddress The ERC20 token contract address to whitelist
    function addTokenToWhitelist(
        address _tokenAddress
    ) external vaultOwnerAndApprovedOnly {
        require(_tokenAddress != address(0), "invalid token address");
        allowedTokens[_tokenAddress] = true;
        emit TokenWhitelisted(_tokenAddress, msg.sender, block.timestamp);
    }

    /// @notice Remove a token from the deposit whitelist
    /// @param _tokenAddress The ERC20 token contract address to remove
    function removeTokenFromWhitelist(
        address _tokenAddress
    ) external vaultOwnerAndApprovedOnly {
        allowedTokens[_tokenAddress] = false;
        emit TokenRemovedFromWhitelist(
            _tokenAddress,
            msg.sender,
            block.timestamp
        );
    }

    /*//////////////////////////////////////////////////////////////
                         ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    /// @notice Authorize an address to manage whitelist and pause state
    /// @param _newAuthorizedAddress The address to authorize (max 3 total)
    function approveAddress(
        address _newAuthorizedAddress
    ) external vaultOwnerOnly authorizedAddressLimit {
        require(_newAuthorizedAddress != address(0), "invalid address");
        require(!approvedAddress[_newAuthorizedAddress], "already authorized");
        approvedAddress[_newAuthorizedAddress] = true;
        authorizedAddresses.push(
            ApprovedList({authorizedAddress: _newAuthorizedAddress})
        );
        emit AddressAuthorized(_newAuthorizedAddress);
    }

    /// @notice Remove authorization from an address using swap-and-pop
    /// @param _authorizedAddress The address to deauthorize
    function removeApproval(
        address _authorizedAddress
    ) external vaultOwnerOnly {
        require(approvedAddress[_authorizedAddress], "address not authorized");
        approvedAddress[_authorizedAddress] = false;

        for (uint256 i = 0; i < authorizedAddresses.length; i++) {
            if (
                authorizedAddresses[i].authorizedAddress == _authorizedAddress
            ) {
                authorizedAddresses[i] = authorizedAddresses[
                    authorizedAddresses.length - 1
                ];
                authorizedAddresses.pop();
                break;
            }
        }
        emit AuthorizationRemoved(_authorizedAddress, block.timestamp);
    }

    /// @notice Transfer ownership of the vault to a new address
    /// @dev Clears all authorized addresses on ownership transfer
    /// @param _newOwnerAddress The new owner address
    function transferOwnership(
        address _newOwnerAddress
    ) external vaultOwnerOnly {
        require(
            _newOwnerAddress != address(0),
            "cannot transfer to zero address"
        );
        address previousOwner = owner;
        owner = _newOwnerAddress;

        for (uint256 i = 0; i < authorizedAddresses.length; i++) {
            approvedAddress[authorizedAddresses[i].authorizedAddress] = false;
        }
        delete authorizedAddresses;

        emit OwnershipTransferred(previousOwner, _newOwnerAddress);
    }

    /*//////////////////////////////////////////////////////////////
                           PAUSE CONTROL
    //////////////////////////////////////////////////////////////*/

    /// @notice Pause the vault to prevent new deposits
    function pause() external vaultOwnerAndApprovedOnly whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    /// @notice Unpause the vault to allow deposits again
    function unpause() external vaultOwnerAndApprovedOnly {
        require(paused, "vault is not paused");
        paused = false;
        emit Unpaused(msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                              RECEIVE
    //////////////////////////////////////////////////////////////*/

    /// @notice Accept direct ETH transfers (minimum 0.01 ETH)
    receive() external payable {
        require(msg.value >= 0.01 ether, "minimum deposit is 0.01 ETH");
        emit Deposit(msg.value, block.timestamp);
    }
}
