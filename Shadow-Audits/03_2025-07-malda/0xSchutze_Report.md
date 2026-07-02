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