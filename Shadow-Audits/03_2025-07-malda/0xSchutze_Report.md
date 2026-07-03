# 0xSchutze - Malda Protocol Shadow Audit Report

## 1. Introduction & Scope
- **Protocol:** Malda (Lending & Rebalancer)
- **Audit Type:** Shadow Audit (Reverse Engineering & Independent Verification)
- **Researcher:** 0xSchutze

This report contains independent discoveries and reverse-engineered proofs of concept from a time-boxed Shadow Audit.

## 2. My Discoveries (Independent Findings)
*Note: During the initial 3.5-hour reconnaissance phase, 11 architectural hypotheses were formulated. However, strict QA verification concluded that none of them constituted valid High/Medium vulnerabilities. The misses were directly attributed to a lack of domain knowledge regarding Lending Protocol primitives (`_doTransferIn` mechanics) and Intent-Based Bridge APIs (Everclear). Therefore, no independent findings are claimed in this report.*

## 3. Assimilated Discoveries (Reverse-Engineered Findings)

### [H-01] Rebalancer can steal funds from markets by sending to custom receiver through Everclear Bridge
**Description & Business Impact:**
The `EverclearBridge` contract accepts an arbitrary `_message` payload from the `Rebalancer` and decodes it into an `IntentParams` struct via `_decodeIntent`. While the bridge validates the input token, extracted amount, and destination chain ID, it completely fails to validate or enforce the `receiver` address. 

Because this raw payload is directly forwarded to the Everclear `FeeAdapter.newIntent()` function, an attacker holding the `REBALANCER_EOA` role can construct a malicious payload where the `receiver` parameter is set to their own address instead of the legitimate destination market. 

**Business Impact:**
A malicious or compromised Rebalancer can successfully extract liquidity from the protocol's markets (`mToken` instances) and bridge it directly to an external, attacker-controlled address on the destination chain, resulting in a total loss of the rebalanced funds.

**Retrospective / Missed Vector:**
While reviewing `EverclearBridge.sol`, I noticed the low-level data slicing into `IntentParams` and unfamiliar parameters like `ttl` and `maxFee`. I deduced that `newIntent()` takes the fee and emits this payload for the rest of the process to continue off-chain. Because I did not know how the off-chain system operated, I incorrectly assumed it would safely handle the data. I did not stop analyzing the on-chain code, but I completely failed to consider that the `receiver` parameter itself could be manipulated during payload construction to redirect the funds.

**Proof of Concept (Foundry):**
**Full Executable PoC:** [01_Malda_H01_PoC.t.sol](PoCs/01_Malda_H01_PoC.t.sol)

**Exploit Payload Injection:**
```solidity
        // 5. Construct the malicious payload
        uint32[] memory destinations = new uint32[](1);
        destinations[0] = 1;
        bytes32 maliciousReceiver = bytes32(uint256(uint160(alice))); // Attacker Address

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
```

---

### [M-15] If Across Bridging fails, all funds intended for bridging will become locked
**Description & Business Impact:**
The `AcrossBridge._depositV3Now` function calls `IAcrossSpokePoolV3.depositV3Now()` with `msg.sender` (the `Rebalancer` contract) as the `depositor` parameter. In the Across V3 protocol, the `depositor` address is the designated recipient for refunds when a cross-chain fill fails (e.g., due to relayer liquidity shortage, fill deadline expiration, or token mismatch on the destination chain).

When the destination-chain delivery reverts, Across refunds the locked tokens on the source chain directly to the `depositor` address — the `Rebalancer` contract. However, the `Rebalancer` contract contains no `sweep()`, `rescue()`, `withdraw()`, or any other mechanism to extract ERC20 tokens sent directly to it. It can only interact with market liquidity through `extractForRebalancing`, not recover arbitrary token balances.

**Business Impact:**
All funds involved in any failed cross-chain rebalancing operation via AcrossBridge are permanently and irrecoverably locked inside the Rebalancer contract. Given that rebalancing operations move protocol-owned liquidity (potentially thousands of ETH or millions in stablecoins per transaction), a single failed bridge operation can result in catastrophic, unrecoverable loss of protocol funds.

**Retrospective / Missed Vector:**
I did not consider what happens if the transaction reverts on the destination chain; the failure state did not cross my mind. Consequently, I did not check the refund routing and missed that refunded assets are returned to the Rebalancer, which has no sweep mechanism, permanently locking them.

**Proof of Concept (Foundry):**
**Full Executable PoC:** [02_Malda_M15_PoC.t.sol](PoCs/02_Malda_M15_PoC.t.sol)

This PoC implements a full multi-chain simulation (Linea ↔ Base) with three custom contracts:
- `SpokePool`: Simulates the Across V3 SpokePool on both chains (deposit, delivery, refund)
- `SimulateOffChainBot`: Replaces off-chain relayer logic with deterministic event-driven routing
- The test triggers a single `rebalancer.sendMsg()` call that cascades through the entire flow:

