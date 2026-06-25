// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Setup} from "./warden_setup/Setup.sol";
import {IDelegationManager} from "contracts/EigenLayer/interfaces/IDelegationManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Stateless trojan contract to simulate the EigenLayer/EigenPod callback behavior 
// missing in the local MockDelegationManager.
contract FakeDelegationManager is Test {
    function completeQueuedWithdrawal(
        bytes calldata, 
        address[] calldata, 
        uint256, 
        bool
    ) external {
        address delegator = msg.sender;
        
        (bool ok, bytes memory res) = delegator.staticcall(abi.encodeWithSignature("eigenPod()"));
        require(ok);
        address pod = abi.decode(res, (address));

        vm.startPrank(pod);
        (bool success, bytes memory data) = delegator.call{value: 0}("");
        vm.stopPrank();

        if (!success) {
            assembly {
                revert(add(data, 32), mload(data))
            }
        }
    }
}

/// @title H-03: ReentrancyGuard DoS on EigenPod withdrawals
/// @notice OperatorDelegator's completeQueuedWithdrawal triggers EigenLayer to send ETH to the EigenPod. 
/// The EigenPod immediately forwards the ETH back to the OperatorDelegator via its receive() function. 
/// Since both completeQueuedWithdrawal and receive() have the nonReentrant modifier, the callback 
/// hits the ReentrancyGuard lock and reverts, permanently bricking all queued native ETH withdrawals.
/// @author 0xSchutze
contract Renzo_H03_PoC_Test is Test, Setup {

    /// @notice Proves that completing a queued withdrawal triggers a ReentrancyGuard revert.
    function test_H03_Reentrancy_DoS() public {
        FakeDelegationManager fakeManager = new FakeDelegationManager();
        vm.etch(address(delegationManager), address(fakeManager).code);

        IDelegationManager.Withdrawal memory withdrawal;
        IERC20[] memory tokens = new IERC20[](0);

        vm.startPrank(OWNER);
        
        // The transaction must revert because the reentrancy lock is already ENTERED 
        // by completeQueuedWithdrawal before receive() is called.
        vm.expectRevert("ReentrancyGuard: reentrant call");
        operatorDelegator1.completeQueuedWithdrawal(
            withdrawal,
            tokens,
            0
        );
        vm.stopPrank();
    }
}