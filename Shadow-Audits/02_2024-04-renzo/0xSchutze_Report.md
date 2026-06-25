# 0xSchutze - Renzo Protocol Shadow Audit Report

## 1. Introduction & Scope
- **Protocol:** Renzo Protocol (2024-04-renzo)
- **Audit Type:** Shadow Audit (Reverse Engineering & Independent Verification)
- **Researcher:** 0xSchutze

This report contains independent discoveries and reverse-engineered proofs of concept (PoCs) for vulnerabilities found within the Renzo Protocol smart contracts. The methodology involves an initial independent manual audit (Deep Focus) followed by a detailed assimilation of the official Code4rena findings.

---

## 2. My Discoveries (Independent Findings)
*This section contains vulnerabilities that I independently discovered and validated prior to reading the official report.*

### [M-09] Deposits will always revert if the amount being deposited is less than the bufferToFill value

**Description & Business Impact:**
In `RestakeManager.sol`, the `deposit` function checks if the withdrawal buffer is below its target. If there is a deficit (`bufferToFill > 0`), the code attempts to route the deposited `_amount` to fill the buffer. However, the ternary operation `bufferToFill = (_amount <= bufferToFill) ? _amount : bufferToFill;` restricts the fill amount, followed by `_amount -= bufferToFill;`. 

If the deposited amount is less than or equal to the deficit, `_amount` is reduced to `0`. The execution then calls `operatorDelegator.deposit(_collateralToken, _amount)` with a `0` value. Inside `OperatorDelegator.sol`, the `deposit` function contains a strict check: `if (tokenAmount == 0) revert InvalidZeroInput();`.
This mathematical reduction leads to a complete Denial of Service (DoS) for all deposits that are smaller than the current withdrawal buffer deficit, locking out retail/small depositors until a whale deposit clears the deficit.

**Proof of Concept (Foundry):**
The complete executable PoC can be found in [`PoCs/01_Renzo_M09_PoC.t.sol`](./PoCs/01_Renzo_M09_PoC.t.sol).
Below is the core exploit execution demonstrating the denial of service:

```solidity
    /// @notice Proves that depositing exactly the deficit amount triggers a denial of service (revert).
    function test_DepositReverts_WhenAmountEqDeficit() public {
        setupBufferDeficit();
        uint256 depositAmount = deficit;
        
        vm.startPrank(OWNER);
        stETH.mint(alice, depositAmount);
        vm.stopPrank();

        vm.startPrank(alice);
        stETH.approve(address(restakeManager), type(uint256).max);

        // The deposit logic reduces the input amount by the buffer deficit. 
        // Because depositAmount == deficit, the net amount becomes 0, triggering the revert.
        vm.expectRevert(InvalidZeroInput.selector);
        restakeManager.deposit(IERC20(address(stETH)), depositAmount);
        vm.stopPrank();
    }
```

---

### [H-03] Native ETH withdrawals from EigenLayer permanently bricked due to overlapping nonReentrant locks

**Description & Business Impact:**
During the execution of `OperatorDelegator.completeQueuedWithdrawal()`, the contract enters a `nonReentrant` lock. This function delegates the withdrawal execution to EigenLayer's `DelegationManager`. Upon processing, EigenLayer pushes the native ETH back to the corresponding `EigenPod`, which immediately forwards it to the `OperatorDelegator`'s `receive()` function.
However, the `receive()` function is also protected by the `nonReentrant` modifier. Since the transaction originated from a function that already acquired the ReentrancyGuard lock (`_status == _ENTERED`), the callback predictably reverts with `"ReentrancyGuard: reentrant call"`. 
This results in a permanent Denial of Service (DoS) for all queued native ETH withdrawals, locking user funds indefinitely within EigenLayer.

**Proof of Concept (Foundry):**
The complete executable PoC can be found in [`PoCs/02_Renzo_H03_PoC.t.sol`](./PoCs/02_Renzo_H03_PoC.t.sol).
Below is the core exploit execution demonstrating the ReentrancyGuard brick:

```solidity
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
```

---

## 3. Assimilated Discoveries (Reverse-Engineered Findings)
*This section contains critical/medium vulnerabilities from the official report that I initially missed or left for the assimilation phase. I will reverse-engineer the root causes and write my own original Foundry PoCs to demonstrate the exploits.*

