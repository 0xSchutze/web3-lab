
/**
 * Execution Layer / Web3 Platform
 * 
 * Interfaces with Ethereum (Sepolia), tracks user balances, securely dispatches payload txs,
 * and forces synchronisation with the Global Supabase Indexer on success.
 */

const Web3Backend = {
    provider: null,
    signer: null,
    address: null,
    // Public read-only provider for unauthenticated queries
    publicProvider: new ethers.JsonRpcProvider("https://eth-sepolia.g.alchemy.com/v2/zoCoAnXb6mbsbxljbinoK"),

    async authenticate() {
        if (!window.ethereum) throw new Error("No Web3 provider detected in browser scope.");

        this.provider = new ethers.BrowserProvider(window.ethereum);
        await this.provider.send("eth_requestAccounts", []);

        this.signer = await this.provider.getSigner();
        this.address = await this.signer.getAddress();

        const network = await this.provider.getNetwork();
        if (network.chainId !== BigInt(CONFIG.NETWORK_ID)) {
            throw new Error(`Execution halted: Client must connect to ChainID ${CONFIG.NETWORK_ID} (Sepolia).`);
        }

        return this.address;
    },

    /** Retrieves the normalized balance of an ERC20 token for the connected wallet */
    async fetchBalance(tokenAddress) {
        if (!this.address) return "0.0";
        try {
            const token = new ethers.Contract(tokenAddress, CONFIG.ABI.TOKEN, this.provider);
            const bal = await token.balanceOf(this.address);
            return ethers.formatUnits(bal, 18); // Assumes 18 decimals for lab standard
        } catch {
            return "0.0"; // Fallback if execution reverts
        }
    },

    /** Extracts Constant Product invariants without gas overhead */
    async getReserves(pairAddress) {
        const p = this.provider || this.publicProvider;
        try {
            const pair = new ethers.Contract(pairAddress, CONFIG.ABI.PAIR, p);
            const res = await pair.getReserves();
            return { r0: res[0], r1: res[1] };
        } catch (e) {
            console.error("getReserves RPC Fault:", e);
            if (window.showToast) window.showToast("RPC Fetch Failed: " + e.message, "error");
            return { r0: 0n, r1: 0n };
        }
    },

    /** LP Token Analytics & Ownership mapping */
    async getLPBalance(pairAddress) {
        if (!this.address || !this.provider) return "0.0";
        try {
            const pair = new ethers.Contract(pairAddress, CONFIG.ABI.PAIR, this.provider);
            const bal = await pair.balanceOf(this.address);
            return ethers.formatUnits(bal, 18);
        } catch { return "0.0"; }
    },

    /** Globals for LP Share computation */
    async getLPTotalSupply(pairAddress) {
        const p = this.provider || this.publicProvider;
        try {
            const pair = new ethers.Contract(pairAddress, CONFIG.ABI.PAIR, p);
            const total = await pair.totalSupply();
            return ethers.formatUnits(total, 18);
        } catch { return "0.0"; }
    },

    async _ensureAllowance(tokenAddress, spenderAddress, amount) {
        const token = new ethers.Contract(tokenAddress, CONFIG.ABI.TOKEN, this.signer);
        const currentAllowance = await token.allowance(this.address, spenderAddress);

        if (currentAllowance < amount) {
            const tx = await token.approve(spenderAddress, ethers.MaxUint256);
            await tx.wait();
        }
    },

    /**
     * Deploys ERC20 & Mutates Global Index
     */
    async deployToken(name, symbol, supply, logoUrl) {
        if (!this.signer) throw new Error("Unauthenticated access attempt.");

        const launchpad = new ethers.Contract(CONFIG.LAUNCHPAD_ADDRESS, CONFIG.ABI.LAUNCHPAD, this.signer);
        const supplyToMint = ethers.parseUnits(supply.toString(), 18);

        const tx = await launchpad.createToken(name, symbol, supplyToMint);
        const receipt = await tx.wait(); // Confirm execution

        // EVM Log Extraction (Deterministic indexing via emitted events)
        let tokenAddr = "0xUnknownGeneratedContract";
        for (const log of receipt.logs) {
            try {
                const parsedLog = launchpad.interface.parseLog(log);
                if (parsedLog && parsedLog.name === "TokenCreated") {
                    tokenAddr = parsedLog.args.tokenAddress;
                    break;
                }
            } catch (e) { /* ignore unrecognizable internal logs */ }
        }

        // Database Persistence (Supabase)
        await Registry.indexToken(tokenAddr, name, symbol, logoUrl, this.address);

        return tx.hash;
    },

    async createPair(tokenA, tokenB) {
        if (!this.signer) throw new Error("Unauthenticated access attempt.");

        const factory = new ethers.Contract(CONFIG.FACTORY_ADDRESS, CONFIG.ABI.FACTORY, this.signer);
        const tx = await factory.createPair(tokenA, tokenB);
        const receipt = await tx.wait(); // Confirm Execution

        // EVM Event Parsing
        let pairAddr = null;
        for (const log of receipt.logs) {
            try {
                const parsedLog = factory.interface.parseLog(log);
                if (parsedLog && parsedLog.name === "PairCreated") {
                    pairAddr = parsedLog.args.pair;
                    break;
                }
            } catch (e) {}
        }
        
        // Fallback state query just in case RPC failed to attach the receipt log natively
        if (!pairAddr) pairAddr = await factory.getPair(tokenA, tokenB); 

        // Index the final pair using global registry
        if (pairAddr && pairAddr !== ethers.ZeroAddress) {
            await Registry.indexPair(pairAddr, tokenA, tokenB, this.address);
        }

        return tx.hash;
    },

    async supplyLiquidity(pairAddress, tokenA, tokenB, amountA, amountB) {
        if (!this.signer) throw new Error("Unauthenticated access attempt.");
        let amount0 = ethers.parseUnits(amountA.toString(), 18);
        let amount1 = ethers.parseUnits(amountB.toString(), 18);

        const pair = new ethers.Contract(pairAddress, CONFIG.ABI.PAIR, this.signer);
        const { r0, r1 } = await this.getReserves(pairAddress);
        
        if (r0 > 0n && r1 > 0n) {
            // GCD-aligned ratio: guarantees (a0 * r1) == (a1 * r0) with ZERO remainder
            // Reduce reserves to simplest ratio
            const g = this._gcd(r0, r1);
            const p = r0 / g;  // simplified reserve0 unit
            const q = r1 / g;  // simplified reserve1 unit
            
            // Find largest k such that k*p <= amount0
            const k = amount0 / p;
            amount0 = k * p;
            amount1 = k * q;
            // Proof: a0*r1 = k*p*(q*g) = k*p*q*g = a1*r0 = k*q*(p*g) ✓
        }

        await this._ensureAllowance(tokenA, pairAddress, amount0);
        await this._ensureAllowance(tokenB, pairAddress, amount1);
        const tx = await pair.mint(amount0, amount1);
        await tx.wait();
        return tx.hash;
    },

    /** BigInt GCD for ratio alignment */
    _gcd(a, b) {
        while (b > 0n) { [a, b] = [b, a % b]; }
        return a;
    },

    async executeSwap(pairAddress, tokenIn, amountIn) {
        if (!this.signer) throw new Error("Unauthenticated access attempt.");
        const amountInParsed = ethers.parseUnits(amountIn.toString(), 18);

        await this._ensureAllowance(tokenIn, pairAddress, amountInParsed);

        const pair = new ethers.Contract(pairAddress, CONFIG.ABI.PAIR, this.signer);
        const tx = await pair.swap(tokenIn, amountInParsed, 0); 
        await tx.wait();

        return tx.hash;
    },

    /** Liquidity Extraction Engine */
    async removeLiquidity(pairAddress, lpAmount) {
        if (!this.signer) throw new Error("Unauthenticated access attempt.");
        const amount = ethers.parseUnits(lpAmount.toString(), 18);
        
        // Our Mini-DEX Core architecture burns directly from msg.sender without needing transfer/allowance
        const pair = new ethers.Contract(pairAddress, CONFIG.ABI.PAIR, this.signer);
        const tx = await pair.burn(amount);
        await tx.wait();
        
        return tx.hash;
    }
};
