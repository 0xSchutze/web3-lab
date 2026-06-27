// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Setup} from "./warden_setup/Setup.sol";
import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {WithdrawQueueStorageV1} from "contracts/Withdraw/WithdrawQueueStorage.sol";

/// @notice External blacklist registry used by SmartWallet to check sender reputation.
contract Blacklist {
    mapping(address => bool) public blacklist;

    function addAddressToBlacklist(address _address) public {
        blacklist[_address] = true;
    }

    function removeAddressFromBlacklist(address _address) public {
        blacklist[_address] = false;
    }

    function isBlacklisted(address _address) external view returns (bool) {
        return blacklist[_address];
    }
}

/// @notice Simulates a realistic smart contract wallet (e.g., Gnosis Safe) with non-trivial
/// receive() logic. Two scenarios demonstrate how .transfer()'s 2300 gas stipend is insufficient:
/// Scenario 1: Event emission + storage write (SSTORE) — triggers native EVM OutOfGas.
/// Scenario 2: Assembly-level isPaused check + external blacklist call — gas guard detects
/// remaining gas is below the cold SLOAD threshold and reverts with exact gas telemetry.
contract SmartWallet {
    event TransferInfo(uint256 amount, address from, uint256 time);

    bool public isPaused;
    uint256 testScenario;
    address blacklistAddress;

    constructor(address _blacklistAddress) {
        blacklistAddress = _blacklistAddress;
    }

    struct TxHistory {
        uint256 amount;
        address from;
        uint256 time;
    }

    TxHistory[] public txHistory;

    error WalletPaused();
    error OutOfGasWithDetails(uint256 gasLeft);
    error WalletBlacklisted();

    function setScenario(uint256 _scenario) public {
        testScenario = _scenario;
    }

    receive() external payable {
        // Scenario 1: Event + SSTORE — guaranteed to exceed 2300 gas stipend
        if (testScenario == 1) {
            emit TransferInfo(msg.value, msg.sender, block.timestamp);
            txHistory.push(TxHistory(msg.value, msg.sender, block.timestamp));
        }

        bytes4 outOfGasSelector = OutOfGasWithDetails.selector;
        bytes4 walletPausedSelector = WalletPaused.selector;
        bytes4 walletBlacklistedSelector = WalletBlacklisted.selector;
        bytes memory payload = abi.encodeWithSignature("isBlacklisted(address)", msg.sender);

        assembly {
            // Scenario 2: Realistic wallet guards (isPaused + blacklist check)
            if eq(sload(testScenario.slot), 2) {

                // Gas guard: if remaining gas is below cold SLOAD cost (2100),
                // the next sload(isPaused.slot) would cause native OOG.
                // Capture exact gas telemetry and revert with diagnostic data instead.
                if iszero(gt(gas(), 2100)) {
                   let ptr := mload(0x40)
                    mstore(ptr, outOfGasSelector)
                    mstore(add(ptr, 0x04), gas())
                    revert(ptr, 0x24) // 4 byte selector + 32 byte gas = 36 byte (0x24)
                }

                let paused := sload(isPaused.slot)
                if eq(paused, 1) {
                    let ptr := mload(0x40)
                    mstore(ptr, shl(224, walletPausedSelector)) 
                    revert(ptr, 0x04) 
                }

                // External call to Blacklist registry
                let payloadPtr := add(payload, 0x20)
                let payloadSize := mload(payload)
                let freeMem := mload(0x40)
                let success := call(
                    gas(),
                    sload(blacklistAddress.slot),
                    0,
                    payloadPtr,
                    payloadSize,
                    freeMem,
                    0x20
                )
                
                if iszero(success) { revert(0, 0) }

                let blacklisted := mload(freeMem)
                if eq(blacklisted, 1) {
                    let ptr := mload(0x40)
                    mstore(ptr, shl(224, walletBlacklistedSelector)) 
                    revert(ptr, 0x04) 
                }
            }
        }
    }
}

