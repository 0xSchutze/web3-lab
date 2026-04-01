const CONFIG = {
  SEPOLIA_CHAIN_ID: "0xaa36a7", // 11155111

  FACTORY_ADDRESS: "0xfc5A57AB765Da9980d1E6E244F173BF6AfC3f286",

  FACTORY_ABI: [
    "function createVault() external",
    "function getVaultByOwner() external view returns (address)",
    "function getAllVaults() external view returns (address[])",
    "function getTotalVaults() external view returns (uint256)",
    "function vaultCount(address) external view returns (uint256)",
    "event VaultCreated(address indexed owner, address indexed vault, uint256 date)",
  ],

  VAULT_ABI: [
    // Read State
    "function owner() external view returns (address)",
    "function paused() external view returns (bool)",
    "function getBalance() external view returns (uint256)",
    "function getTokenBalance(address token) external view returns (uint256)",
    "function allowedTokens(address token) external view returns (bool)",
    "function approvedAddress(address addr) external view returns (bool)",
    "function authorizedAddresses(uint256 index) external view returns (address)",
    
    // Write Actions
    "function depositEth() external payable",
    "function withdrawEth(uint256 amount) external",
    "function depositToken(address token, uint256 amount) external",
    "function withdrawToken(address token, uint256 amount) external",
    "function addTokenToWhitelist(address token) external",
    "function removeTokenFromWhitelist(address token) external",
    "function approveAddress(address addr) external",
    "function removeApproval(address addr) external",
    "function transferOwnership(address newOwner) external",
    "function pause() external",
    "function unpause() external",

    // Events
    "event Deposit(uint256 amount, uint256 txDate)",
    "event Withdraw(address indexed to, uint256 amount, uint256 txDate)",
    "event DepositToken(address indexed from, address indexed vault, address indexed token, uint256 amount)",
    "event WithdrawToken(address indexed to, address indexed token, uint256 amount)",
    "event OwnershipTransferred(address indexed from, address indexed newOwner)",
    "event AddressAuthorized(address indexed authorizedAddress)",
    "event AuthorizationRemoved(address indexed who, uint256 date)",
    "event TokenWhitelisted(address indexed token, address indexed by, uint256 date)",
    "event TokenRemovedFromWhitelist(address indexed token, address indexed by, uint256 date)",
    "event Paused(address indexed by)",
    "event Unpaused(address indexed by)"
  ],

  ERC20_ABI: [
    "function approve(address spender, uint256 amount) external returns (bool)",
    "function allowance(address owner, address spender) external view returns (uint256)",
    "function balanceOf(address account) external view returns (uint256)",
    "function decimals() external view returns (uint8)",
    "function symbol() external view returns (string)",
  ],
};
