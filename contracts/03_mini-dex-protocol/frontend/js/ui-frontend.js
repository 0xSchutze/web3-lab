/**
 * 
 * Tx History, Copy-to-Clipboard, Price Impact, Balance+MAX,
 * Pool Share %, Explorer Full-Width, Detail Modals, Analytics Engine
 */

document.addEventListener("DOMContentLoaded", async () => {

    // Core State
    let isAuthenticated = false;
    let cachedTokens = [];
    let cachedPairs = [];

    let currentModalTarget = null;
    let selectedTokens = {
        'swap-in': null,
        'swap-out': null,
        'factory-0': null, // Asset A
        'factory-1': null, // Asset B
        'pool-pair': null, // Active Pair for LP Provision
        'pool-remove': null // Active Pair for LP Extraction
    };

    let activeSwapRouteData = null;
    let currentPoolRatio = { r0: 0n, r1: 0n };

    // Internal Modals & Containers
    let pendingExternalAsset = null;
    const tokenModal = document.getElementById("tokenModal");
    const pairModal = document.getElementById("pairModal");
    const imageUploadModal = document.getElementById("imageUploadModal");
    const txModal = document.getElementById("txModal");
    const warningModal = document.getElementById("warningModal");
    const detailModal = document.getElementById("detailModal");
    const detailModalBody = document.getElementById("detailModalBody");
    const detailModalTitle = document.getElementById("detailModalTitle");
    const ETHERSCAN_BASE = "https://sepolia.etherscan.io/address/";
    const ETHERSCAN_TX = "https://sepolia.etherscan.io/tx/";

    const modalTokenList = document.getElementById("modalTokenList");
    const modalPairList = document.getElementById("modalPairList");

    function copyToClipboard(text, btn) {
        navigator.clipboard.writeText(text).then(() => {
            if (btn) { btn.innerHTML = '<i class="ri-check-line"></i>'; btn.classList.add('copied'); setTimeout(() => { btn.innerHTML = '<i class="ri-file-copy-line"></i>'; btn.classList.remove('copied'); }, 1500); }
            showToast('Copied to clipboard', 'info');
        });
    }
    window.copyToClipboard = copyToClipboard;

    // --- Toast & UX System ---
    function showToast(message, type = 'info') {
        const container = document.getElementById("toastContainer");
        const toast = document.createElement("div");
        toast.className = `toast ${type}`;

        window.showToast = showToast; // Expose globally for RPC error bridges
        let icon = '<i class="ri-information-fill"></i>';
        if (type === 'success') icon = '<i class="ri-checkbox-circle-fill"></i>';
        if (type === 'error') icon = '<i class="ri-shield-fill"></i>';

        toast.innerHTML = `<span style="font-size: 1.1rem; margin-right: 0.2rem;">${icon}</span> <span>${message}</span>`;
        container.appendChild(toast);

        setTimeout(() => {
            toast.classList.add("fade-out");
            setTimeout(() => toast.remove(), 300);
        }, 4500);
    }

    function toggleTxModal(show, message = "Confirm this execution via Web3 Provider") {
        if (show) {
            document.getElementById("txModalText").textContent = message;
            txModal.classList.add("active");
        } else {
            txModal.classList.remove("active");
        }
    }

    function promptWarning() {
        return new Promise((resolve) => {
            if (!warningModal) return resolve(true);
            warningModal.classList.add("active");
            document.getElementById("btnCancelWarning").onclick = () => { warningModal.classList.remove("active"); resolve(false); };
            document.getElementById("btnConfirmWarning").onclick = () => { warningModal.classList.remove("active"); resolve(true); };
        });
    }

    // Detail Inspector Modal
    document.getElementById("closeDetailModal").addEventListener("click", () => detailModal.classList.remove("active"));

    async function openTokenDetail(tokenData) {
        detailModalTitle.textContent = "Token Intelligence";
        detailModalBody.innerHTML = `<p class="empty-text">Querying EVM state...</p>`;
        detailModal.classList.add("active");

        let decimals = 18, totalSupply = "N/A";
        try {
            const contract = new ethers.Contract(tokenData.address, CONFIG.ABI.TOKEN, Web3Backend.provider);
            decimals = await contract.decimals();
            const rawSupply = await contract.totalSupply();
            totalSupply = Number(ethers.formatUnits(rawSupply, decimals)).toLocaleString();
        } catch (e) { console.warn("Token detail fetch:", e); }

        const createdAt = tokenData.created_at ? new Date(tokenData.created_at).toLocaleString() : "Unknown";
        const creatorShort = tokenData.creator_address ? `${tokenData.creator_address.substring(0, 6)}...${tokenData.creator_address.slice(-4)}` : "Unknown";

        detailModalBody.innerHTML = `
            <div class="detail-logo-header">
                <img src="${tokenData.logo_url}" alt="${tokenData.symbol}">
                <div class="detail-title-group">
                    <h4>${tokenData.name}</h4>
                    <p><span class="detail-badge">${tokenData.symbol}</span></p>
                </div>
            </div>
            <div class="detail-section">
                <div class="detail-section-title">Contract Information</div>
                <div class="detail-row">
                    <span class="detail-label">Address</span>
                    <span><a href="${ETHERSCAN_BASE}${tokenData.address}" target="_blank" class="etherscan-link">${tokenData.address.substring(0, 6)}...${tokenData.address.slice(-4)} <i class="ri-external-link-line"></i></a><button class="copy-btn" onclick="copyToClipboard('${tokenData.address}', this)"><i class="ri-file-copy-line"></i></button></span>
                </div>
                <div class="detail-row">
                    <span class="detail-label">Decimals</span>
                    <span class="detail-value">${decimals}</span>
                </div>
                <div class="detail-row">
                    <span class="detail-label">Total Supply</span>
                    <span class="detail-value">${totalSupply}</span>
                </div>
                <div class="detail-row">
                    <span class="detail-label">Creator</span>
                    <a href="${ETHERSCAN_BASE}${tokenData.creator_address}" target="_blank" class="etherscan-link">${creatorShort} <i class="ri-external-link-line"></i></a>
                </div>
            </div>
            <div class="detail-section">
                <div class="detail-section-title">Origin Metadata</div>
                <div class="detail-row">
                    <span class="detail-label">Indexed At</span>
                    <span class="detail-value" style="font-family: Inter, sans-serif; font-size: 0.8rem;">${createdAt}</span>
                </div>
            </div>`;
    }

    async function openPairDetail(pairData) {
        detailModalTitle.textContent = "Pool Intelligence";
        detailModalBody.innerHTML = `<p class="empty-text">Querying EVM state...</p>`;
        detailModal.classList.add("active");

        const t0 = cachedTokens.find(t => t.address === pairData.token0_address) || { symbol: "UNK", name: "Unknown", logo_url: "" };
        const t1 = cachedTokens.find(t => t.address === pairData.token1_address) || { symbol: "UNK", name: "Unknown", logo_url: "" };

        let r0Fmt = "0", r1Fmt = "0", ratio = "N/A", lpTotalSupply = "0";
        try {
            const { r0, r1 } = await Web3Backend.getReserves(pairData.pair_address);
            r0Fmt = Number(ethers.formatUnits(r0, 18)).toLocaleString(undefined, { maximumFractionDigits: 4 });
            r1Fmt = Number(ethers.formatUnits(r1, 18)).toLocaleString(undefined, { maximumFractionDigits: 4 });
            if (r0 > 0n) ratio = (Number(ethers.formatUnits(r1, 18)) / Number(ethers.formatUnits(r0, 18))).toFixed(6);
            lpTotalSupply = Number(await Web3Backend.getLPTotalSupply(pairData.pair_address)).toLocaleString(undefined, { maximumFractionDigits: 4 });
        } catch (e) { console.warn("Pair detail fetch:", e); }

        let userLpBal = "0";
        if (isAuthenticated) {
            try { userLpBal = Number(await Web3Backend.getLPBalance(pairData.pair_address)).toFixed(6); } catch { }
        }

        const createdAt = pairData.created_at ? new Date(pairData.created_at).toLocaleString() : "Unknown";
        const creatorShort = pairData.creator_address ? `${pairData.creator_address.substring(0, 6)}...${pairData.creator_address.slice(-4)}` : "Unknown";

        detailModalBody.innerHTML = `
            <div class="detail-logo-header">
                <div class="pair-img-group" style="width:64px; height:40px;">
                    <img src="${t0.logo_url}" style="width:40px;height:40px;">
                    <img src="${t1.logo_url}" style="width:40px;height:40px;left:24px;">
                </div>
                <div class="detail-title-group">
                    <h4>${t0.symbol} / ${t1.symbol}</h4>
                    <p>Constant Product AMM Pool</p>
                </div>
            </div>
            <div class="detail-section">
                <div class="detail-section-title">Pool Contract</div>
                <div class="detail-row">
                    <span class="detail-label">LP Address</span>
                    <span><a href="${ETHERSCAN_BASE}${pairData.pair_address}" target="_blank" class="etherscan-link">${pairData.pair_address.substring(0, 6)}...${pairData.pair_address.slice(-4)} <i class="ri-external-link-line"></i></a><button class="copy-btn" onclick="copyToClipboard('${pairData.pair_address}', this)"><i class="ri-file-copy-line"></i></button></span>
                </div>
                <div class="detail-row">
                    <span class="detail-label">LP Total Supply</span>
                    <span class="detail-value">${lpTotalSupply}</span>
                </div>
                <div class="detail-row">
                    <span class="detail-label">Your LP Balance</span>
                    <span class="detail-value" style="color: ${parseFloat(userLpBal) > 0 ? '#10b981' : 'var(--text-muted)'}">${userLpBal}</span>
                </div>
            </div>
            <div class="detail-section">
                <div class="detail-section-title">Live Reserves</div>
                <div class="detail-row">
                    <span class="detail-label">${t0.symbol}</span>
                    <span class="detail-value">${r0Fmt}</span>
                </div>
                <div class="detail-row">
                    <span class="detail-label">${t1.symbol}</span>
                    <span class="detail-value">${r1Fmt}</span>
                </div>
                <div class="detail-row">
                    <span class="detail-label">Price Ratio</span>
                    <span class="detail-value" style="color: var(--accent);">1 ${t0.symbol} ≈ ${ratio} ${t1.symbol}</span>
                </div>
            </div>
            <div class="detail-section">
                <div class="detail-section-title">Underlying Assets</div>
                <div class="detail-row">
                    <span class="detail-label">Asset A Contract</span>
                    <a href="${ETHERSCAN_BASE}${pairData.token0_address}" target="_blank" class="etherscan-link">${t0.symbol}: ${pairData.token0_address.substring(0, 6)}...${pairData.token0_address.slice(-4)} <i class="ri-external-link-line"></i></a>
                </div>
                <div class="detail-row">
                    <span class="detail-label">Asset B Contract</span>
                    <a href="${ETHERSCAN_BASE}${pairData.token1_address}" target="_blank" class="etherscan-link">${t1.symbol}: ${pairData.token1_address.substring(0, 6)}...${pairData.token1_address.slice(-4)} <i class="ri-external-link-line"></i></a>
                </div>
                <div class="detail-row">
                    <span class="detail-label">Creator</span>
                    <a href="${ETHERSCAN_BASE}${pairData.creator_address}" target="_blank" class="etherscan-link">${creatorShort} <i class="ri-external-link-line"></i></a>
                </div>
            </div>
            <div class="detail-section">
                <div class="detail-section-title">Origin Metadata</div>
                <div class="detail-row">
                    <span class="detail-label">Indexed At</span>
                    <span class="detail-value" style="font-family: Inter, sans-serif; font-size: 0.8rem;">${createdAt}</span>
                </div>
            </div>`;
    }

    // --- Boot Sequence ---
    try {
        await Registry.getTokens(); // Wake up DB
    } catch { }

    // Auto-reconnect if wallet was previously authorized
    if (window.ethereum) {
        try {
            const accounts = await window.ethereum.request({ method: 'eth_accounts' });
            if (accounts.length > 0) {
                // Wallet already authorized — trigger silent connect
                setTimeout(() => document.getElementById("btnConnect").click(), 300);
            }
        } catch { }
    }

    // Navigation Subsystem
    document.querySelectorAll(".tab-btn").forEach(btn => {
        btn.addEventListener("click", (e) => {
            document.querySelectorAll(".tab-btn").forEach(b => b.classList.remove("active"));
            document.querySelectorAll(".panel").forEach(p => p.classList.remove("active"));
            e.target.classList.add("active");
            document.getElementById(e.target.dataset.target).classList.add("active");

            // Explorer full-width toggle
            const ws = document.querySelector('.workspace-container');
            if (e.target.dataset.target === 'explorer-panel') {
                ws.classList.add('explorer-expanded');
            } else {
                ws.classList.remove('explorer-expanded');
            }
        });
    });

    document.querySelectorAll(".sub-tab-btn").forEach(btn => {
        btn.addEventListener("click", (e) => {
            document.querySelectorAll(".sub-tab-btn").forEach(b => b.classList.remove("active"));
            document.querySelectorAll(".sub-panel").forEach(p => p.style.display = "none");
            e.target.classList.add("active");
            document.getElementById(e.target.dataset.target).style.display = "block";
        });
    });

    // Authentication Guard
    const btnConnect = document.getElementById("btnConnect");
    const btnDisconnect = document.getElementById("btnDisconnect");
    const networkStatus = document.getElementById("networkStatus");
    const actions = document.querySelectorAll(".btn-action");

    btnConnect.addEventListener("click", async () => {
        try {
            btnConnect.textContent = "Authenticating Context...";
            const address = await Web3Backend.authenticate();

            btnConnect.style.display = "none";
            btnDisconnect.style.display = "inline-flex";
            networkStatus.querySelector(".dot").className = "dot green";
            networkStatus.querySelector(".text").textContent = `Sepolia: ${address.substring(0, 6)}...`;
            isAuthenticated = true;

            actions.forEach(btn => {
                if (btn.id !== "btnRemoveLiquidity") btn.removeAttribute("disabled");
                if (btn.id === "btnSwap") btn.textContent = "Execute Route";
                if (btn.id === "btnDeployToken") btn.textContent = "Compile & Deploy Artifact";
                if (btn.id === "btnCreatePair") btn.textContent = "Instantiate Factory Proxy";
                if (btn.id === "btnMintLiquidity") btn.textContent = "Commit Liquidity Payload";
            });

            showToast("Zero-Trust perimeter secured.", "success");
            await refreshDashboards();

        } catch (error) {
            showToast(`Authentication blocked: ${error.message}`, "error");
            btnConnect.textContent = "Connect Wallet";
            networkStatus.querySelector(".dot").className = "dot red";
            networkStatus.querySelector(".text").textContent = "Disconnected";
        }
    });

    btnDisconnect.addEventListener("click", () => {
        isAuthenticated = false;
        Web3Backend.address = null;
        Web3Backend.signer = null;
        btnConnect.textContent = "Connect Wallet";
        btnConnect.style.display = "inline-flex";
        btnDisconnect.style.display = "none";
        networkStatus.querySelector(".dot").className = "dot red";
        networkStatus.querySelector(".text").textContent = "Disconnected";
        actions.forEach(btn => btn.setAttribute("disabled", "true"));
        showToast("Session disconnected.", "info");
        refreshDashboards();
    });

    // --- Context Hydration Engines ---
    async function refreshDashboards() {
        cachedTokens = await Registry.getTokens();
        cachedPairs = await Registry.getPairs();

        hydrateExplorer(); // Explorer Analytics Engine

        if (!isAuthenticated) return;

        const assetsList = document.getElementById("sidebarWalletAssets");
        const poolsList = document.getElementById("sidebarUserPairs");
        assetsList.innerHTML = ''; poolsList.innerHTML = '';

        // Hydrate Sidebar Pools
        let foundLPs = 0;
        for (const pair of cachedPairs) {
            const lpBal = await Web3Backend.getLPBalance(pair.pair_address);
            if (parseFloat(lpBal) > 0 || pair.creator_address === Web3Backend.address.toLowerCase()) {
                const t0 = cachedTokens.find(t => t.address === pair.token0_address);
                const t1 = cachedTokens.find(t => t.address === pair.token1_address);
                if (!t0 || !t1) continue; // Skip orphaned pairs from old deployments
                foundLPs++;
                const pairShort = `${pair.pair_address.substring(0, 6)}...${pair.pair_address.slice(-4)}`;

                poolsList.innerHTML += `
                    <div class="token-row" title="LP Contract: ${pair.pair_address}" style="cursor:pointer;" onclick="document.dispatchEvent(new CustomEvent('openPairDetail', {detail: '${pair.pair_address}'}))">
                        <div class="token-row-left">
                            <div class="pair-img-group"><img src="${t0.logo_url}"><img src="${t1.logo_url}"></div>
                            <div class="token-info" style="margin-left: 0.5rem;">
                                <span class="token-ticker">${t0.symbol}/${t1.symbol} LP</span>
                                <span class="token-name">Bal: ${parseFloat(lpBal).toFixed(4)}</span>
                                <a href="${ETHERSCAN_BASE}${pair.pair_address}" target="_blank" class="etherscan-link" style="font-size:0.7rem;" onclick="event.stopPropagation()">${pairShort} ↗</a>
                            </div>
                        </div>
                    </div>`;
            }
        }

        // Listen for sidebar pair detail clicks
        document.addEventListener('openPairDetail', (e) => {
            const p = cachedPairs.find(x => x.pair_address === e.detail);
            if (p) openPairDetail(p);
        });
        if (foundLPs === 0) poolsList.innerHTML = `<p class="empty-state">No LP positions attached to identity</p>`;

        // Hydrate Sidebar Wallet Assets
        let foundAssets = 0;
        for (const token of cachedTokens) {
            const bal = await Web3Backend.fetchBalance(token.address);
            if (parseFloat(bal) > 0) {
                foundAssets++;
                assetsList.innerHTML += `
                    <div class="token-row">
                        <div class="token-row-left">
                            <img src="${token.logo_url}" class="token-img">
                            <div class="token-info">
                                <span class="token-ticker">${token.symbol}</span>
                                <span class="token-name">${token.name}</span>
                            </div>
                        </div>
                        <span class="token-balance">${parseFloat(bal).toFixed(2)}</span>
                    </div>`;
            }
        }

        if (foundAssets === 0) assetsList.innerHTML = `<p class="empty-state">Zero recognizable assets in ledger</p>`;

        // Hydrate Recent Activity
        await hydrateActivityFeed();
    }

    // Live Analytics Explorer Engine
    function hydrateExplorer(tokenFilter = "", pairFilter = "") {
        const tokensGrid = document.getElementById("explorerTokensGrid");
        const pairsGrid = document.getElementById("explorerPairsGrid");
        tokensGrid.innerHTML = ''; pairsGrid.innerHTML = '';

        let fTokens = cachedTokens;
        if (tokenFilter) {
            const q = tokenFilter.toLowerCase();
            fTokens = fTokens.filter(t => t.name.toLowerCase().includes(q) || t.symbol.toLowerCase().includes(q) || t.address.toLowerCase().includes(q));
        }

        // Filter out orphaned pairs (tokens not in registry)
        let fPairs = cachedPairs.filter(p =>
            cachedTokens.some(t => t.address === p.token0_address) &&
            cachedTokens.some(t => t.address === p.token1_address)
        );
        if (pairFilter) {
            const q = pairFilter.toLowerCase();
            fPairs = fPairs.filter(p => {
                const t0 = cachedTokens.find(t => t.address === p.token0_address) || { symbol: "" };
                const t1 = cachedTokens.find(t => t.address === p.token1_address) || { symbol: "" };
                return p.pair_address.toLowerCase().includes(q) || t0.symbol.toLowerCase().includes(q) || t1.symbol.toLowerCase().includes(q);
            });
        }

        if (fTokens.length === 0) tokensGrid.innerHTML = `<p class="empty-state">No matching tokens found.</p>`;
        if (fPairs.length === 0) pairsGrid.innerHTML = `<p class="empty-state">No matching pools found.</p>`;

        fTokens.forEach(t => {
            const card = document.createElement("div");
            card.className = "explorer-card";
            card.title = t.address;
            card.innerHTML = `
                <img src="${t.logo_url}" class="single-logo">
                <h4>${t.symbol}</h4>
                <p>${t.address.substring(0, 6)}...${t.address.slice(-4)}</p>
            `;
            card.addEventListener("click", () => openTokenDetail(t));
            tokensGrid.appendChild(card);
        });

        fPairs.forEach(p => {
            const t0 = cachedTokens.find(t => t.address === p.token0_address) || { symbol: "UNK", logo_url: "" };
            const t1 = cachedTokens.find(t => t.address === p.token1_address) || { symbol: "UNK", logo_url: "" };

            const cardId = `explorer-pair-${p.pair_address}`;
            const card = document.createElement("div");
            card.className = "explorer-card";
            card.title = p.pair_address;
            card.id = cardId;
            card.innerHTML = `
                <div class="pair-img-group">
                    <img src="${t0.logo_url}"><img src="${t1.logo_url}">
                </div>
                <h4>${t0.symbol}/${t1.symbol}</h4>
                <p style="margin-bottom:0.5rem;">${p.pair_address.substring(0, 6)}...${p.pair_address.slice(-4)}</p>
                <div class="analytics-container">
                    <div style="margin-top:0.5rem; font-size:0.75rem; color:var(--text-muted); padding-top:0.5rem; border-top:1px solid var(--border-dim);">
                        Indexing Vault telemetry...
                    </div>
                </div>
            `;
            card.addEventListener("click", () => openPairDetail(p));
            pairsGrid.appendChild(card);

            // Asynchronous Analytics Hydration
            Web3Backend.getReserves(p.pair_address).then(res => {
                const el = document.getElementById(cardId);
                if (el) {
                    if (res.r0 === 0n && res.r1 === 0n) {
                        el.querySelector('.analytics-container').innerHTML = `<div style="margin-top:0.5rem; font-size:0.75rem; color:#ef4444; padding-top:0.5rem; border-top:1px solid var(--border-dim);">TVL: Empty/Fresh Vault</div>`;
                    } else {
                        const amt0 = Number(ethers.formatUnits(res.r0, 18));
                        const amt1 = Number(ethers.formatUnits(res.r1, 18));
                        const ratio = (amt1 / amt0).toFixed(6);

                        el.querySelector('.analytics-container').innerHTML = `
                        <div style="margin-top:0.5rem; text-align:left; font-size:0.75rem; color:var(--text-muted); padding-top:0.5rem; border-top:1px solid var(--border-dim); font-family:monospace; line-height: 1.4;">
                            <span style="color:var(--text-light)">R1: ${amt0.toFixed(2)} ${t0.symbol}</span><br>
                            <span style="color:var(--text-light)">R2: ${amt1.toFixed(2)} ${t1.symbol}</span><br>
                            <div style="margin-top:0.3rem; color:var(--accent);">Global Ratio: 1 ${t0.symbol} ≈ ${ratio} ${t1.symbol}</div>
                        </div>`;
                    }
                }
            });
        });
    }

    const explorerTokenSearch = document.getElementById("explorerTokenSearch");
    if (explorerTokenSearch) explorerTokenSearch.addEventListener("input", (e) => hydrateExplorer(e.target.value.trim(), explorerPairSearch ? explorerPairSearch.value.trim() : ""));

    const explorerPairSearch = document.getElementById("explorerPairSearch");
    if (explorerPairSearch) explorerPairSearch.addEventListener("input", (e) => hydrateExplorer(explorerTokenSearch ? explorerTokenSearch.value.trim() : "", e.target.value.trim()));

    // Transaction Activity Feed
    async function hydrateActivityFeed() {
        const container = document.getElementById('sidebarActivity');
        if (!container || !isAuthenticated) return;

        const txIcons = {
            'swap': '<i class="ri-loop-right-line" style="color: var(--accent-1);"></i>',
            'mint': '<i class="ri-drop-fill" style="color: var(--accent-2);"></i>',
            'burn': '<i class="ri-fire-fill" style="color: var(--error);"></i>',
            'deploy': '<i class="ri-rocket-fill" style="color: var(--warning);"></i>',
            'pair': '<i class="ri-link" style="color: var(--success);"></i>'
        };

        try {
            const txs = await Registry.getTransactions(Web3Backend.address, 8);
            if (!txs || txs.length === 0) {
                container.innerHTML = `<p class="empty-state">No transactions yet</p>`;
                return;
            }
            container.innerHTML = '';
            for (const tx of txs) {
                const icon = txIcons[tx.tx_type] || '<i class="ri-box-3-fill"></i>';
                const ago = timeAgo(tx.created_at);
                container.innerHTML += `
                    <div class="activity-row">
                        <span class="activity-icon">${icon}</span>
                        <div class="activity-info">
                            <span>${tx.details || tx.tx_type}</span>
                            <span>${ago}</span>
                        </div>
                        <a href="${ETHERSCAN_TX}${tx.tx_hash}" target="_blank" class="activity-link">View <i class="ri-external-link-line"></i></a>
                    </div>`;
            }
        } catch {
            container.innerHTML = `<p class="empty-state">Activity feed unavailable</p>`;
        }
    }

    function timeAgo(dateStr) {
        const diff = (Date.now() - new Date(dateStr).getTime()) / 1000;
        if (diff < 60) return 'Just now';
        if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
        if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
        return `${Math.floor(diff / 86400)}d ago`;
    }

    // --- Global Modals (Token & Pair Selection) ---
    const modalSearchInput = document.getElementById("modalSearchInput");
    const pairSearchInput = document.getElementById("pairSearchInput");

    function openTokenModal(targetId) {
        currentModalTarget = targetId;
        modalSearchInput.value = "";
        tokenModal.classList.add("active");
        renderModalTokens();
    }

    document.getElementById("btnSelectPool").addEventListener("click", () => {
        currentModalTarget = 'pool-pair';
        pairSearchInput.value = "";
        pairModal.classList.add("active");
        renderModalPairs();
    });

    document.getElementById("btnSelectPoolRemove").addEventListener("click", () => {
        currentModalTarget = 'pool-remove';
        pairSearchInput.value = "";
        pairModal.classList.add("active");
        renderModalPairs();
    });

    document.querySelectorAll(".close-modal").forEach(btn => {
        btn.addEventListener("click", () => {
            tokenModal.classList.remove("active");
            pairModal.classList.remove("active");
            imageUploadModal.classList.remove("active");
            pendingExternalAsset = null;
        });
    });

    document.getElementById("btnSelectTokenIn").addEventListener("click", () => openTokenModal("swap-in"));
    document.getElementById("btnSelectTokenOut").addEventListener("click", () => openTokenModal("swap-out"));
    document.getElementById("btnSelectFactory0").addEventListener("click", () => openTokenModal("factory-0"));
    document.getElementById("btnSelectFactory1").addEventListener("click", () => openTokenModal("factory-1"));

    modalSearchInput.addEventListener("input", (e) => renderModalTokens(e.target.value));
    pairSearchInput.addEventListener("input", (e) => renderModalPairs(e.target.value));

    async function renderModalPairs(searchQuery = "") {
        modalPairList.innerHTML = `<p class="empty-text">Cross-referencing index DB...</p>`;
        if (cachedPairs.length === 0) cachedPairs = await Registry.getPairs();

        const query = searchQuery.toLowerCase().trim();
        let filteredPairs = cachedPairs;

        if (query) { filteredPairs = cachedPairs.filter(p => p.pair_address.toLowerCase().includes(query)); }

        modalPairList.innerHTML = '';
        if (filteredPairs.length === 0) return modalPairList.innerHTML = `<p class="empty-text">Zero records isolated from index.</p>`;

        for (const pair of filteredPairs) {
            const t0 = cachedTokens.find(t => t.address === pair.token0_address);
            const t1 = cachedTokens.find(t => t.address === pair.token1_address);
            if (!t0 || !t1) continue;

            const row = document.createElement("div");
            row.className = "token-row";
            row.innerHTML = `
                <div class="token-row-left">
                    <div class="pair-img-group" style="margin-right:0.5rem;"><img src="${t0.logo_url}"><img src="${t1.logo_url}"></div>
                    <div class="token-info">
                        <span class="token-ticker">${t0.symbol}/${t1.symbol} LP</span>
                        <span class="token-name">${pair.pair_address.substring(0, 8)}...</span>
                    </div>
                </div>`;

            row.addEventListener("click", async () => {
                selectedTokens[currentModalTarget] = pair;
                let targetBtn = document.getElementById(currentModalTarget === 'pool-pair' ? "btnSelectPool" : "btnSelectPoolRemove");

                targetBtn.querySelector(".token-symbol").innerHTML = `<div style="display:inline-flex; align-items:center; transform: translateY(4px); margin-right:8px; width:32px; height:20px; position:relative;"><img src="${t0.logo_url}" style="width:20px; border-radius:50%; position:absolute; left:0; z-index:2; border: 1px solid #000;"><img src="${t1.logo_url}" style="width:20px; border-radius:50%; position:absolute; left:12px; z-index:1; border: 1px solid #000;"></div><span>${t0.symbol}/${t1.symbol}</span>`;
                targetBtn.style.background = "var(--surface-elevated)";
                targetBtn.style.border = "1px solid var(--border-glow)";

                if (currentModalTarget === 'pool-pair') {
                    document.getElementById("labelPoolAmt0").textContent = `Asset A Qty (${t0.symbol})`;
                    document.getElementById("labelPoolAmt1").textContent = `Asset B Qty (${t1.symbol})`;
                    document.getElementById("poolAmount0").removeAttribute("disabled");

                    if (isAuthenticated) {
                        currentPoolRatio = await Web3Backend.getReserves(pair.pair_address);
                        if (currentPoolRatio.r0 === 0n) {
                            document.getElementById("poolRatioInfoA").textContent = "Fresh Pool: Define Initial Ratio";
                            document.getElementById("poolRatioInfoB").textContent = "";
                            document.getElementById("poolAmount1").removeAttribute("disabled");
                        } else {
                            document.getElementById("poolRatioInfoA").textContent = "Ratio Locked via Matrix";
                            document.getElementById("poolRatioInfoB").textContent = "Auto-Synced Output";
                            document.getElementById("poolAmount1").setAttribute("disabled", "true");
                        }
                    }
                } else if (currentModalTarget === 'pool-remove') {
                    // LP Burn Extractor Engine
                    document.getElementById("removeLiquidityCard").style.display = "block";
                    const lpBalance = await Web3Backend.getLPBalance(pair.pair_address);
                    document.getElementById("maxLpBalance").textContent = `Max Balance: ${parseFloat(lpBalance).toFixed(5)}`;

                    const totalLP = await Web3Backend.getLPTotalSupply(pair.pair_address);
                    const reserves = await Web3Backend.getReserves(pair.pair_address);

                    // Allow fast binding
                    document.getElementById("maxLpBalance").onclick = () => {
                        document.getElementById("removeLpAmount").value = lpBalance;
                        document.getElementById("removeLpAmount").dispatchEvent(new Event('input'));
                    };

                    document.getElementById("removeLpAmount").oninput = (e) => {
                        let burnAmt = parseFloat(e.target.value);
                        if (isNaN(burnAmt) || burnAmt <= 0) {
                            document.getElementById("btnRemoveLiquidity").setAttribute("disabled", "true");
                            document.getElementById("removeEstA").textContent = `0.00 ${t0.symbol}`;
                            document.getElementById("removeEstB").textContent = `0.00 ${t1.symbol}`;
                            return;
                        }

                        if (totalLP > 0) {
                            const poolShare = burnAmt / parseFloat(totalLP);
                            const estA = poolShare * Number(ethers.formatUnits(reserves.r0, 18));
                            const estB = poolShare * Number(ethers.formatUnits(reserves.r1, 18));

                            document.getElementById("removeEstA").textContent = `${estA.toFixed(4)} ${t0.symbol}`;
                            document.getElementById("removeEstB").textContent = `${estB.toFixed(4)} ${t1.symbol}`;
                        }

                        if (burnAmt <= parseFloat(lpBalance)) {
                            document.getElementById("btnRemoveLiquidity").removeAttribute("disabled");
                        } else {
                            document.getElementById("btnRemoveLiquidity").setAttribute("disabled", "true");
                        }
                    };
                }

                pairModal.classList.remove("active");
            });
            modalPairList.appendChild(row);
        }
    }

    async function renderModalTokens(searchQuery = "") {
        modalTokenList.innerHTML = `<p class="empty-text">Cross-referencing index...</p>`;
        if (cachedTokens.length === 0) cachedTokens = await Registry.getTokens();

        const query = searchQuery.toLowerCase().trim();
        let filteredTokens = query ? cachedTokens.filter(t => t.name.toLowerCase().includes(query) || t.symbol.toLowerCase().includes(query) || t.address.toLowerCase() === query) : cachedTokens;

        modalTokenList.innerHTML = '';
        if (filteredTokens.length === 0 && window.ethers && ethers.isAddress(query)) {
            modalTokenList.innerHTML = `
                <div class="input-card" style="text-align:center; padding: 2rem 1rem;">
                    <p class="subtitle" style="margin-bottom:1rem; color:var(--accent);">EVM Address [${query.substring(0, 6)}...] isolated.</p>
                    <button class="btn-primary" id="btnImportToken">Query Smart Contract Code</button>
                </div>`;

            document.getElementById("btnImportToken").addEventListener("click", async () => {
                if (!isAuthenticated) return showToast("Must authenticate to execute EVM Probe.", "error");
                try {
                    const extToken = new ethers.Contract(query, CONFIG.ABI.TOKEN, Web3Backend.provider);
                    pendingExternalAsset = { address: query, name: await extToken.name(), symbol: await extToken.symbol() };
                    document.getElementById("imageModalMessage").textContent = `Verified: ${pendingExternalAsset.name} (${pendingExternalAsset.symbol}). Req Logo:`;
                    tokenModal.classList.remove("active"); imageUploadModal.classList.add("active");
                } catch { showToast("EVM Probe Failed: Extraneous interface.", "error"); }
            });
            return;
        }

        for (const token of filteredTokens) {
            let balance = isAuthenticated ? parseFloat(await Web3Backend.fetchBalance(token.address)).toFixed(2) : "0.0";
            const row = document.createElement("div"); row.className = "token-row";
            row.innerHTML = `<div class="token-row-left"><img src="${token.logo_url}" class="token-img"><div class="token-info"><span class="token-ticker">${token.symbol}</span><span class="token-name">${token.name.substring(0, 16)}</span></div></div><span class="token-balance">${balance}</span>`;

            row.addEventListener("click", async () => {
                selectedTokens[currentModalTarget] = token;
                let targetBtn = document.getElementById(
                    currentModalTarget === 'swap-in' ? "btnSelectTokenIn" :
                        currentModalTarget === 'swap-out' ? "btnSelectTokenOut" :
                            currentModalTarget === 'factory-0' ? "btnSelectFactory0" : "btnSelectFactory1"
                );
                targetBtn.querySelector(".token-symbol").innerHTML = `<img src="${token.logo_url}" style="width:18px; border-radius:50%; vertical-align:middle; margin-right:6px;"> ${token.symbol}`;
                targetBtn.style.background = "var(--surface-elevated)";
                targetBtn.style.border = "1px solid var(--border-glow)";
                tokenModal.classList.remove("active");

                if (currentModalTarget === 'swap-in' || currentModalTarget === 'swap-out') {
                    evaluateSwapRoute();
                    //  Show balance + MAX for swap input
                    if (currentModalTarget === 'swap-in' && isAuthenticated) {
                        const bal = await Web3Backend.fetchBalance(token.address);
                        let balRow = document.getElementById('swapBalanceDisplay');
                        if (!balRow) {
                            balRow = document.createElement('div');
                            balRow.id = 'swapBalanceDisplay';
                            balRow.className = 'balance-display';
                            document.getElementById('swapAmountIn').parentNode.insertBefore(balRow, document.getElementById('swapAmountIn'));
                        }
                        balRow.innerHTML = `<span>Balance: ${parseFloat(bal).toFixed(4)}</span><button class="max-btn" id="swapMaxBtn">MAX</button>`;
                        document.getElementById('swapMaxBtn').onclick = () => { document.getElementById('swapAmountIn').value = bal; calculateLiveQuote(); };
                    }
                }
            });
            modalTokenList.appendChild(row);
        }
    }

    // --- LP Dynamic Matching ---
    document.getElementById("poolAmount0").addEventListener("input", (e) => {
        if (currentPoolRatio.r0 === 0n || !e.target.value) return;
        const amt0 = parseFloat(e.target.value);
        if (amt0 > 0) {
            //  Use BigInt to match Solidity integer math exactly
            // Contract checks: (_amount0 * reserve1) == (_amount1 * reserve0)
            // So: _amount1 = (_amount0 * reserve1) / reserve0
            const amt0Wei = ethers.parseUnits(amt0.toString(), 18);
            const amt1Wei = (amt0Wei * currentPoolRatio.r1) / currentPoolRatio.r0;
            const a1 = document.getElementById("poolAmount1");
            if (a1) a1.value = ethers.formatUnits(amt1Wei, 18);
        }

        // Pool Share % calculation
        updatePoolShare();
    });

    async function updatePoolShare() {
        const pair = selectedTokens['pool-pair'];
        if (!pair) return;
        const amt0 = parseFloat(document.getElementById("poolAmount0").value);
        const amt1 = parseFloat(document.getElementById("poolAmount1").value);
        if (isNaN(amt0) || amt0 <= 0) return;

        let shareEl = document.getElementById('poolShareDisplay');
        if (!shareEl) {
            shareEl = document.createElement('div');
            shareEl.id = 'poolShareDisplay';
            shareEl.className = 'pool-share-info';
            document.getElementById('add-liquidity').insertBefore(shareEl, document.getElementById('btnMintLiquidity'));
        }

        try {
            const totalLP = parseFloat(await Web3Backend.getLPTotalSupply(pair.pair_address));
            if (totalLP === 0) {
                shareEl.textContent = 'Pool Share: 100% (Initial Provider)';
            } else {
                const r0 = Number(ethers.formatUnits(currentPoolRatio.r0, 18));
                const newLP = (amt0 / r0) * totalLP;
                const share = (newLP / (totalLP + newLP)) * 100;
                shareEl.textContent = `Your Pool Share: ${share.toFixed(2)}%`;
            }
        } catch { shareEl.textContent = 'Pool Share: Calculating...'; }
    }

    // --- Router Quoting Logic ---
    async function evaluateSwapRoute() {
        const tIn = selectedTokens['swap-in'];
        const tOut = selectedTokens['swap-out'];
        const statusText = document.getElementById("swapRouteStatus");
        const btnSwap = document.getElementById("btnSwap");

        if (!tIn || !tOut) return;
        if (tIn.address === tOut.address) {
            statusText.textContent = "Mathematical Fault: Origin and Destination vectors identical."; statusText.style.color = "#ef4444";
            btnSwap.setAttribute("disabled", "true"); activeSwapRouteData = null; return;
        }

        activeSwapRouteData = cachedPairs.find(p =>
            (p.token0_address.toLowerCase() === tIn.address.toLowerCase() && p.token1_address.toLowerCase() === tOut.address.toLowerCase()) ||
            (p.token0_address.toLowerCase() === tOut.address.toLowerCase() && p.token1_address.toLowerCase() === tIn.address.toLowerCase())
        );

        if (activeSwapRouteData) {
            statusText.innerHTML = `Route Validated via <b style="color:var(--accent); font-family:monospace;">${activeSwapRouteData.pair_address.substring(0, 8)}...</b>`;
            statusText.style.color = "#10b981";
            if (isAuthenticated) btnSwap.removeAttribute("disabled");
            calculateLiveQuote(); // Re-trigger calculation if amount is already populated
        } else {
            statusText.textContent = "Insufficient Liquidity: Route not isolated."; statusText.style.color = "#ef4444";
            btnSwap.setAttribute("disabled", "true");
        }
    }

    document.getElementById("swapAmountIn").addEventListener("input", calculateLiveQuote);

    async function calculateLiveQuote() {
        const amtIn = parseFloat(document.getElementById("swapAmountIn").value);
        const quoteEl = document.getElementById("swapQuoteResult");
        if (isNaN(amtIn) || amtIn <= 0 || !activeSwapRouteData) return quoteEl.style.display = "none";

        try {
            const { r0, r1 } = await Web3Backend.getReserves(activeSwapRouteData.pair_address);
            if (r0 === 0n && r1 === 0n) {
                quoteEl.textContent = "Pool drained (Zero Reserves)";
                quoteEl.style.display = "block";
                document.getElementById("btnSwap").setAttribute("disabled", "true");
                return;
            } else {
                if (isAuthenticated) document.getElementById("btnSwap").removeAttribute("disabled");
            }

            const isToken0 = selectedTokens['swap-in'].address.toLowerCase() === activeSwapRouteData.token0_address.toLowerCase();
            const reserveIn = isToken0 ? r0 : r1;
            const reserveOut = isToken0 ? r1 : r0;

            const amountWithFee = amtIn * 0.995;
            const rInForm = Number(ethers.formatUnits(reserveIn, 18));
            const rOutForm = Number(ethers.formatUnits(reserveOut, 18));

            const estimatedOut = (amountWithFee * rOutForm) / (rInForm + amountWithFee);
            window.activeQuoteOutput = estimatedOut;

            quoteEl.style.display = "block";
            quoteEl.textContent = `Estimated Output: ${estimatedOut.toFixed(6)} ${selectedTokens['swap-out'].symbol}`;

            // Price Impact calculation
            const spotPrice = rOutForm / rInForm;
            const execPrice = estimatedOut / amtIn;
            const priceImpact = ((spotPrice - execPrice) / spotPrice * 100);
            let impactEl = document.getElementById('priceImpactDisplay');
            if (!impactEl) {
                impactEl = document.createElement('div');
                impactEl.id = 'priceImpactDisplay';
                quoteEl.parentNode.appendChild(impactEl);
            }
            impactEl.className = `price-impact ${priceImpact < 1 ? 'low' : priceImpact < 5 ? 'medium' : 'high'}`;
            impactEl.textContent = `Price Impact: -${priceImpact.toFixed(2)}%`;
            impactEl.style.display = 'block';
        } catch (e) {
            quoteEl.style.display = "none";
            const pi = document.getElementById('priceImpactDisplay');
            if (pi) pi.style.display = 'none';
        }
    }


    // ---  Image Crop Modal System ---
    const cropModal = document.getElementById("cropModal");
    const cropCanvas = document.getElementById("cropCanvas");
    const cropCtx = cropCanvas.getContext("2d");
    const cropZoom = document.getElementById("cropZoom");
    let cropImage = null;
    let cropOffsetX = 0, cropOffsetY = 0, cropScale = 1;
    let cropDragging = false, cropStartX = 0, cropStartY = 0;
    let cropResolve = null; // Promise resolver

    document.getElementById("closeCropModal").addEventListener("click", () => {
        cropModal.classList.remove("active");
        if (cropResolve) { cropResolve(null); cropResolve = null; }
    });

    function drawCropCanvas() {
        if (!cropImage) return;
        cropCtx.clearRect(0, 0, 320, 320);
        cropCtx.fillStyle = "#000";
        cropCtx.fillRect(0, 0, 320, 320);
        const w = cropImage.width * cropScale;
        const h = cropImage.height * cropScale;
        const x = (320 - w) / 2 + cropOffsetX;
        const y = (320 - h) / 2 + cropOffsetY;
        cropCtx.drawImage(cropImage, x, y, w, h);
    }

    cropZoom.addEventListener("input", (e) => {
        cropScale = parseFloat(e.target.value);
        drawCropCanvas();
    });

    cropCanvas.addEventListener("mousedown", (e) => {
        cropDragging = true;
        cropStartX = e.clientX - cropOffsetX;
        cropStartY = e.clientY - cropOffsetY;
    });
    document.addEventListener("mousemove", (e) => {
        if (!cropDragging) return;
        cropOffsetX = e.clientX - cropStartX;
        cropOffsetY = e.clientY - cropStartY;
        drawCropCanvas();
    });
    document.addEventListener("mouseup", () => { cropDragging = false; });

    document.getElementById("btnCropConfirm").addEventListener("click", () => {
        // Extract the 200x200 circle-center area, output as 128x128
        const outCanvas = document.createElement("canvas");
        outCanvas.width = 128; outCanvas.height = 128;
        const outCtx = outCanvas.getContext("2d");
        // Source: center 200px of the 320px canvas → maps to 128px output
        outCtx.drawImage(cropCanvas, 60, 60, 200, 200, 0, 0, 128, 128);
        const base64 = outCanvas.toDataURL("image/jpeg", 0.85);
        cropModal.classList.remove("active");
        if (cropResolve) { cropResolve(base64); cropResolve = null; }
    });

    function openCropModal(file) {
        return new Promise((resolve) => {
            cropResolve = resolve;
            cropOffsetX = 0; cropOffsetY = 0; cropScale = 1;
            cropZoom.value = "1";
            const reader = new FileReader();
            reader.onload = (e) => {
                cropImage = new Image();
                cropImage.onload = () => {
                    // Fit image: scale so shortest side fills 320px
                    const minDim = Math.min(cropImage.width, cropImage.height);
                    cropScale = 320 / minDim;
                    cropZoom.value = cropScale.toFixed(2);
                    cropZoom.min = (cropScale * 0.5).toFixed(2);
                    cropZoom.max = (cropScale * 3).toFixed(2);
                    drawCropCanvas();
                    cropModal.classList.add("active");
                };
                cropImage.src = e.target.result;
            };
            reader.readAsDataURL(file);
        });
    }

    // File input → open crop modal
    document.getElementById("launchLogoFile").addEventListener("change", (e) => {
        if (e.target.files.length > 0) {
            document.getElementById("launchLogoLabel").innerHTML = `<span class="upload-icon"><i class="ri-check-line"></i></span> ${e.target.files[0].name.substring(0, 20)}`;
        }
    });

    // --- Duplicate Name/Symbol Check ---
    function checkDuplicate(name, symbol) {
        const warnings = [];
        const nameMatch = cachedTokens.find(t => t.name.toLowerCase() === name.toLowerCase());
        const symbolMatch = cachedTokens.find(t => t.symbol.toLowerCase() === symbol.toLowerCase());
        if (nameMatch) warnings.push(`Token name "${name}" already exists (${nameMatch.address.substring(0, 8)}...)`);
        if (symbolMatch) warnings.push(`Symbol "${symbol}" already registered (${symbolMatch.address.substring(0, 8)}...)`);
        return warnings;
    }

    // EVM TX Mutators
    document.getElementById("btnDeployToken").addEventListener("click", async () => {
        if (!isAuthenticated) return;
        const name = document.getElementById("launchName").value;
        const symbol = document.getElementById("launchSymbol").value;
        const supply = document.getElementById("launchSupply").value;
        const fileInput = document.getElementById("launchLogoFile");

        if (!name || !symbol || !supply || fileInput.files.length === 0) return showToast("All fields required including logo.", "error");

        // Duplicate check — hard block
        const dupes = checkDuplicate(name, symbol);
        if (dupes.length > 0) {
            return showToast(`Deployment rejected: ${dupes[0]}`, "error");
        }

        try {
            toggleTxModal(true, "Opening crop tool...");
            toggleTxModal(false);
            const logoBase64 = await openCropModal(fileInput.files[0]);
            if (!logoBase64) return showToast("Crop cancelled.", "info");

            toggleTxModal(true, "Deploying token to Sepolia...");
            const txHash = await Web3Backend.deployToken(name, symbol, supply, logoBase64);
            showToast(`Token deployed. Hash: ${txHash.substring(0, 10)}...`, "success");
            Registry.indexTransaction(txHash, 'deploy', `Deployed ${symbol}`, Web3Backend.address);
            await refreshDashboards();
        } catch (error) { showToast(`Tx Reverted: ${error.message.substring(0, 40)}`, "error"); }
        finally { toggleTxModal(false); }
    });

    document.getElementById("btnCreatePair").addEventListener("click", async () => {
        if (!isAuthenticated) return;
        const tokenA = selectedTokens['factory-0']?.address;
        const tokenB = selectedTokens['factory-1']?.address;
        if (!tokenA || !tokenB) return showToast("Guard Block: Requires 2 assets.", "error");

        try {
            toggleTxModal(true, `Instantiating ${selectedTokens['factory-0'].symbol}/${selectedTokens['factory-1'].symbol} Pool...`);
            const txHash = await Web3Backend.createPair(tokenA, tokenB);
            showToast(`Pool deployed! Hash: ${txHash.substring(0, 10)}...`, "success");
            Registry.indexTransaction(txHash, 'pair', `${selectedTokens['factory-0'].symbol}/${selectedTokens['factory-1'].symbol} Pool`, Web3Backend.address);
            await refreshDashboards();
        } catch (error) { showToast(`Execution Blocked: ${error.message.substring(0, 40)}`, "error"); }
        finally { toggleTxModal(false); }
    });

    document.getElementById("btnSwap").addEventListener("click", async () => {
        if (!isAuthenticated) return;
        const tokenIn = selectedTokens['swap-in'];
        const amountIn = document.getElementById("swapAmountIn").value;
        if (!tokenIn || !amountIn || !activeSwapRouteData) return;

        //  Slippage/Drain Guard Warning
        if (window.activeQuoteOutput !== undefined && window.activeQuoteOutput < 0.0001) {
            const proceed = await promptWarning();
            if (!proceed) return;
        }

        try {
            toggleTxModal(true, `Routing Payload: ${amountIn} ${tokenIn.symbol} via Network...`);
            const txHash = await Web3Backend.executeSwap(activeSwapRouteData.pair_address, tokenIn.address, amountIn);
            showToast(`Swap executed! Hash: ${txHash.substring(0, 10)}...`, "success");
            Registry.indexTransaction(txHash, 'swap', `Swapped ${amountIn} ${tokenIn.symbol}`, Web3Backend.address);
            await refreshDashboards();
        } catch (error) { showToast(`Contract Reverted: ${error.message.substring(0, 60)}...`, "error"); }
        finally { toggleTxModal(false); document.getElementById("swapAmountIn").value = ""; calculateLiveQuote(); }
    });

    // Asset Supply Flow
    document.getElementById("btnMintLiquidity").addEventListener("click", async () => {
        if (!isAuthenticated) return;
        const pair = selectedTokens['pool-pair'];
        const amt0 = document.getElementById("poolAmount0").value;
        const amt1 = document.getElementById("poolAmount1").value;
        if (!pair || !amt0 || !amt1) return showToast("Input Matrix Invalid.", "error");

        try {
            toggleTxModal(true, `Locking ${amt0} Asset A & ${amt1} Asset B into Vault...`);
            const txHash = await Web3Backend.supplyLiquidity(pair.pair_address, pair.token0_address, pair.token1_address, amt0, amt1);
            const t0 = cachedTokens.find(t => t.address === pair.token0_address) || { symbol: "A" };
            const t1 = cachedTokens.find(t => t.address === pair.token1_address) || { symbol: "B" };
            showToast(`LP minted. Hash: ${txHash.substring(0, 10)}`, "success");
            Registry.indexTransaction(txHash, 'mint', `Minted LP for ${t0.symbol}/${t1.symbol}`, Web3Backend.address);

            // LP Success Card — show minted LP info
            const lpBalance = await Web3Backend.getLPBalance(pair.pair_address);
            const pairShort = `${pair.pair_address.substring(0, 6)}...${pair.pair_address.slice(-4)}`;

            // Remove any old success card
            const oldCard = document.querySelector('.lp-success-card');
            if (oldCard) oldCard.remove();

            const successCard = document.createElement('div');
            successCard.className = 'lp-success-card';
            successCard.innerHTML = `
                <h5><i class="ri-checkbox-circle-fill"></i> Liquidity Position Confirmed</h5>
                <div class="lp-detail"><span>LP Tokens Received</span><span>${parseFloat(lpBalance).toFixed(6)}</span></div>
                <div class="lp-detail"><span>Pool</span><span>${t0.symbol}/${t1.symbol}</span></div>
                <div class="lp-detail"><span>LP Contract</span><a href="${ETHERSCAN_BASE}${pair.pair_address}" target="_blank" class="etherscan-link" style="font-size:0.78rem;">${pairShort} <i class="ri-external-link-line"></i></a></div>
            `;
            document.getElementById('add-liquidity').appendChild(successCard);

            await refreshDashboards();
        } catch (error) { showToast(`EVM Error: ${error.message.substring(0, 50)}...`, "error"); }
        finally {
            toggleTxModal(false);
            document.getElementById("poolAmount0").value = "";
            const a1 = document.getElementById("poolAmount1");
            if (a1) a1.value = "";
        }
    });

    // Liquidity Burn & Extraction Execution
    document.getElementById("btnRemoveLiquidity").addEventListener("click", async () => {
        if (!isAuthenticated) return;
        const pair = selectedTokens['pool-remove'];
        const burnAmt = document.getElementById("removeLpAmount").value;
        if (!pair || !burnAmt) return showToast("Extraction Matrix Invalid.", "error");

        try {
            toggleTxModal(true, `Burning ${burnAmt} LP Tokens & Unlocking Reserves...`);
            const txHash = await Web3Backend.removeLiquidity(pair.pair_address, burnAmt);
            showToast(`Extraction complete. Tx: ${txHash.substring(0, 10)}...`, "success");
            Registry.indexTransaction(txHash, 'burn', `Burned LP tokens`, Web3Backend.address);
            await refreshDashboards();

            // Clean UI
            document.getElementById("removeLiquidityCard").style.display = "none";
            document.getElementById("removeLpAmount").value = "";
            document.getElementById("btnSelectPoolRemove").querySelector('.token-symbol').innerHTML = "Select Active LP Vault";

        } catch (error) {
            showToast(`Reverted: ${error.message.substring(0, 50)}...`, "error");
        } finally {
            toggleTxModal(false);
        }
    });

    refreshDashboards();
});
