/**
 * Protocol Configuration & Human Readable ABIs
 * 
 * Defines target network constraints and the strict interface fragments required 
 * for executing calls to the deployed EVM contracts.
 */

const CONFIG = {
    // Expected Ethereum Chain (Sepolia Testnet)
    NETWORK_ID: 11155111, 
    
    // Core Protocol Endpoints
    LAUNCHPAD_ADDRESS: "0xf09fd17a452fd0044a41f198d6af9523e90dc078",
    FACTORY_ADDRESS: "0x0ddbde777dcaf54e7cf075f7f9a0aa89fc9ae60e",
    
    // Global Immutable Indexer (Supabase)
    SUPABASE: {
        URL: "https://wuixfdtiubrqozeskkza.supabase.co",
        KEY: "sb_publishable_fUY-XxvO_xtvnmqhCCiw9g_xUrlxDjb"
    },
    
    // Human-Readable ABI Fragments (Reduces memory footprint compared to full JSON ABIs)
    ABI: {

        LAUNCHPAD: [
            "function createToken(string memory _name, string memory _symbol, uint256 _totalSupply) external returns (address)",
            "event TokenCreated(address indexed tokenAddress, string name, string symbol, uint256 totalSupply, address indexed creator)"
        ],
        FACTORY: [
            "function createPair(address tokenA, address tokenB) external returns (address pair)",
            "function getPair(address, address) external view returns (address)",
            "event PairCreated(address indexed token0, address indexed token1, address pair, uint256)"
        ],
        PAIR: [
            "function mint(uint256 _amount0, uint256 _amount1) external returns (uint MINILP)",
            "function burn(uint256 _MINILPamount) external returns (uint256 amount0, uint256 amount1)",
            "function swap(address _tokenIn, uint112 _amountIn, uint256 _amountOut) external",
            "function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast)",
            "function balanceOf(address account) external view returns (uint256)",
            "function totalSupply() external view returns (uint256)"
        ],
        TOKEN: [
            "function name() external view returns (string)",
            "function symbol() external view returns (string)",
            "function approve(address spender, uint256 amount) external returns (bool)",
            "function allowance(address owner, address spender) external view returns (uint256)",
            "function balanceOf(address account) external view returns (uint256)",
            "function decimals() external view returns (uint8)"
        ]
    }
};
