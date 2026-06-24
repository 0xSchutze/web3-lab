# Mini Vault Protocol

A lightweight multi-asset treasury vault protocol built in Solidity for educational purposes.

> ⚠️ **Educational & Experimental**
> This protocol is built for **learning purposes only**. It has **not been audited**. Do not use with real funds. Bugs and vulnerabilities may exist.

---

## Overview

The protocol consists of two contracts:

| Contract | Description |
|---|---|
| `Vault.sol` | A personal treasury vault supporting ETH and ERC20 deposits. Anyone can deposit, only the owner can withdraw. |
| `VaultFactory.sol` | Deploys and tracks individual Vault instances. Each address can own one vault. |

---

## Features

- ETH and ERC20 token deposits
- Token whitelist (only approved tokens accepted)
- Pause / unpause functionality for emergencies
- Authorized address management (max 3 per vault)
- Ownership transfer with automatic authorization cleanup
- One vault per address enforced by factory
- NatSpec documentation

---

## Project Structure

```
src/
├── Vault.sol           # Core vault contract
├── VaultFactory.sol    # Factory for deploying vaults
└── IERC20.sol          # Minimal ERC20 interface

script/
└── DeployVault.s.sol   # Foundry deploy script

test/                   # Tests (WIP)
```

---

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Install

```bash
git clone https://github.com/0xSchutze/web3-lab.git
cd web3-lab/contracts/02_mini-vault-protocol
forge install foundry-rs/forge-std
```

### Build

```bash
forge build
```

### Test

```bash
forge test
```

### Deploy to Sepolia

**Option A — Using `.env` file:**

Create a `.env` file (never commit this):
```
PRIVATE_KEY=your_private_key
SEPOLIA_RPC_URL=your_alchemy_or_infura_url
```

Then run:
```bash
source .env
forge script script/DeployVault.s.sol:DeployVaultFactory \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

**Option B — Directly in terminal (no .env):**
```bash
forge script script/DeployVault.s.sol:DeployVaultFactory \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY \
  --private-key 0xYOUR_PRIVATE_KEY \
  --broadcast \
  --verify
```

---

## How It Works

1. Deploy `VaultFactory` (one-time)
2. Call `createVault()` — deploys a unique `Vault` for the caller
3. Whitelist tokens via `addTokenToWhitelist(tokenAddress)`
4. Anyone can deposit ETH via `depositEth()` or tokens via `depositToken()`
5. Owner withdraws via `withdrawEth()` or `withdrawToken()`

---

## Frontend Integration (dApp)

A full **Vanilla JS / GSAP** frontend is included in the `frontend/` directory to interact with the deployed vaults.

### Live Demo & Smart Contracts
The currently deployed version of the protocol runs on Sepolia and can be accessed directly without any installation:
- **[View Live on GitHub Pages](https://0xschutze.github.io/web3-lab/contracts/02_mini-vault-protocol/frontend/index.html)** *(Example Link)*
- **[View VaultFactory on Sepolia Etherscan](https://sepolia.etherscan.io/address/0xfc5A57AB765Da9980d1E6E244F173BF6AfC3f286)**

### Running Locally
To run the front-end interface on your local machine, simply serve the static files:
```bash
cd frontend
npx serve .
# Or use python: python3 -m http.server 8000
```
By default, the UI will connect to the official Sepolia Factory contract deployed by the author.

### Connecting Custom Smart Contracts
If you modify the smart contracts and deploy your own versions to a network (like Anvil, Sepolia, or Mainnet), you must update the application to point to your new contracts:
1. Open `frontend/config.js`
2. Update the `FACTORY_ADDRESS` variable with your newly deployed VaultFactory address.
3. If you changed the Solidity code, make sure to update `FACTORY_ABI` and `VAULT_ABI` with the newly compiled ABI artifacts.

---

## Architecture Trade-offs & Limitations

**1. Factory State Inconsistency**: The `VaultFactory` tracks the initial deployer of each `Vault`, but does not track ownership transfers (`transferOwnership`) done directly on the `Vault` contract. This means the Factory's internal mapping becomes outdated upon transfer.

**2. Frontend Workaround**: Because the `VaultFactory` state is not updated on secondary transfers, the included frontend requires users to manually input the Vault address they want to load. The frontend independently reads the chain to verify the connected user's role (`Owner`, `Manager`, or `Guest`), working around the Factory's incomplete state tracking.

---

## Security Notes

- This contract is **unaudited** — use at your own risk
- No formal verification has been performed
- Intended for Sepolia testnet only
- Private key management is the responsibility of the deployer

---

## Author

**0xSchutze**
