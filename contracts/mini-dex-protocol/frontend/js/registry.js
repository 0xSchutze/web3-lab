/**
 * Global Indexer Interface / Serverless Database Layer
 * 
 * Interacts with the Supabase PostgreSQL cluster to fetch and register 
 * immutable DEX entities (Tokens and Pairs). Follows strict RLS protocols.
 */

const Registry = {
    client: null,

    init() {
        if (!window.supabase) throw new Error("Execution halted: Supabase CDN not loaded in DOM.");
        // Initialize client using global config endpoints
        this.client = window.supabase.createClient(CONFIG.SUPABASE.URL, CONFIG.SUPABASE.KEY);
    },

    /**
     * Commits a newly launched token into the global index.
     * Subject to RLS: Public Insert Only. No Deletes/Updates.
     */
    async indexToken(address, name, symbol, logoUrl, creatorAddress) {
        if (!this.client) this.init();
        
        const payload = { 
            address: address.toLowerCase(), 
            name: name, 
            symbol: symbol, 
            logo_url: logoUrl,
            creator_address: creatorAddress.toLowerCase()
        };

        const { error } = await this.client.from('tokens').insert([payload]);
            
        if (error) throw new Error("Indexer Synchronization Failed: " + error.message);
        return true;
    },

    /**
     * Retrieves the comprehensive global token registry.
     */
    async getTokens() {
        if (!this.client) this.init();
        
        const { data, error } = await this.client
            .from('tokens')
            .select('*')
            .order('created_at', { ascending: false });
            
        if (error) {
            console.warn("Registry Warning: Fetch tokens failed.", error);
            return [];
        }
        return data;
    },

    /**
     * Commits a new liquidity pair deployment.
     */
    async indexPair(pairAddress, token0, token1, creatorAddress) {
        if (!this.client) this.init();
        
        const payload = { 
            pair_address: pairAddress.toLowerCase(), 
            token0_address: token0.toLowerCase(), 
            token1_address: token1.toLowerCase(),
            creator_address: creatorAddress.toLowerCase()
        };

        const { error } = await this.client.from('pairs').insert([payload]);
            
        if (error) throw new Error("Pair Synchronization Failed: " + error.message);
        return true;
    },

    /**
     * Retrieves all registered pairs.
     */
    async getPairs() {
        if (!this.client) this.init();
        
        const { data, error } = await this.client
            .from('pairs')
            .select('*')
            .order('created_at', { ascending: false });
            
        if (error) {
            console.warn("Registry Warning: Fetch pairs failed.", error);
            return [];
        }
        return data;
    },

    /**
     * Commits a transaction record to the global activity log.
     */
    async indexTransaction(txHash, txType, details, walletAddress) {
        if (!this.client) this.init();
        
        const payload = {
            tx_hash: txHash,
            tx_type: txType,
            details: details,
            wallet_address: walletAddress.toLowerCase()
        };

        try {
            await this.client.from('transactions').insert([payload]);
        } catch (e) {
            console.warn("Transaction indexing failed (table may not exist):", e);
        }
    },

    /**
     * Retrieves recent transactions for the connected wallet.
     */
    async getTransactions(walletAddress, limit = 10) {
        if (!this.client) this.init();
        
        try {
            const { data, error } = await this.client
                .from('transactions')
                .select('*')
                .eq('wallet_address', walletAddress.toLowerCase())
                .order('created_at', { ascending: false })
                .limit(limit);
                
            if (error) return [];
            return data || [];
        } catch {
            return [];
        }
    }
};
