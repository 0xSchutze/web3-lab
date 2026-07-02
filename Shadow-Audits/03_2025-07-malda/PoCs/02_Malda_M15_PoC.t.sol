// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Rebalancer_Unit_Shared} from "../test/unit/shared/Rebalancer_Unit_Shared.t.sol";
import {IAcrossSpokePoolV3} from "../src/interfaces/external/across/IAcrossSpokePoolV3.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccrossBridge} from "../src/rebalancer/bridges/AcrossBridge.sol";
import {IBridge} from "../src/interfaces/IBridge.sol";
import {IRoles} from "../src/interfaces/IRoles.sol";
import {IBridgeV3} from "./IBridgeV3Functions.sol";
import {Rebalancer} from "../src/rebalancer/Rebalancer.sol";
import {IRebalancer} from "../src/interfaces/IRebalancer.sol";

/// @notice Mock SpokePool simulating the Across V3 SpokePool contract on both source and destination chains.
/// Implements depositV3Now (source-side deposit), handleV3AcrossMessage (destination-side delivery wrapper),
/// and refund (source-side refund when the destination delivery reverts). Communicates cross-chain events
/// to a SimulateOffChainBot contract that routes them to the corresponding chain's SpokePool.
contract SpokePool {
    IRoles public roles;
    IBridge public acrossBridge;

    bytes32 public constant GUARDIAN_SPOKEPOOL = keccak256("GUARDIAN_SPOKEPOOL");
    bytes32 public constant acrossBridgeLineaID = keccak256("acrossBridgeLinea");
    bytes32 public constant acrossBridgeBaseID = keccak256("crossBridgeBase");
    bytes32 public constant LINEA_CHAIN = keccak256("LINEA_CHAIN");
    bytes32 public constant BASE_CHAIN = keccak256("BASE_CHAIN");

    error NotAuthorized();
    error AlreadyInitialized();
    error BridgeAddressesNotSet();

    event CrossChainDeliverySucceeded(address tokenSent, uint256 amount, address relayer, bytes message);
    event CrossChainDeliveryReverted(bytes reason);
    event RefundCompleted(bytes revertReason, address depositor, address token, uint256 amount);
    event DepositV3Funded(address tokenSent, uint256 amount, address relayer, bytes message);

    uint256 txNonce;
    address acrossBridgeAddress;
    address simulateOffChainBot;
    bool initialized;
    bytes32 CHAIN;

    struct Transaction {
        address depositor;
        address token;
        uint256 amount;
    }

    mapping(address => bytes32) private AcrossBridgeAddressesToIDs;
    mapping(bytes32 => address) private IDsToAcrossBridgeAddresses;
    mapping(uint256 index => Transaction) txHistory;

    constructor(bytes32 _chain, address _roles) {
        CHAIN = _chain;
        roles = IRoles(_roles);
    }

    function initialize(address _simulateOffChainBot) public {
        if (initialized) revert AlreadyInitialized();

        else if (
            IDsToAcrossBridgeAddresses[acrossBridgeBaseID] == address(0)
                || IDsToAcrossBridgeAddresses[acrossBridgeLineaID] == address(0)
        ) revert BridgeAddressesNotSet();

        else if (CHAIN == LINEA_CHAIN) {
            acrossBridgeAddress = IDsToAcrossBridgeAddresses[acrossBridgeLineaID];
        } else if (CHAIN == BASE_CHAIN) {
            acrossBridgeAddress = IDsToAcrossBridgeAddresses[acrossBridgeBaseID];
        }

        acrossBridge = IBridge(acrossBridgeAddress);
        simulateOffChainBot = _simulateOffChainBot;
        initialized = true;
    }

    function setAcrossBridgeAddresses(address[] calldata addresses, bytes32[] calldata _IDs) external {
        if (!roles.isAllowedFor(msg.sender, GUARDIAN_SPOKEPOOL)) revert NotAuthorized();
        require(addresses.length == _IDs.length);
        uint256 len = _IDs.length;

        for (uint256 i; i < len; ++i) {
            AcrossBridgeAddressesToIDs[addresses[i]] = _IDs[i];
            IDsToAcrossBridgeAddresses[_IDs[i]] = addresses[i];
        }
    }

    /// @notice Source-side deposit. Locks tokens, records the depositor in txHistory,
    /// then notifies the off-chain bot to relay the deposit to the destination chain.
    function depositV3Now(
        address depositor,
        address recipient,
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 outputAmount,
        uint256 destinationChainId,
        address exclusiveRelayer,
        uint32 fillDeadlineOffset,
        uint32 exclusivityDeadline,
        bytes calldata message
    ) external payable {
        // Lock tokens inside SpokePool (mirrors real Across behavior)
        IERC20(inputToken).transferFrom(msg.sender, address(this), inputAmount);
        ++txNonce;
        txHistory[txNonce] = Transaction(depositor, inputToken, inputAmount);

        // In production, off-chain relayer bots listen to this event
        emit DepositV3Funded(inputToken, inputAmount, exclusiveRelayer, message);

        // Since we have no off-chain bot, we simulate the relay via a direct contract call
        bytes memory params = abi.encode(inputToken, inputAmount, exclusiveRelayer, message);
        bytes memory emptyReturnData = "";
        bytes4 emitSelector = bytes4(keccak256("DepositV3Funded(address,uint256,address,bytes)"));
        (bool success,) = simulateOffChainBot.call(
            abi.encodeWithSignature("noticeEmit(bytes4,bytes,bytes)", emitSelector, emptyReturnData, params)
        );

        if (!success) {
            assembly {
                let size := returndatasize()
                let ptr := mload(0x40)
                returndatacopy(ptr, 0, size)
                revert(ptr, size)
            }
        }
    }

    /// @notice Destination-side delivery wrapper. Forwards the cross-chain message to the
    /// AcrossBridge's handleV3AcrossMessage. If the delivery reverts (e.g. token mismatch),
    /// catches the error and notifies the off-chain bot to trigger a refund on the source chain.
    function handleV3AcrossMessage(address _tokenSent, uint256 _amount, address _relayer, bytes memory _message)
        external
    {
        if (!roles.isAllowedFor(msg.sender, roles.REBALANCER_EOA())) revert NotAuthorized();

        try IBridgeV3(acrossBridgeAddress).handleV3AcrossMessage(_tokenSent, _amount, _relayer, _message) {
            emit CrossChainDeliverySucceeded(_tokenSent, _amount, _relayer, _message);
        } catch (bytes memory returnData) {
            // Delivery failed on destination chain
            emit CrossChainDeliveryReverted(returnData);

            // Notify the off-chain bot to trigger refund on the source chain
            bytes4 emitSelector = bytes4(keccak256("CrossChainDeliveryReverted(bytes)"));
            bytes memory params = "";
            (bool success,) = simulateOffChainBot.call(
                abi.encodeWithSignature("noticeEmit(bytes4,bytes,bytes)", emitSelector, returnData, params)
            );

            if (!success) {
                assembly {
                    let size := returndatasize()
                    let ptr := mload(0x40)
                    returndatacopy(ptr, 0, size)
                    revert(ptr, size)
                }
            }
        }
    }

    /// @notice Source-side refund. Retrieves the last depositor from txHistory and transfers
    /// their locked tokens back. In the real Across system, this is triggered by the Hub
    /// after a fill timeout or failed delivery on the destination chain.
    function refund(bytes memory _reason) external {
        if (!roles.isAllowedFor(msg.sender, roles.REBALANCER_EOA())) revert NotAuthorized();
        uint256 lastTxId = txNonce;
        Transaction memory txData = txHistory[lastTxId];

        IERC20(txData.token).transfer(txData.depositor, txData.amount);
        emit RefundCompleted(_reason, txData.depositor, txData.token, txData.amount);
    }
}

