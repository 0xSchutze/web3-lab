// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Protocol Math Library
 * @author 0xSchutze / Web3 Security Lab
 * @notice Provides standard mathematical utilities for the AMM invariant routing.
 * @dev Includes safe Babylonian method for square root calculation.
 */
library Math {

    /**
     * @notice Returns the smaller of two unsigned integers.
     * @param x First integer.
     * @param y Second integer.
     * @return z The smaller integer.
     */
    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }

    /**
     * @notice Calculates the square root of a given EVM integer using the Babylonian computation method.
     * @param y The integer to calculate the square root for.
     * @return z The calculated square root outcome.
     */
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