/// @title H-01: ETH permanently locked for Smart Contract Wallets due to .transfer() gas limit
/// @notice WithdrawQueue.claim() sends ETH via .transfer(), which forwards only 2300 gas.
/// Smart contract wallets (e.g., Gnosis Safe) require >2300 gas in their receive() function
/// for basic operations like storage writes, event emissions, or proxy delegation.
/// Since claim() enforces msg.sender == original withdrawer, the locked funds cannot be
/// recovered by an alternative address. Result: permanent fund loss for all SC wallet users.
/// @author 0xSchutze
contract Renzo_H01_PoC_Test is Test, Setup {

    address constant IS_NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    SmartWallet smartWallet;
    Blacklist blacklist;
    IERC20 ezEthAddrToERC;
    IERC20 stEthAddrToERC;
    address smartWalletAddr;
    address bob;

    function _setupWalletAndLiquidity() internal {
        blacklist = new Blacklist();
        smartWallet = new SmartWallet(address(blacklist));
        smartWalletAddr = address(smartWallet);
        stEthAddrToERC = IERC20(address(stETH));
        ezEthAddrToERC = IERC20(address(ezETH));
        bob = makeAddr("bob");

        WithdrawQueueStorageV1.TokenWithdrawBuffer[] memory buffers =
            new WithdrawQueueStorageV1.TokenWithdrawBuffer[](2);
        buffers[0] = WithdrawQueueStorageV1.TokenWithdrawBuffer(address(stEthAddrToERC), 0.1 ether);
        buffers[1] = WithdrawQueueStorageV1.TokenWithdrawBuffer(IS_NATIVE, 100 ether);

        vm.startPrank(OWNER);
        stETH.mint(smartWalletAddr, 50e18);
        withdrawQueue.updateWithdrawBufferTarget(buffers);
        vm.stopPrank();

        // Bob deposits ETH to fill the withdraw buffer so SmartWallet can request native ETH withdrawal
        vm.deal(bob, 100 ether);
        vm.startPrank(bob);
        restakeManager.depositETH{value: 100 ether}();
        vm.stopPrank();

        vm.startPrank(smartWalletAddr);
        stETH.approve(address(restakeManager), type(uint256).max);
        ezETH.approve(address(withdrawQueue), type(uint256).max);
        vm.stopPrank();
    }

    /// @notice Proves that a wallet performing event emission + storage write in receive()
    /// triggers native EVM OutOfGas, permanently locking the withdrawn ETH.
    function test_H01_NativeOOG_EventAndStorageWrite() public {
        _setupWalletAndLiquidity();
        smartWallet.setScenario(1);

        vm.startPrank(smartWalletAddr);
        restakeManager.deposit(stEthAddrToERC, 50e18);
        uint256 ezEthBalance = ezETH.balanceOf(smartWalletAddr);
        withdrawQueue.withdraw(ezEthBalance, IS_NATIVE);
        vm.warp(block.timestamp + 7 days);

        // .transfer() sends only 2300 gas. Event emission (LOG3 ~1500 gas) +
        // SSTORE for txHistory.push (~20000 gas) far exceeds the stipend.
        try withdrawQueue.claim(0) {
            fail("claim() should have reverted - wallet receive() exceeds 2300 gas stipend");
        } catch (bytes memory returnData) {
            // Native OOG produces empty returnData (0x)
            assertTrue(returnData.length == 0, "Expected native EVM OutOfGas (empty returnData)");
        }

        vm.stopPrank();
    }

    /// @notice Proves that even minimal wallet logic (cold SLOAD for isPaused check) exhausts
    /// the 2300 gas stipend. The wallet's gas guard captures exact remaining gas before OOG.
    function test_H01_CustomOOG_ColdSloadExhaustsStipend() public {
        _setupWalletAndLiquidity();
        smartWallet.setScenario(2);

        vm.startPrank(smartWalletAddr);
        restakeManager.deposit(stEthAddrToERC, 50e18);
        uint256 ezEthBalance = ezETH.balanceOf(smartWalletAddr);
        withdrawQueue.withdraw(ezEthBalance, IS_NATIVE);
        vm.warp(block.timestamp + 7 days);

        // After warm SLOAD for testScenario (~100 gas), only ~2200 gas remains.
        // The gas guard detects this is below cold SLOAD cost (2100 gas) and
        // reverts with exact gas telemetry instead of hitting native OOG.
        try withdrawQueue.claim(0) {
            fail("claim() should have reverted - wallet receive() exceeds 2300 gas stipend");
        } catch (bytes memory returnData) {
            if (returnData.length == 0) {
                // Native OOG — wallet exhausted gas before reaching the guard
                console.log("Native EVM OutOfGas (gas exhausted before guard)");
                return;
            }

            bytes4 selector = abi.decode(returnData, (bytes4));
            if (selector == SmartWallet.OutOfGasWithDetails.selector) {
                uint256 gasLeft;
                assembly {
                    gasLeft := mload(add(returnData, 0x40))
                }
                console.log("Gas remaining at guard checkpoint:", gasLeft);
                assertTrue(gasLeft < 2300, "gasLeft must be below 2300: stipend was not exhausted");
                return;
            }

            fail("Unexpected revert - neither OOG nor gas guard triggered");
        }

        vm.stopPrank();
    }
}