/// @notice Simulates the off-chain relayer bot that bridges events between two chains.
/// In production, Across relayer bots listen to on-chain events and trigger corresponding
/// actions on the destination/source chain. This contract replaces that off-chain logic
/// with deterministic on-chain routing based on event selectors.
contract SimulateOffChainBot {
    address usdcAddress;
    address spokePoolLinea;
    address spokePoolBase;
    bool initialized;

    error UnknownSelector(bytes4 selector);
    error AlreadyInitialized();

    function initialize(address _spokePoolLinea, address _spokePoolBase, address _usdcAddress) public {
        if (initialized) revert AlreadyInitialized();
        spokePoolLinea = _spokePoolLinea;
        spokePoolBase = _spokePoolBase;
        usdcAddress = _usdcAddress;
        initialized = true;
    }

    /// @notice Event router. Determines which chain sent the event and forwards it
    /// to the opposite chain's SpokePool with the appropriate action.
    function noticeEmit(bytes4 emitSelector, bytes memory _reason, bytes calldata params) external {
        // Determine cross-chain direction: if Linea sent it, route to Base, and vice versa
        bool isLineaChainSpokePool = msg.sender == spokePoolLinea ? true : false;
        address targetChainSpokePoolAddress = isLineaChainSpokePool ? spokePoolBase : spokePoolLinea;

        if (emitSelector == bytes4(keccak256("CrossChainDeliveryReverted(bytes)"))) {
            _handleDeliveryReverted(targetChainSpokePoolAddress, _reason);
        } else if (emitSelector == bytes4(keccak256("DepositV3Funded(address,uint256,address,bytes)"))) {
            (address _tokenSent, uint256 _amount, address _relayer, bytes memory _message) =
                abi.decode(params, (address, uint256, address, bytes));
            _handleDepositFunded(targetChainSpokePoolAddress, _tokenSent, _amount, _relayer, _message);
        } else {
            revert UnknownSelector(emitSelector);
        }
    }

    /// @notice Routes a revert event back to the source chain's SpokePool to trigger a refund.
    function _handleDeliveryReverted(address _targetChainSpokePoolAddress, bytes memory _reason) internal {
        (bool success,) =
            _targetChainSpokePoolAddress.call(abi.encodeWithSignature("refund(bytes)", _reason));

        if (!success) {
            assembly {
                let size := returndatasize()
                let ptr := mload(0x40)
                returndatacopy(ptr, 0, size)
                revert(ptr, size)
            }
        }
    }

    /// @notice Routes a deposit event to the destination chain's SpokePool to deliver the funds.
    /// Intentionally substitutes _tokenSent with USDC to trigger AcrossBridge_TokenMismatch on the
    /// destination AcrossBridge, simulating a scenario where the cross-chain delivery fails
    /// (e.g. due to a token resolution error or misconfigured output token on the destination).
    function _handleDepositFunded(
        address _targetChainSpokePoolAddress,
        address _tokenSent,
        uint256 _amount,
        address _relayer,
        bytes memory _message
    ) internal {
        // Force a token mismatch: the market's underlying is WETH, but we send USDC.
        // This causes AcrossBridge.handleV3AcrossMessage to revert with AcrossBridge_TokenMismatch(),
        // which triggers the catch block in the destination SpokePool, initiating the refund flow.
        _tokenSent = usdcAddress;
        (bool success,) = _targetChainSpokePoolAddress.call(
            abi.encodeWithSignature(
                "handleV3AcrossMessage(address,uint256,address,bytes)", _tokenSent, _amount, _relayer, _message
            )
        );

        if (!success) {
            assembly {
                let size := returndatasize()
                let ptr := mload(0x40)
                returndatacopy(ptr, 0, size)
                revert(ptr, size)
            }
        }
    }
}

