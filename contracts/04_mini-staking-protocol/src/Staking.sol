// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "./IERC20.sol";

/// @title Mini Staking Protocol
/// @author 0xSchutze
/// @notice A Synthetix-style staking protocol that rewards users linearly over time
contract Staking {
    IERC20 public stakingToken;
    IERC20 public rewardToken;

    uint256 public rewardRate;
    uint256 public totalStaked;
    uint256 public rewardPerTokenStored;
    uint256 public lastUpdateTime;

    mapping(address => uint256) public stakingTokenBalance;
    mapping(address => uint256) public rewardTokenBalance;
    mapping(address => uint256) public userRewardPerTokenPaid;

    // ─── Events ───────────────────────────────────────────────────────────────

    /// @notice Emitted when a user deposits staking tokens
    event Staked(address indexed user, uint256 amount);

    /// @notice Emitted when a user withdraws staking tokens
    event Withdrawn(address indexed user, uint256 amount);

    /// @notice Emitted when a user claims accumulated rewards
    event RewardClaimed(address indexed user, uint256 reward);

    // ─── Constructor ──────────────────────────────────────────────────────────

    /// @notice Initializes the staking protocol
    /// @param _stakingToken The token users will deposit
    /// @param _rewardToken The token users will earn
    /// @param _rewardRate Tokens distributed per second globally
    constructor(address _stakingToken, address _rewardToken, uint256 _rewardRate) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        rewardRate = _rewardRate;
    }

    // ─── Modifiers ────────────────────────────────────────────────────────────

    /// @notice Synchronizes global and per-user reward state before any interaction
    modifier updateReward(address account) {
        _updateReward(account);
        _;
    }

    // ─── Internal ─────────────────────────────────────────────────────────────

    /// @dev Extracted from modifier to reduce deployed bytecode size
    function _updateReward(address account) internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;

        if (account != address(0)) {
            rewardTokenBalance[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
    }

    // ─── View ─────────────────────────────────────────────────────────────────

    /// @notice Calculates the global reward index per token
    /// @dev Accumulates newly elapsed rewards since last update, scaled by 1e18
    /// @return The cumulative reward per single staked token
    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + (((block.timestamp - lastUpdateTime) * rewardRate * 1e18) / totalStaked);
    }

    /// @notice Calculates the total pending rewards for a given user
    /// @param account The user address to query
    /// @return Total claimable reward tokens at the current block
    function earned(address account) public view returns (uint256) {
        uint256 currentRewardPerToken = rewardPerToken();
        uint256 userPastReward = userRewardPerTokenPaid[account];
        return ((stakingTokenBalance[account] * (currentRewardPerToken - userPastReward)) / 1e18) + rewardTokenBalance[account];
    }

    // ─── External ─────────────────────────────────────────────────────────────

    /// @notice Deposit staking tokens to begin earning rewards
    /// @param amount Amount of staking tokens to lock
    function stake(uint256 amount) external updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        totalStaked += amount;
        stakingTokenBalance[msg.sender] += amount;
        require(stakingToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        emit Staked(msg.sender, amount);
    }

    /// @notice Withdraw previously staked tokens
    /// @param amount Amount of staking tokens to retrieve
    function withdraw(uint256 amount) external updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        totalStaked -= amount;
        stakingTokenBalance[msg.sender] -= amount;
        require(stakingToken.transfer(msg.sender, amount), "Transfer failed");
        emit Withdrawn(msg.sender, amount);
    }

    /// @notice Claim all accumulated reward tokens
    function getReward() external updateReward(msg.sender) {
        uint256 reward = rewardTokenBalance[msg.sender];
        require(reward > 0, "No rewards to claim");
        rewardTokenBalance[msg.sender] = 0;
        require(rewardToken.transfer(msg.sender, reward), "Reward transfer failed");
        emit RewardClaimed(msg.sender, reward);
    }
}
