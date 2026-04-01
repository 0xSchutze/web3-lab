// ── State ────────────────────────────────────────────────────────────────────
let provider, signer, userAddress;
let factoryContract, vaultContract;
let vaultAddress = null;
let personalVaultAddress = null;
let isOwner = false;
let isManager = false;

// ── Init ─────────────────────────────────────────────────────────────────────
window.addEventListener("load", async () => {
  if (window.ethereum) {
    const accounts = await window.ethereum.request({ method: "eth_accounts" });
    if (accounts.length > 0) {
      connectWallet();
    }
  }
});

document.getElementById("connect-btn").addEventListener("click", connectWallet);

async function connectWallet() {
  if (!window.ethereum) {
    showToast("MetaMask not found. Please install it.", "error");
    return;
  }

  try {
    setBtnLoading("connect-btn", true);

    // Request accounts
    await window.ethereum.request({ method: "eth_requestAccounts" });

    // Check network
    const chainId = await window.ethereum.request({ method: "eth_chainId" });
    if (chainId !== CONFIG.SEPOLIA_CHAIN_ID) {
      try {
        await window.ethereum.request({
          method: "wallet_switchEthereumChain",
          params: [{ chainId: CONFIG.SEPOLIA_CHAIN_ID }],
        });
      } catch {
        showToast("Please switch to Sepolia testnet.", "error");
        setBtnLoading("connect-btn", false);
        return;
      }
    }

    provider = new ethers.BrowserProvider(window.ethereum);
    signer = await provider.getSigner();
    userAddress = await signer.getAddress();

    // Set up factory
    factoryContract = new ethers.Contract(CONFIG.FACTORY_ADDRESS, CONFIG.FACTORY_ABI, signer);

    // Show app
    document.getElementById("connect-screen").style.display = "none";
    document.getElementById("app").style.display = "block";
    document.getElementById("header-address").textContent = shortAddr(userAddress);

    await loadDashboard();

  // Listen for account/network changes (Moved to central init below to avoid duplicate listeners)
  } catch (err) {
    showToast("Connection failed: " + (err.message || err), "error");
  } finally {
    setBtnLoading("connect-btn", false);
  }
}

// Attach global event listeners
if (window.ethereum) {
  window.ethereum.on("accountsChanged", async (accounts) => {
    if (accounts.length === 0) {
      window.location.reload(); // Completely disconnected
    } else {
      if (provider) {
        try {
          // Re-initialize signer with new chosen account
          signer = await provider.getSigner();   
          const newAddress = await signer.getAddress();
          
          if (newAddress.toLowerCase() !== userAddress.toLowerCase()) {
            userAddress = newAddress;
            document.getElementById("header-address").textContent = shortAddr(userAddress);
            
            // Reset state so they don't get stuck in the previous vault
            vaultAddress = null;
            personalVaultAddress = null;
            vaultContract = null;
            
            await loadDashboard();
            showToast("Switched account", "info");
          }
        } catch(e) {
          console.error("Account switch error", e);
        }
      } else {
        window.location.reload();
      }
    }
  });
  window.ethereum.on("chainChanged", () => window.location.reload());
}

document.getElementById("switch-account-btn")?.addEventListener("click", async () => {
  try {
    await window.ethereum.request({
      method: "wallet_requestPermissions",
      params: [{ eth_accounts: {} }]
    });
  } catch (err) {
    if (err.code === 4001) {
      showToast("Account switch cancelled", "info");
    } else {
      showToast("Failed to switch account", "error");
    }
  }
});

// ── Dashboard ─────────────────────────────────────────────────────────────────
async function loadDashboard() {
  try {
    const count = await factoryContract.vaultCount(userAddress);
    
    if (count > 0n) {
      personalVaultAddress = await factoryContract.getVaultByOwner();
    } else {
      personalVaultAddress = null;
    }

    if (count === 0n && !vaultAddress) {
      document.getElementById("no-vault-section").style.display = "flex";
      document.getElementById("vault-section").style.display = "none";
    } else {
      if (!vaultAddress) vaultAddress = personalVaultAddress;
      
      vaultContract = new ethers.Contract(vaultAddress, CONFIG.VAULT_ABI, signer);

      document.getElementById("no-vault-section").style.display = "none";
      document.getElementById("vault-section").style.display = "flex";

      await refreshVaultData();
    }
  } catch (err) {
    showToast("Failed to load dashboard.", "error");
    console.error(err);
  }
}