/// @title M-15: Across Bridge Refund Lock — Unrecoverable Funds in Rebalancer
/// @notice When a cross-chain rebalancing operation via AcrossBridge fails on the destination chain,
///         the Across protocol refunds the deposited tokens to the original depositor address. Because
///         AcrossBridge sets the Rebalancer contract as the depositor (msg.sender), refunded tokens are
///         sent directly to the Rebalancer. The Rebalancer has no sweep, rescue, or withdrawal function,
///         permanently locking all refunded assets.
///         This PoC simulates a full multi-chain flow: Linea (source) -> Base (destination) with an
///         intentional token mismatch on Base causing a revert, followed by an automatic refund to the
///         Rebalancer on Linea, proving the funds become permanently locked.
/// @author 0xSchutze
contract Malda_M15_UnrecoverableFunds is Test, Rebalancer_Unit_Shared {
    AccrossBridge acrossBridgeLinea;
    AccrossBridge acrossBridgeBase;
    SpokePool spokePoolLinea;
    SpokePool spokePoolBase;
    SimulateOffChainBot simulateOffChainBot;
    Rebalancer rebalancerLinea;
    Rebalancer rebalancerBase;

    bytes32 public constant LINEA_CHAIN = keccak256("LINEA_CHAIN");
    bytes32 public constant BASE_CHAIN = keccak256("BASE_CHAIN");
    bytes32 public constant acrossBridgeLineaID = keccak256("acrossBridgeLinea");
    bytes32 public constant acrossBridgeBaseID = keccak256("crossBridgeBase");
    bytes32 public constant REBALANCER_EOA = keccak256("REBALANCER_EOA");
    bytes32 public constant GUARDIAN_SPOKEPOOL = keccak256("GUARDIAN_SPOKEPOOL");
    bytes32 public constant GUARDIAN_BRIDGE = keccak256("GUARDIAN_BRIDGE");

    function _additionalSetup() internal {
        // -- Permissions for test contract --
        roles.allowFor(address(this), GUARDIAN_SPOKEPOOL, true);
        roles.allowFor(address(this), GUARDIAN_BRIDGE, true);

        // -- Deploy off-chain bot (has access to both chains) --
        simulateOffChainBot = new SimulateOffChainBot();

        // -- Linea chain deployment --
        spokePoolLinea = new SpokePool(LINEA_CHAIN, address(roles));
        acrossBridgeLinea = new AccrossBridge(address(roles), address(spokePoolLinea));
        rebalancerLinea = new Rebalancer(address(roles), address(this));

        // -- Base chain deployment --
        spokePoolBase = new SpokePool(BASE_CHAIN, address(roles));
        acrossBridgeBase = new AccrossBridge(address(roles), address(spokePoolBase));
        rebalancerBase = new Rebalancer(address(roles), address(this));

        // -- Bridge address registry (both SpokePools need to know both bridges) --
        address[] memory addresses = new address[](2);
        addresses[0] = address(acrossBridgeLinea);
        addresses[1] = address(acrossBridgeBase);

        bytes32[] memory IDs = new bytes32[](2);
        IDs[0] = acrossBridgeLineaID;
        IDs[1] = acrossBridgeBaseID;

        // -- Off-chain bot initialization --
        simulateOffChainBot.initialize(address(spokePoolLinea), address(spokePoolBase), address(usdc));
        roles.allowFor(address(simulateOffChainBot), REBALANCER_EOA, true);

        // -- Linea chain initialization --
        spokePoolLinea.setAcrossBridgeAddresses(addresses, IDs);
        spokePoolLinea.initialize(address(simulateOffChainBot));
        rebalancerLinea.setWhitelistedBridgeStatus(address(acrossBridgeLinea), true);
        rebalancerLinea.setWhitelistedDestination(2, true);
        acrossBridgeLinea.setWhitelistedRelayer(2, address(0), true);
        vm.label(address(rebalancerLinea), "RebalancerLinea");
        roles.allowFor(address(rebalancerLinea), roles.REBALANCER(), true);

        // -- Base chain initialization --
        spokePoolBase.setAcrossBridgeAddresses(addresses, IDs);
        spokePoolBase.initialize(address(simulateOffChainBot));
        rebalancerBase.setWhitelistedBridgeStatus(address(acrossBridgeBase), true);
        rebalancerBase.setWhitelistedDestination(2, true);
        acrossBridgeBase.setWhitelistedRelayer(2, address(0), true);
        vm.label(address(rebalancerBase), "RebalancerBase");
        roles.allowFor(address(rebalancerBase), roles.REBALANCER(), true);

        // -- Allow market on both chains --
        address[] memory allowedMarkets = new address[](1);
        allowedMarkets[0] = address(mWethHost);
        rebalancerBase.setAllowList(allowedMarkets, true);
        rebalancerLinea.setAllowList(allowedMarkets, true);

        // -- Seed market with liquidity --
        deal(address(weth), address(mWethHost), 10000e18);
    }

    /// @notice Simulates a destination chain revert during AcrossBridge rebalancing to demonstrate permanent lock of funds.
    function test_M15_UnrecoverableFunds() public {
        // Arrange
        _additionalSetup();

        bytes memory sendMsgCalldataMessage = abi.encode(
            uint256(5000e18),
            uint256(5000e18),
            address(0),
            uint32(block.timestamp + 10 days),
            uint32(block.timestamp + 10 days)
        );
        IRebalancer.Msg memory sendMsgFinalMessage = IRebalancer.Msg({
            dstChainId: uint32(2),
            token: address(weth),
            message: sendMsgCalldataMessage,
            bridgeData: bytes("")
        });

        // Act — A single sendMsg triggers the entire cross-chain flow:
        // Linea Rebalancer -> Linea AcrossBridge -> Linea SpokePool (deposit + lock)
        // -> Off-chain Bot -> Base SpokePool (delivery attempt with wrong token -> revert)
        // -> Off-chain Bot -> Linea SpokePool (refund to depositor = Rebalancer)
        vm.prank(address(simulateOffChainBot));
        rebalancerLinea.sendMsg(address(acrossBridgeLinea), address(mWethHost), 5000e18, sendMsgFinalMessage);

        // Assert — 5000 WETH is now trapped inside the Rebalancer with no way to extract it.
        // The Rebalancer contract has no sweep(), rescue(), or withdraw() function.
        assertEq(
            IERC20(address(weth)).balanceOf(address(rebalancerLinea)),
            5000e18,
            "Refunded tokens permanently locked in Rebalancer"
        );
    }
}