```solidity
    // Act — A single sendMsg triggers the entire cross-chain flow:
    // Linea Rebalancer -> Linea AcrossBridge -> Linea SpokePool (deposit + lock)
    // -> Off-chain Bot -> Base SpokePool (delivery attempt with wrong token -> revert)
    // -> Off-chain Bot -> Linea SpokePool (refund to depositor = Rebalancer)
    vm.prank(address(simulateOffChainBot));
    rebalancerLinea.sendMsg(address(acrossBridgeLinea), address(mWethHost), 5000e18, sendMsgFinalMessage);

    // Assert — 5000 WETH is now trapped inside the Rebalancer with no way to extract it.
    assertEq(
        IERC20(address(weth)).balanceOf(address(rebalancerLinea)),
        5000e18,
        "Refunded tokens permanently locked in Rebalancer"
    );
```

---

### [M-06] EverclearBridge does not pull tokens from the Rebalancer, causing all rebalancing operations to fail
**Description & Business Impact:**
The `EverclearBridge.sendMsg` function is responsible for receiving rebalancing tokens from the `Rebalancer` contract and passing them to the Everclear `FeeAdapter.newIntent()` function to initiate a cross-chain transfer. However, the `sendMsg` implementation completely omits the critical step of pulling the `_token` from the `Rebalancer` via `transferFrom()`.

Because the bridge never receives the tokens, its internal balance remains zero. Consequently, when the function attempts to either return slippage via `IERC20(_token).safeTransfer(_market, toReturn)` or when the Everclear `FeeAdapter` attempts to pull the tokens for intent creation, the operation will inevitably revert with an `ERC20InsufficientBalance` error.

**Business Impact:**
The integration with the Everclear protocol is completely broken. Any attempt to use `EverclearBridge` for cross-chain rebalancing will result in a 100% revert rate (Denial of Service). Since bridging is a core mechanism for maintaining cross-chain liquidity health, this prevents the protocol from moving assets effectively when using Everclear.

**Retrospective / Missed Vector:**
I misread the code. I saw the `safeTransfer` used for the slippage refund and incorrectly assumed it was a `transferFrom` pulling core funds from the market. Because of this error, I missed that the bridge never actually extracts `params.amount` from the Rebalancer, guaranteeing a revert.

**Proof of Concept (Foundry):**
**Full Executable PoC:** [03_Malda_M06_PoC.t.sol](PoCs/03_Malda_M06_PoC.t.sol)

The PoC contains two distinct tests proving that the bridge is broken under all conditions:
1. `test_M06_DoS_WithSlippageRefund()`: Reverts immediately at the `safeTransfer` step if the extracted amount is greater than the params amount.
2. `test_M06_DoS_WithoutSlippage()`: Reverts at the `transferFrom` step inside the `FeeAdapter` when there is no slippage refund.

```solidity
    // Act & Assert
    // We set extractedAmount to 1000e18, matching params.amount exactly.
    // The slippage logic is skipped, but FeeAdapter.newIntent() will attempt to pull 1000e18.
    // It will revert with ERC20InsufficientBalance because the bridge holds 0 WETH.
    vm.expectRevert();
    rebalancer.sendMsg(address(everclearBridge), address(mWethHost), 1000e18, exploitMessage);
```

---

### [M-04] Blacklist can be completely bypassed on outHere endpoint in mTokenGateway
**Description & Business Impact:**
The `mTokenGateway.outHere` function verifies that both the `msg.sender` and the `receiver` parameter are not blacklisted via the `ifNotBlacklisted` modifier. However, inside the internal `_outHere` function, the `receiver` parameter is explicitly overwritten with the original `_sender` (the user who supplied the funds on the source chain) on line 286: `receiver = _sender;`.

Furthermore, the `_checkSender` function allows an unprivileged caller to execute the withdrawal on behalf of the original `_sender` if the original `_sender` has delegated authority to them via `updateAllowedCallerStatus()`. Critically, `updateAllowedCallerStatus()` does not check if `msg.sender` is blacklisted.

Therefore, a blacklisted user can easily bypass the modifiers by granting `allowedCallers` status to a secondary, clean wallet. The clean wallet then calls `outHere`. Both modifiers pass successfully, but the funds are transferred directly to the blacklisted user's address because `receiver` is overwritten with the blacklisted `_sender`.

**Business Impact:**
The entire blacklist mechanism on the withdrawal flow is completely ineffective. Malicious actors, OFAC-sanctioned addresses, or compromised wallets that are explicitly flagged by the protocol's Guardian can still extract their funds at will by proxying the transaction through a clean address.

**Retrospective / Missed Vector:**
While analyzing `mTokenGateway.sol`, I specifically reviewed the `updateAllowedCallerStatus` mechanism and the access modifiers. However, I analyzed these components in isolation. I failed to connect the `allowedCallers` delegation feature with the `outHere` withdrawal endpoint. Because `outHere` overwrites the `receiver` parameter internally, a blacklisted user can simply use `allowedCallers` to authorize a clean address to execute the withdrawal on their behalf, completely bypassing the `ifNotBlacklisted` checks. I read the code, but I did not simulate the attacker's execution path.

**Proof of Concept (Foundry):**
**Full Executable PoC:** [04_Malda_M04_PoC.t.sol](PoCs/04_Malda_M04_PoC.t.sol)

The PoC demonstrates an unprivileged bypass where a blacklisted Alice delegates to a clean wallet to extract her funds:

```solidity
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
```