async function refreshVaultData() {
  if (!vaultContract) return;

  const [ethBalance, owner, paused, isUserApproved] = await Promise.all([
    vaultContract.getBalance(),
    vaultContract.owner(),
    vaultContract.paused(),
    vaultContract.approvedAddress(userAddress),
  ]);

  isOwner = owner.toLowerCase() === userAddress.toLowerCase();
  isManager = isUserApproved;

  // Header vault info
  const link = document.getElementById("vault-etherscan-link");
  link.href = `https://sepolia.etherscan.io/address/${vaultAddress}`;
  link.textContent = shortAddr(vaultAddress);

  // Pause status
  const pauseStatus = document.getElementById("pause-status");
  pauseStatus.className = `pause-status ${paused ? "paused" : "active"}`;
  pauseStatus.innerHTML = paused ? "⏸ Paused" : "✅ Active";

  // Stats
  document.getElementById("stat-eth").textContent = formatEth(ethBalance) + " ETH";
  document.getElementById("stat-vault").textContent = shortAddr(vaultAddress);
  
  // Always display the true owner address
  document.getElementById("stat-owner").innerHTML = `<span class="mono-text">${shortAddr(owner)}</span>`;
  
  // Display the user's role on this contract
  let roleTag = "";
  if (isOwner) {
    roleTag = '<span class="owner-badge">⚡ Owner</span>';
  } else if (isManager) {
    roleTag = '<span class="owner-badge" style="color: #38bdf8; background: rgba(56, 189, 248, 0.15);">💼 Manager</span>';
  } else {
    roleTag = '<span class="owner-badge" style="color: #a1a1aa; border-color: rgba(255,255,255,0.1); background: rgba(0,0,0,0.3);">👁️ Guest</span>';
  }
  document.getElementById("stat-role").innerHTML = roleTag;
  
  // Guest Notice
  const guestNotice = document.getElementById("guest-notice");
  if (guestNotice) {
    guestNotice.style.display = (!isOwner && !isManager) ? "block" : "none";
  }
  
  document.getElementById("stat-paused").textContent = paused ? "Paused" : "Running";

  // Role visibility sections
  document.querySelectorAll(".owner-only").forEach((el) => {
    el.style.display = isOwner ? "" : "none";
  });
  document.querySelectorAll(".manager-access").forEach((el) => {
    el.style.display = (isOwner || isManager) ? "" : "none";
  });
  
  // Context Switcher logic
  const homeBtn = document.getElementById("return-my-vault-btn");
  if (homeBtn) {
    if (personalVaultAddress && personalVaultAddress.toLowerCase() !== vaultAddress.toLowerCase()) {
      homeBtn.style.display = "inline-flex";
    } else {
      homeBtn.style.display = "none";
    }
  }
}

// ── Create Vault ─────────────────────────────────────────────────────────────
document.getElementById("create-vault-btn").addEventListener("click", async () => {
  try {
    setBtnLoading("create-vault-btn", true);
    const tx = await factoryContract.createVault();
    showToast("Creating vault... waiting for confirmation", "info");
    await tx.wait();
    showToast("Vault created successfully! 🎉", "success");
    await loadDashboard();
  } catch (err) {
    showToast(parseError(err), "error");
  } finally {
    setBtnLoading("create-vault-btn", false);
  }
});

// ── Connect External Vault ───────────────────────────────────────────────────
async function loadCustomVault(addrInputId, btnId) {
  const addr = document.getElementById(addrInputId).value.trim();
  if (!ethers.isAddress(addr)) {
    showToast("Invalid vault address", "error");
    return;
  }
  try {
    setBtnLoading(btnId, true);
    // Verify it's actually a vault
    const testContract = new ethers.Contract(addr, CONFIG.VAULT_ABI, provider);
    await testContract.owner(); 
    
    vaultAddress = addr;
    vaultContract = new ethers.Contract(vaultAddress, CONFIG.VAULT_ABI, signer);
    
    document.getElementById("no-vault-section").style.display = "none";
    document.getElementById("vault-section").style.display = "flex";
    
    await refreshVaultData();
    document.getElementById(addrInputId).value = "";
    showToast("Connected to vault ✅", "success");
  } catch (err) {
    showToast("Contract is not a valid Vault", "error");
  } finally {
    setBtnLoading(btnId, false);
  }
}

