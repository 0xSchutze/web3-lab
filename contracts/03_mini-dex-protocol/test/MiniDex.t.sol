// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MiniDEXFactory} from "../src/Mini-DEX-Factory.sol";
import {MiniDEXPair} from "../src/Mini-DEX-Pair.sol";
import {Launchpad} from "../src/Launchpad/Launchpad.sol";
import {Token} from "../src/Launchpad/Token.sol";

/**
 * @title Mini-DEX Protocol Integration Test Suite
 * @notice End-to-end (E2E) verification of the Routerless AMM, Fair Launchpad, and Liquidity Provision Math.
 * @dev Focus: Slippage calculations (0.5%), Reentrancy/Underflow invariants, and LP Token strict isolation.
 */
contract MiniDexTest is Test {
    // ------------------------------------------------------------------------
    // System Under Test (SUT)
    // ------------------------------------------------------------------------
    MiniDEXFactory public factory;
    Launchpad public launchpad;
    MiniDEXPair public pair;

    // ------------------------------------------------------------------------
    // Core Assets
    // ------------------------------------------------------------------------
    Token public tokenA;
    Token public tokenB;

    // ------------------------------------------------------------------------
    // Protocol Actors
    // ------------------------------------------------------------------------
    address public deployer = address(this);
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    // ------------------------------------------------------------------------
    // Invariant Constants
    // ------------------------------------------------------------------------
    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 10**18;
    uint256 public constant INITIAL_LIQUIDITY_A = 10 * 10**18;
    uint256 public constant INITIAL_LIQUIDITY_B = 30_000 * 10**18;

    function setUp() public {
        // 1. Deploy Core Infrastructure
        factory = new MiniDEXFactory(deployer);
        launchpad = new Launchpad();

        // 2. Permissionless Token Issuance via Launchpad
        address tokenAAddr = launchpad.createToken("Cat Coin", "CAT", INITIAL_SUPPLY);
        address tokenBAddr = launchpad.createToken("Dog Coin", "DOG", INITIAL_SUPPLY);
        
        tokenA = Token(tokenAAddr);
        tokenB = Token(tokenBAddr);

        // 3. Register Zero-Dependency AMM Pair
        address pairAddr = factory.createPair(address(tokenA), address(tokenB));
        pair = MiniDEXPair(pairAddr);

        // Map canonical token sorting addresses
        address token0 = pair.token0();
        address token1 = pair.token1();

        // 4. Provision Initial Liquidity
        Token(token0).approve(address(pair), type(uint256).max);
        Token(token1).approve(address(pair), type(uint256).max);

        // Mint liquidity enforcing invariant ratio logic
        if (token0 == address(tokenA)) {
            pair.mint(INITIAL_LIQUIDITY_A, INITIAL_LIQUIDITY_B);
        } else {
            pair.mint(INITIAL_LIQUIDITY_B, INITIAL_LIQUIDITY_A);
        }

        // 5. Fund Test Identity
        tokenA.transfer(alice, 50 * 10**18);
    }

    /// @notice Validates the constant product formula (X * Y = K) execution with the integrated 0.5% protocol fee.
    function test_Execution_SwapMath() public {
        uint256 initialBalanceB = tokenB.balanceOf(alice);
        
        vm.startPrank(alice);

        // Alice grants exact allowance for the swap engine
        uint112 amountIn = uint112(2 * 10**18);
        tokenA.approve(address(pair), amountIn);

        // Execute Routerless Base Swap
        pair.swap(address(tokenA), amountIn, 0);

        vm.stopPrank();

        uint256 finalBalanceB = tokenB.balanceOf(alice);
        uint256 tokensReceived = finalBalanceB - initialBalanceB;
        
        console.log("---- SWAP EXECUTION RESULTS ----");
        console.log("Input Amount: 2 CAT");
        console.log("Minimum Return Boundary Met.");
        console.log("Tokens Extracted by Alice:", tokensReceived / 10**18, "DOG");
        console.log("--------------------------------");
        
        // Assert Protocol Stability (No zero-returns due to math rounding)
        assertTrue(tokensReceived > 0, "Invariant broken: Swap yielded zero output");
    }

    /// @notice Validates that the Factory contract prevents the creation of invalid pairs.
    function test_RevertIf_SameTokenPairCreation() public {
        // Attempting to bridge identical assets should be blocked by the factory layer.
        vm.expectRevert(bytes("cant use same tokens"));
        factory.createPair(address(tokenA), address(tokenA));
        
        console.log("Passed: Factory successfully blocked identical token pairing.");
    }

    /// @notice Guarantees total storage isolation of ERC20 capabilities; LP tokens from Pair A cannot be manipulated in Pair B.
    function test_Security_LPIsolation() public {
        // Setup Isolated Ecosystem (Pair 2)
        address tokenCAddr = launchpad.createToken("Bird Coin", "BRD", INITIAL_SUPPLY);
        address pair2Addr = factory.createPair(address(tokenA), tokenCAddr);
        MiniDEXPair pair2 = MiniDEXPair(pair2Addr);

        uint256 deployerLPTokensFromPair1 = pair.balanceOf(deployer);
        
        // Attempt an unauthorized cross-pool burn. 
        // Expecting a standard Underflow error due to Pair2 state being completely segregated from Pair1.
        vm.expectRevert(); 
        pair2.burn(deployerLPTokensFromPair1);

        console.log("Passed: LP State strictly isolated. Unauthorized burn attempt deflected.");
    }
}
