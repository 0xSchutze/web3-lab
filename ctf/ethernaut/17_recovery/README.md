# Level 17: Recovery

**Target:** [Recovery.sol](./Recovery.sol)

## Vulnerability

No code vulnerability in the traditional sense — this is an **on-chain forensics** challenge. A factory contract (`Recovery`) created a `SimpleToken` contract via `new`, and the deployer lost track of the child contract's address. The child contract holds 0.001 ETH and exposes a public `destroy()` function that calls `selfdestruct`.

## Key Concepts

**Deterministic address derivation:** Contract addresses created via `CREATE` (not `CREATE2`) are deterministic and computed as:
```
address = keccak256(RLP_encode(deployer_address, nonce))[12:]
```

For a contract's first `CREATE` operation, the nonce is `1`. The RLP encoding prefix for a 20-byte address is `0xd694`, and a single-byte nonce of 1 is `0x01`.

**OSINT approach:** Alternatively, the lost address can be found by inspecting the factory contract's internal transactions on a block explorer (e.g., Etherscan) — the `CREATE` operation is logged as an internal transaction showing the child contract's address.

## Root Cause

The `SimpleToken` contract exposes an unrestricted `destroy()` function — anyone can call `selfdestruct` and drain the contract's ETH balance to any address. Combined with the deterministic nature of contract addresses, the "lost" address is trivially recoverable.

## Exploit

Compute the child contract address via RLP encoding and call `destroy()`:

```solidity
address factory = 0xa496A137800e7Be949a725E5F5d5C2E3FB78Eb53;

// RLP Encoding: (0xd6, 0x94) + factory_address + nonce (0x01)
address lostContract = address(uint160(uint256(keccak256(
    abi.encodePacked(bytes1(0xd6), bytes1(0x94), factory, bytes1(0x01))
))));

IExploit(lostContract).destroy(payable(msg.sender));
```

## Real-World Reference

Deterministic address computation is fundamental to counterfactual deployment patterns used by account abstraction (ERC-4337) and `CREATE2` factory contracts (e.g., Uniswap V2/V3 pair addresses). Understanding RLP encoding and address derivation is essential for on-chain forensics, MEV searching, and front-running detection — attackers often pre-compute deployment addresses to front-run contract creation with malicious interactions.