document.getElementById("load-external-btn")?.addEventListener("click", () => loadCustomVault("external-vault-addr", "load-external-btn"));
document.getElementById("dashboard-load-external-btn")?.addEventListener("click", () => loadCustomVault("dashboard-external-addr", "dashboard-load-external-btn"));

document.getElementById("return-my-vault-btn")?.addEventListener("click", async () => {
    if (personalVaultAddress) {
       document.getElementById("dashboard-external-addr").value = personalVaultAddress;
       await loadCustomVault("dashboard-external-addr", "return-my-vault-btn");
       document.getElementById("dashboard-external-addr").value = "";
    }
});



// ── Deposit ETH ──────────────────────────────────────────────────────────────
document.getElementById("deposit-eth-btn").addEventListener("click", async () => {
  const amount = document.getElementById("deposit-eth-amount").value;
  if (!amount || isNaN(amount) || parseFloat(amount) < 0.01) {
    showToast("Minimum deposit is 0.01 ETH", "error");
    return;
  }
  try {
    setBtnLoading("deposit-eth-btn", true);
    const tx = await vaultContract.depositEth({ value: ethers.parseEther(amount) });
    showToast("Depositing ETH...", "info");
    await tx.wait();
    showToast(`Deposited ${amount} ETH ✅`, "success");
    document.getElementById("deposit-eth-amount").value = "";
    await refreshVaultData();
  } catch (err) {
    showToast(parseError(err), "error");
  } finally {
    setBtnLoading("deposit-eth-btn", false);
  }
});

// ── Deposit Token ─────────────────────────────────────────────────────────────
document.getElementById("approve-token-btn").addEventListener("click", async () => {
  const tokenAddr = document.getElementById("deposit-token-address").value.trim();
  const amount = document.getElementById("deposit-token-amount").value;
  if (!ethers.isAddress(tokenAddr)) {
    showToast("Invalid token address", "error");
    return;
  }
  try {
    setBtnLoading("approve-token-btn", true);
    const erc20 = new ethers.Contract(tokenAddr, CONFIG.ERC20_ABI, signer);
    const decimals = await erc20.decimals();
    const parsed = ethers.parseUnits(amount, decimals);
    const tx = await erc20.approve(vaultAddress, parsed);
    showToast("Approving token spend...", "info");
    await tx.wait();
    showToast("Approved! Now click Deposit.", "success");
  } catch (err) {
    showToast(parseError(err), "error");
  } finally {
    setBtnLoading("approve-token-btn", false);
  }
});

document.getElementById("deposit-token-btn").addEventListener("click", async () => {
  const tokenAddr = document.getElementById("deposit-token-address").value.trim();
  const amount = document.getElementById("deposit-token-amount").value;
  if (!ethers.isAddress(tokenAddr) || !amount) {
    showToast("Fill in token address and amount", "error");
    return;
  }
  try {
    setBtnLoading("deposit-token-btn", true);
    const erc20 = new ethers.Contract(tokenAddr, CONFIG.ERC20_ABI, signer);
    const decimals = await erc20.decimals();
    const parsed = ethers.parseUnits(amount, decimals);
    const tx = await vaultContract.depositToken(tokenAddr, parsed);
    showToast("Depositing token...", "info");
    await tx.wait();
    showToast("Token deposited ✅", "success");
    document.getElementById("deposit-token-address").value = "";
    document.getElementById("deposit-token-amount").value = "";
  } catch (err) {
    showToast(parseError(err), "error");
  } finally {
    setBtnLoading("deposit-token-btn", false);
  }
});

