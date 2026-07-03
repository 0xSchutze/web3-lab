// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Rebalancer_Unit_Shared} from "../test/unit/shared/Rebalancer_Unit_Shared.t.sol";
import {EverclearBridge} from "../src/rebalancer/bridges/EverclearBridge.sol";
import {IFeeAdapter} from "../src/interfaces/external/everclear/IFeeAdapter.sol";
import {IRebalancer} from "../src/interfaces/IRebalancer.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Mock FeeAdapter simulating the Everclear intent creation endpoint.
/// Critically, this mock attempts to pull the input asset from the caller (the Bridge),
/// mirroring the real Everclear protocol's behavior.
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

        // The real Everclear FeeAdapter pulls funds from the caller.
        // If the caller (EverclearBridge) has 0 balance, this will revert.
        IERC20(_inputAsset).transferFrom(msg.sender, address(this), _amount);

        return (_intentId, _intent);
    }
}

/// @title M-06: EverclearBridge Missing TransferFrom Causes DoS
/// @notice The EverclearBridge completely forgets to execute `safeTransferFrom` to pull tokens
///         from the Rebalancer before interacting with the Everclear FeeAdapter or returning slippage.
///         Because the bridge's balance is always 0, any rebalancing attempt will inevitably revert
///         either during the slippage refund (`safeTransfer`) or during the intent creation (`transferFrom`).
/// @author 0xSchutze
contract Malda_M06_DoS is Test, Rebalancer_Unit_Shared {
    EverclearBridge public everclearBridge;
    MockFeeAdapter public feeAdapter;
    IRebalancer.Msg public exploitMessage;

    function _additionalSetup() internal {
        // 1. Grant roles
        roles.allowFor(address(this), roles.GUARDIAN_BRIDGE(), true);
        roles.allowFor(address(this), roles.REBALANCER_EOA(), true);

        // 2. Deploy infrastructure
        feeAdapter = new MockFeeAdapter();
        everclearBridge = new EverclearBridge(address(roles), address(feeAdapter));
        
        rebalancer.setWhitelistedBridgeStatus(address(everclearBridge), true);
        rebalancer.setWhitelistedDestination(2, true);

        // 3. Whitelist market and add liquidity
        address[] memory allowedMarkets = new address[](1);
        allowedMarkets[0] = address(mWethHost);
        rebalancer.setAllowList(allowedMarkets, true);
        deal(address(weth), address(mWethHost), 10000e18);

        // 4. Construct valid Everclear message payload
        address randomAddr = makeAddr("randomAddr");
        uint32[] memory destinations = new uint32[](1);
        destinations[0] = 2;
        bytes32 receiver = bytes32(uint256(uint160(randomAddr)));

        bytes memory payload = abi.encode(
            destinations,
            receiver,
            address(weth),
            bytes32(uint256(uint160(address(weth)))),
            1000e18, // params.amount = 1000 WETH
            0,
            0,
            "",
            IFeeAdapter.FeeParams({fee: 0, deadline: 0, sig: ""})
        );

        bytes memory encodedMessage = abi.encodePacked(bytes4(0x7ddd19ca), payload);

        exploitMessage = IRebalancer.Msg({
            dstChainId: 2,
            token: address(weth),
            message: encodedMessage,
            bridgeData: ""
        });
    }

    /// @notice Tests the slippage refund scenario where extracted amount exceeds params.amount.
    function test_M06_DoS_WithSlippageRefund() public {
        // Arrange
        _additionalSetup();

        // Act & Assert
        // We set extractedAmount to 2000e18, but params.amount is 1000e18.
        // The bridge will attempt to transfer 1000e18 back to the market.
        // It will revert with ERC20InsufficientBalance because the bridge holds 0 WETH.
        vm.expectRevert();
        rebalancer.sendMsg(address(everclearBridge), address(mWethHost), 2000e18, exploitMessage);
    }

    /// @notice Tests the zero-slippage scenario, verifying the revert still occurs.
    function test_M06_DoS_WithoutSlippage() public {
        // Arrange
        _additionalSetup();

        // Act & Assert
        // We set extractedAmount to 1000e18, matching params.amount exactly.
        // The slippage logic is skipped, but FeeAdapter.newIntent() will attempt to pull 1000e18.
        // It will revert with ERC20InsufficientBalance because the bridge holds 0 WETH.
        vm.expectRevert();
        rebalancer.sendMsg(address(everclearBridge), address(mWethHost), 1000e18, exploitMessage);
    }
}