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