// ── Withdraw ETH ─────────────────────────────────────────────────────────────
document.getElementById("withdraw-eth-btn").addEventListener("click", async () => {
  const amount = document.getElementById("withdraw-eth-amount").value;
  if (!amount || parseFloat(amount) < 0.01) {
    showToast("Minimum withdrawal is 0.01 ETH", "error");
    return;
  }
  try {
    setBtnLoading("withdraw-eth-btn", true);
    const tx = await vaultContract.withdrawEth(ethers.parseEther(amount));
    showToast("Withdrawing ETH...", "info");
    await tx.wait();
    showToast(`Withdrew ${amount} ETH ✅`, "success");
    document.getElementById("withdraw-eth-amount").value = "";
    await refreshVaultData();
  } catch (err) {
    showToast(parseError(err), "error");
  } finally {
    setBtnLoading("withdraw-eth-btn", false);
  }
});

// ── Withdraw Token ────────────────────────────────────────────────────────────
document.getElementById("withdraw-token-btn").addEventListener("click", async () => {
  const tokenAddr = document.getElementById("withdraw-token-address").value.trim();
  const amount = document.getElementById("withdraw-token-amount").value;
  if (!ethers.isAddress(tokenAddr) || !amount) {
    showToast("Fill in token address and amount", "error");
    return;
  }
  try {
    setBtnLoading("withdraw-token-btn", true);
    const erc20 = new ethers.Contract(tokenAddr, CONFIG.ERC20_ABI, signer);
    const decimals = await erc20.decimals();
    const parsed = ethers.parseUnits(amount, decimals);
    const tx = await vaultContract.withdrawToken(tokenAddr, parsed);
    showToast("Withdrawing token...", "info");
    await tx.wait();
    showToast("Token withdrawn ✅", "success");
    document.getElementById("withdraw-token-address").value = "";
    document.getElementById("withdraw-token-amount").value = "";
  } catch (err) {
    showToast(parseError(err), "error");
  } finally {
    setBtnLoading("withdraw-token-btn", false);
  }
});

// ── Check Token Balance ───────────────────────────────────────────────────────
document.getElementById("check-token-btn").addEventListener("click", async () => {
  const addr = document.getElementById("withdraw-token-address").value.trim();
  if (!ethers.isAddress(addr)) {
    showToast("Enter a valid token address first", "error");
    return;
  }
  try {
    const bal = await vaultContract.getTokenBalance(addr);
    const erc20 = new ethers.Contract(addr, CONFIG.ERC20_ABI, provider);
    const [decimals, symbol] = await Promise.all([erc20.decimals(), erc20.symbol()]);
    showToast(`Vault has ${ethers.formatUnits(bal, decimals)} ${symbol}`, "info");
  } catch {
    const bal = await vaultContract.getTokenBalance(addr);
    showToast(`Vault balance: ${bal.toString()} units`, "info");
  }
});

// ── Whitelist ─────────────────────────────────────────────────────────────────
document.getElementById("add-whitelist-btn").addEventListener("click", async () => {
  const addr = document.getElementById("whitelist-token-input").value.trim();
  if (!ethers.isAddress(addr)) {
    showToast("Invalid token address", "error");
    return;
  }
  try {
    setBtnLoading("add-whitelist-btn", true);
    const tx = await vaultContract.addTokenToWhitelist(addr);
    showToast("Adding to whitelist...", "info");
    await tx.wait();
    showToast("Token whitelisted ✅", "success");
    document.getElementById("whitelist-token-input").value = "";
  } catch (err) {
    showToast(parseError(err), "error");
  } finally {
    setBtnLoading("add-whitelist-btn", false);
  }
});

document.getElementById("remove-whitelist-btn").addEventListener("click", async () => {
  const addr = document.getElementById("whitelist-token-input").value.trim();
  if (!ethers.isAddress(addr)) {
    showToast("Invalid token address", "error");
    return;
  }
  try {
    setBtnLoading("remove-whitelist-btn", true);
    const tx = await vaultContract.removeTokenFromWhitelist(addr);
    showToast("Removing from whitelist...", "info");
    await tx.wait();
    showToast("Token removed ✅", "success");
    document.getElementById("whitelist-token-input").value = "";
  } catch (err) {
    showToast(parseError(err), "error");
  } finally {
    setBtnLoading("remove-whitelist-btn", false);
  }
});

document.getElementById("check-whitelist-btn").addEventListener("click", async () => {
  const addr = document.getElementById("whitelist-token-input").value.trim();
  if (!ethers.isAddress(addr)) {
    showToast("Invalid token address", "error");
    return;
  }
  const allowed = await vaultContract.allowedTokens(addr);
  showToast(allowed ? "✅ Token is whitelisted" : "❌ Token is NOT whitelisted", allowed ? "success" : "error");
});

// ── Settings ──────────────────────────────────────────────────────────────────
document.getElementById("approve-addr-btn").addEventListener("click", async () => {
  const addr = document.getElementById("authorize-address-input").value.trim();
  if (!ethers.isAddress(addr)) {
    showToast("Invalid address", "error");
    return;
  }
  try {
    setBtnLoading("approve-addr-btn", true);
    const tx = await vaultContract.approveAddress(addr);
    showToast("Authorizing address...", "info");
    await tx.wait();
    showToast("Address authorized ✅", "success");
    document.getElementById("authorize-address-input").value = "";
  } catch (err) {
    showToast(parseError(err), "error");
  } finally {
    setBtnLoading("approve-addr-btn", false);
  }
});

document.getElementById("remove-addr-btn").addEventListener("click", async () => {
  const addr = document.getElementById("authorize-address-input").value.trim();
  if (!ethers.isAddress(addr)) {
    showToast("Invalid address", "error");
    return;
  }
  try {
    setBtnLoading("remove-addr-btn", true);
    const tx = await vaultContract.removeApproval(addr);
    showToast("Removing authorization...", "info");
    await tx.wait();
    showToast("Authorization removed ✅", "success");
    document.getElementById("authorize-address-input").value = "";
  } catch (err) {
    showToast(parseError(err), "error");
  } finally {
    setBtnLoading("remove-addr-btn", false);
  }
});

document.getElementById("pause-btn").addEventListener("click", async () => {
  try {
    setBtnLoading("pause-btn", true);
    const tx = await vaultContract.pause();
    showToast("Pausing vault...", "info");
    await tx.wait();
    showToast("Vault paused ✅", "success");
    await refreshVaultData();
  } catch (err) {
    showToast(parseError(err), "error");
  } finally {
    setBtnLoading("pause-btn", false);
  }
});

document.getElementById("unpause-btn").addEventListener("click", async () => {
  try {
    setBtnLoading("unpause-btn", true);
    const tx = await vaultContract.unpause();
    showToast("Unpausing vault...", "info");
    await tx.wait();
    showToast("Vault unpaused ✅", "success");
    await refreshVaultData();
  } catch (err) {
    showToast(parseError(err), "error");
  } finally {
    setBtnLoading("unpause-btn", false);
  }
});

document.getElementById("transfer-ownership-btn").addEventListener("click", async () => {
  const addr = document.getElementById("new-owner-input").value.trim();
  if (!ethers.isAddress(addr)) {
    showToast("Invalid address", "error");
    return;
  }
  if (!confirm(`Transfer ownership to ${addr}? This cannot be undone.`)) return;
  try {
    setBtnLoading("transfer-ownership-btn", true);
    const tx = await vaultContract.transferOwnership(addr);
    showToast("Transferring ownership...", "info");
    await tx.wait();
    showToast("Ownership transferred ✅", "success");
    await refreshVaultData();
  } catch (err) {
    showToast(parseError(err), "error");
  } finally {
    setBtnLoading("transfer-ownership-btn", false);
  }
});

// ── Helpers ───────────────────────────────────────────────────────────────────
function shortAddr(addr) {
  return addr.slice(0, 6) + "..." + addr.slice(-4);
}

function formatEth(wei) {
  return parseFloat(ethers.formatEther(wei)).toFixed(4);
}

function parseError(err) {
  if (err?.reason) return err.reason;
  if (err?.message) {
    const m = err.message;
    const revert = m.match(/reverted with reason string '(.+?)'/);
    if (revert) return revert[1];
    if (m.includes("user rejected")) return "Transaction rejected";
    return m.slice(0, 80);
  }
  return "Unknown error";
}


