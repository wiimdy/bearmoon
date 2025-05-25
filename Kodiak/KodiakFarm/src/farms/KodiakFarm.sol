// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.8.19;

// *********************************************************************************************************
// @title Modified StakingRewards from Frax/Synthetix for Kodiak
// @author berastotle
// @notice Allows users to stake ERC20 tokens and earn token rewards, with a multiplier based on lock duration
// @dev    Modifications:
// Emergency withdrawal by user is possible if token rewards run out
// Ability to add new reward tokens after contract is deployed
// Ability to configure caps to the total stake in the farm
// Auto-set rewards to zero if they're not refilled by time of reward period renewal
// Remove configuration of rewardSymbols
// Require funding of farm before setting a rewardRate (soft check)
// Separate roles:
// rewardManager: can change reward rates by token,
// owner: can change farm settings, controlled by farm deployer
// *********************************************************************************************************

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "lib/v3-periphery/contracts/libraries/TransferHelper.sol";
import {ReentrancyGuard} from "lib/solady/src/utils/ReentrancyGuard.sol";
import {IFarmFactory} from "src/farms/interfaces/IFarmFactory.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Multicallable} from "lib/solady/src/utils/Multicallable.sol";

contract KodiakFarm is Ownable, ReentrancyGuard, Multicallable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */
    // Effectively immutable
    IFarmFactory public factory;

    // Instances
    IERC20 public stakingToken;
    uint256 public stakingTokenCap; //Configurable maximum cap, default to uncapped

    // Constant for various precisions
    uint256 private constant MULTIPLIER_PRECISION = 1e18;

    // Time tracking
    uint256 public periodFinish;
    uint256 public lastUpdateTime;

    // Lock time and multiplier settings
    uint256 public lock_max_multiplier;
    uint256 public lock_time_for_max_multiplier;
    uint256 public lock_time_min;

    // Reward addresses, rates, and managers
    mapping(address => address) public rewardManagers; // token addr -> manager addr
    address[] public rewardTokens;
    uint256[] public rewardRates;
    mapping(address => uint256) public rewardTokenAddrToIdx; // token addr -> token index

    // Reward period
    uint256 public rewardsDuration;

    // Reward tracking
    uint256[] private rewardsPerTokenStored;
    mapping(address => mapping(uint256 => uint256)) private userRewardsPerTokenPaid; // staker addr -> token id -> paid amount
    mapping(address => mapping(uint256 => uint256)) private rewards; // staker addr -> token id -> reward amount
    mapping(address => uint256) private lastRewardClaimTime; // staker addr -> timestamp

    // Balance tracking
    uint256 private _total_liquidity_locked;
    uint256 private _total_combined_weight;
    mapping(address => uint256) private _locked_liquidity;
    mapping(address => uint256) private _combined_weights;

    // Stake tracking
    mapping(address => LockedStake[]) private lockedStakes;

    // Greylisting of bad addresses
    mapping(address => bool) public greylist;

    // Administrative booleans
    bool public stakesUnlocked; // Release locked stakes in case of emergency
    bool public rewardsCollectionPaused; // For emergencies
    bool public stakingPaused; // For emergencies

    /* ========== STRUCTS ========== */

    struct LockedStake {
        bytes32 kek_id;
        uint256 start_timestamp;
        uint256 liquidity;
        uint256 ending_timestamp;
        uint256 lock_multiplier; // 6 decimals of precision. 1x = 1000000
    }

    /* ========== MODIFIERS ========== */

    modifier onlyTknMgrs(address reward_token_address) {
        require(msg.sender == owner() || isTokenManagerFor(msg.sender, reward_token_address), "Farm: Not owner or tkn mgr");
        _;
    }

    modifier updateRewardAndBalance(address account, bool sync_too) {
        _updateRewardAndBalance(account, sync_too);
        _;
    }

    /* ========== INITIALIZER ========== */
    function initialize(
        address _owner,
        address _stakingToken,
        address[] memory _rewardTokens,
        address[] memory _rewardManagers,
        uint256[] memory _rewardRates,
        bytes calldata /*_data*/
    ) external nonReentrant {
        require(address(stakingToken) == address(0), "Farm: Already initialized");
        stakingToken = IERC20(_stakingToken);

        factory = IFarmFactory(msg.sender);

        require(_rewardTokens.length == _rewardManagers.length, "Farm: Array lengths do not match");
        require(_rewardTokens.length == _rewardRates.length, "Farm: Array lengths do not match");
        rewardTokens = _rewardTokens;
        rewardRates = _rewardRates;

        for (uint256 i = 0; i < _rewardTokens.length; i++) {
            if (i > 0) {
                require(rewardTokenAddrToIdx[_rewardTokens[i]] == 0 && _rewardTokens[i] != rewardTokens[0], "Token already added");
            }
            // For fast token address -> token ID lookups later
            rewardTokenAddrToIdx[_rewardTokens[i]] = i;
            // Initialize the stored rewards
            rewardsPerTokenStored.push(0);
            // Initialize the reward managers
            rewardManagers[_rewardTokens[i]] = _rewardManagers[i];
        }

        // Default settings, use ownerOnly setters to update
        stakingTokenCap = type(uint256).max; //default to uncapped
        rewardsDuration = 30 * 86400; // 30 * 86400  (30 days)
        lock_time_min = 0;
        lock_time_for_max_multiplier = 1 * 30 * 86400; // 30 days
        lock_max_multiplier = uint256(3e18); // E18. 1x = e18

        _transferOwnership(_owner); //Transfer ownership to deployer
    }

    //Call this to start the farm
    function startFarm() external onlyOwner {
        require(!_farmStarted(), "Farm: Already started");

        uint256 _rewardsDuration = rewardsDuration;
        address[] memory _rewardTokens = rewardTokens;
        uint256[] memory _rewardRates = rewardRates;

        for (uint256 i = 0; i < _rewardTokens.length; i++) {
            uint256 fundingNeeded = rewardFundingNeeded(_rewardTokens[i], _rewardRates[i]);
            if (fundingNeeded > 0) {
                TransferHelper.safeTransferFrom(_rewardTokens[i], msg.sender, address(this), fundingNeeded);
            }
        }

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(_rewardsDuration);

        emit FarmStarted();
    }

    /* ========== VIEWS ========== */
    function _farmStarted() private view returns (bool) {
        return lastUpdateTime != 0 && periodFinish != 0;
    }

    // Calculate how much more of the reward token needs to be funded before setting a reward rate
    // Note this is necessary but not sufficient condition, as we get the deficit using the balance, which includes unclaimed tokens
    function rewardFundingNeeded(address _rewardToken, uint256 _rate) public view returns (uint256) {
        uint256 balance = IERC20(_rewardToken).balanceOf(address(this));
        uint256 _rewardsDuration = rewardsDuration;
        uint256 timeToFund;
        if (!_farmStarted()) {
            timeToFund = _rewardsDuration;
        } else if (block.timestamp <= periodFinish) {
            uint256 remainingTime = periodFinish.sub(block.timestamp);
            timeToFund = remainingTime < rewardsDuration / 2 ? remainingTime.add(rewardsDuration) : remainingTime;
        } else if (block.timestamp > periodFinish) {
            uint256 num_periods_elapsed = uint256(block.timestamp.sub(periodFinish)) / rewardsDuration; // Floor division to the nearest period
            timeToFund = rewardsDuration.mul(num_periods_elapsed + 1);
        }

        uint256 amountNeeded = _rate.mul(timeToFund);
        return balance > amountNeeded ? 0 : amountNeeded.sub(balance);
    }

    // Total locked liquidity tokens
    function totalLiquidityLocked() external view returns (uint256) {
        return _total_liquidity_locked;
    }

    // Locked liquidity for a given account
    function lockedLiquidityOf(address account) external view returns (uint256) {
        return _locked_liquidity[account];
    }

    // Total 'balance' used for calculating the percent of the pool the account owns
    // Takes into account the locked stake time multiplier
    function totalCombinedWeight() external view returns (uint256) {
        return _total_combined_weight;
    }

    // Combined weight for a specific account
    function combinedWeightOf(address account) external view returns (uint256) {
        return _combined_weights[account];
    }

    // Calculated the combined weight for an account
    function calcCurCombinedWeight(address account) public view returns (uint256 old_combined_weight, uint256 new_combined_weight) {
        // Get the old combined weight
        old_combined_weight = _combined_weights[account];

        // Loop through the locked stakes, first by getting the liquidity * lock_multiplier portion
        new_combined_weight = 0;
        for (uint256 i = 0; i < lockedStakes[account].length; i++) {
            LockedStake memory thisStake = lockedStakes[account][i];
            uint256 lock_multiplier = thisStake.lock_multiplier;

            // Handles corner case where user never claims for a new stake
            // Don't want the multiplier going above the max
            uint256 accrue_start_time = Math.max(lastRewardClaimTime[account], thisStake.start_timestamp);

            // If the lock is expired
            if (thisStake.ending_timestamp <= block.timestamp) {
                // If the lock expired in the time since the last claim, the weight needs to be proportionately averaged this time
                if (lastRewardClaimTime[account] < thisStake.ending_timestamp) {
                    uint256 time_before_expiry = (thisStake.ending_timestamp).sub(accrue_start_time);
                    uint256 time_after_expiry = (block.timestamp).sub(thisStake.ending_timestamp);
                    uint256 time_sum = time_before_expiry.add(time_after_expiry);

                    if (time_sum == 0) {
                        // Multiplier is 1x if lock time is 0
                        lock_multiplier == MULTIPLIER_PRECISION;
                    } else {
                        // Get the weighted-average lock_multiplier
                        uint256 numerator = ((lock_multiplier).mul(time_before_expiry)).add(((MULTIPLIER_PRECISION).mul(time_after_expiry)));
                        lock_multiplier = numerator.div(time_sum);
                    }
                }
                // Otherwise, it needs to just be 1x
                else {
                    lock_multiplier = MULTIPLIER_PRECISION;
                }
            }

            // Sanity check: make sure it never goes above the initial multiplier
            if (lock_multiplier > thisStake.lock_multiplier) lock_multiplier = thisStake.lock_multiplier;

            uint256 liquidity = thisStake.liquidity;
            uint256 combined_boosted_amount = liquidity.mul(lock_multiplier).div(MULTIPLIER_PRECISION);
            new_combined_weight = new_combined_weight.add(combined_boosted_amount);
        }
    }

    // All the locked stakes for a given account
    function lockedStakesOf(address account) external view returns (LockedStake[] memory) {
        return lockedStakes[account];
    }

    // All the reward token symbols (if they exist)
    function getRewardSymbols() external view returns (string[] memory) {
        uint256 len = rewardTokens.length;
        string[] memory rewardSymbols = new string[](len);

        for (uint256 i = 0; i < len; i++) {
            try IERC20Metadata(rewardTokens[i]).symbol() returns (string memory symbol) {
                rewardSymbols[i] = symbol;
            } catch {
                rewardSymbols[i] = "";
            }
        }

        return rewardSymbols;
    }

    // All the reward tokens
    function getAllRewardTokens() external view returns (address[] memory) {
        return rewardTokens;
    }

    // All the reward rates
    function getAllRewardRates() external view returns (uint256[] memory) {
        return rewardRates;
    }

    // Multiplier amount, given the length of the lock
    function lockMultiplier(uint256 secs) public view returns (uint256) {
        uint256 lock_multiplier = uint256(MULTIPLIER_PRECISION).add(secs.mul(lock_max_multiplier.sub(MULTIPLIER_PRECISION)).div(lock_time_for_max_multiplier));
        if (lock_multiplier > lock_max_multiplier) lock_multiplier = lock_max_multiplier;
        return lock_multiplier;
    }

    // Last time the reward was applicable
    function lastTimeRewardApplicable() internal view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    // Amount of reward tokens per LP token
    function rewardsPerToken() public view returns (uint256[] memory newRewardsPerTokenStored) {
        if (_total_liquidity_locked == 0 || _total_combined_weight == 0) {
            return rewardsPerTokenStored;
        } else {
            newRewardsPerTokenStored = new uint256[](rewardTokens.length);
            for (uint256 i = 0; i < rewardsPerTokenStored.length; i++) {
                newRewardsPerTokenStored[i] = rewardsPerTokenStored[i].add(lastTimeRewardApplicable().sub(lastUpdateTime).mul(rewardRates[i]).mul(1e18).div(_total_combined_weight));
            }
            return newRewardsPerTokenStored;
        }
    }

    // Amount of reward tokens an account has earned / accrued
    // Note: In the edge-case of one of the account's stake expiring since the last claim, this will
    // return a slightly inflated number
    function earned(address account) public view returns (uint256[] memory new_earned) {
        uint256[] memory reward_arr = rewardsPerToken();
        new_earned = new uint256[](rewardTokens.length);

        if (_combined_weights[account] == 0) {
            for (uint256 i = 0; i < rewardTokens.length; i++) {
                new_earned[i] = 0;
            }
        } else {
            for (uint256 i = 0; i < rewardTokens.length; i++) {
                new_earned[i] = (_combined_weights[account]).mul(reward_arr[i].sub(userRewardsPerTokenPaid[account][i])).div(1e18).add(rewards[account][i]);
            }
        }
    }

    // Total reward tokens emitted in the given period
    function getRewardForDuration() external view returns (uint256[] memory rewards_per_duration_arr) {
        rewards_per_duration_arr = new uint256[](rewardRates.length);

        for (uint256 i = 0; i < rewardRates.length; i++) {
            rewards_per_duration_arr[i] = rewardRates[i].mul(rewardsDuration);
        }
    }

    // See if the caller_addr is a manager for the reward token
    function isTokenManagerFor(address caller_addr, address reward_token_addr) public view returns (bool) {
        if (caller_addr == owner()) return true; // Contract owner

        else if (rewardManagers[reward_token_addr] == caller_addr) return true; // Reward manager
        return false;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function _updateRewardAndBalance(address account, bool sync_too) internal {
        require(_farmStarted(), "Farm: not started yet");

        // Need to retro-adjust some things if the period hasn't been renewed, then start a new one
        if (sync_too) {
            sync();
        }

        if (account != address(0)) {
            // To keep the math correct, the user's combined weight must be recomputed
            (uint256 old_combined_weight, uint256 new_combined_weight) = calcCurCombinedWeight(account);

            // Calculate the earnings first
            _syncEarned(account);

            // Update the user's and the global combined weights
            if (new_combined_weight >= old_combined_weight) {
                uint256 weight_diff = new_combined_weight.sub(old_combined_weight);
                _total_combined_weight = _total_combined_weight.add(weight_diff);
                _combined_weights[account] = old_combined_weight.add(weight_diff);
            } else {
                uint256 weight_diff = old_combined_weight.sub(new_combined_weight);
                _total_combined_weight = _total_combined_weight.sub(weight_diff);
                _combined_weights[account] = old_combined_weight.sub(weight_diff);
            }
        }
    }

    function _syncEarned(address account) internal {
        if (account != address(0)) {
            // Calculate the earnings
            uint256[] memory earned_arr = earned(account);

            // Update the rewards array
            for (uint256 i = 0; i < earned_arr.length; i++) {
                rewards[account][i] = earned_arr[i];
            }

            // Update the rewards paid array
            for (uint256 i = 0; i < earned_arr.length; i++) {
                userRewardsPerTokenPaid[account][i] = rewardsPerTokenStored[i];
            }
        }
    }

    function stakeLocked(uint256 liquidity, uint256 secs) public nonReentrant {
        _stakeLocked(msg.sender, liquidity, secs, block.timestamp);
    }

    function _stakeLocked(address user, uint256 liquidity, uint256 secs, uint256 start_timestamp) internal updateRewardAndBalance(user, true) {
        require(!stakingPaused, "Staking paused");
        require(liquidity > 0, "Must stake more than zero");
        require(_total_liquidity_locked.add(liquidity) <= stakingTokenCap, "Farm cap exceeded");
        require(!greylist[user], "Address has been greylisted");
        require(secs >= lock_time_min, "Minimum stake time not met");
        require(secs <= lock_time_for_max_multiplier, "Trying to lock for too long");

        uint256 lock_multiplier = lockMultiplier(secs);
        bytes32 kek_id = keccak256(abi.encodePacked(user, start_timestamp, liquidity, _locked_liquidity[user]));
        lockedStakes[user].push(LockedStake(kek_id, start_timestamp, liquidity, start_timestamp.add(secs), lock_multiplier));

        // Pull tokens from the user
        TransferHelper.safeTransferFrom(address(stakingToken), user, address(this), liquidity);

        // Update liquidities
        _total_liquidity_locked = _total_liquidity_locked.add(liquidity);
        _locked_liquidity[user] = _locked_liquidity[user].add(liquidity);

        // Need to call to update the combined weights
        _updateRewardAndBalance(user, false);

        // Needed for edge case if the staker only claims once, and after the lock expired
        if (lastRewardClaimTime[user] == 0) lastRewardClaimTime[user] = block.timestamp;

        emit StakeLocked(user, liquidity, secs, kek_id);
    }

    // Two different withdrawLocked functions are needed because of delegateCall and msg.sender issues
    function withdrawLocked(bytes32 kek_id) public nonReentrant {
        _withdrawLocked(msg.sender, kek_id, true);
    }

    function withdrawLockedMultiple(bytes32[] memory kek_ids) public nonReentrant {
        _getReward(msg.sender);
        for (uint256 i = 0; i < kek_ids.length; i++) {
            _withdrawLocked(msg.sender, kek_ids[i], false); //don't collect rewards each iteration
        }
    }

    function withdrawLockedAll() public nonReentrant {
        _getReward(msg.sender);
        LockedStake[] memory locks = lockedStakes[msg.sender];
        for (uint256 i = 0; i < locks.length; i++) {
            if (locks[i].liquidity > 0 && block.timestamp >= locks[i].ending_timestamp) {
                _withdrawLocked(msg.sender, locks[i].kek_id, false);
            }
        }
    }

    //Emergency withdraw forgoes rewards
    function emergencyWithdraw(bytes32 kek_id) public nonReentrant {
        _withdrawLocked(msg.sender, kek_id, false);
    }

    function _withdrawLocked(address user, bytes32 kek_id, bool collectRewards) internal {
        // Collect rewards first and then update the balances
        if (collectRewards) {
            _getReward(user);
        }

        LockedStake memory thisStake;
        thisStake.liquidity = 0;
        uint256 theArrayIndex;
        uint256 stakesLength = lockedStakes[user].length;

        for (uint256 i = 0; i < stakesLength; i++) {
            if (kek_id == lockedStakes[user][i].kek_id) {
                thisStake = lockedStakes[user][i];
                theArrayIndex = i;
                break;
            }
        }
        require(thisStake.kek_id == kek_id, "Stake not found");
        require(block.timestamp >= thisStake.ending_timestamp || stakesUnlocked == true, "Stake is still locked!");

        uint256 liquidity = thisStake.liquidity;

        if (liquidity > 0) {
            // Update liquidities
            _total_liquidity_locked = _total_liquidity_locked.sub(liquidity);
            _locked_liquidity[user] = _locked_liquidity[user].sub(liquidity);

            // Remove the stake from the array
            // Step 1: If it's not the last element, copy the last element to the index where you want to remove an element
            if (theArrayIndex < stakesLength - 1) {
                lockedStakes[user][theArrayIndex] = lockedStakes[user][stakesLength - 1];
            }

            // Step 2: Remove the last element (pop the array)
            lockedStakes[user].pop();

            // Need to call to update the combined weights
            _updateRewardAndBalance(user, false);

            // Give the tokens to the destination_address
            // Should throw if insufficient balance
            TransferHelper.safeTransfer(address(stakingToken), user, liquidity);

            emit WithdrawLocked(user, liquidity, kek_id);
        }
    }

    // Two different getReward functions are needed because of delegateCall and msg.sender issues
    function getReward() external nonReentrant returns (uint256[] memory) {
        require(!rewardsCollectionPaused, "Rewards collection paused");
        return _getReward(msg.sender);
    }

    // No withdrawer == msg.sender check needed since this is only internally callable
    function _getReward(address user) internal updateRewardAndBalance(user, true) returns (uint256[] memory rewards_before) {
        require(!rewardsCollectionPaused, "Farm: Rewards emergency paused, use emergencyWithdraw if necessary");

        // Update the rewards array and distribute rewards
        rewards_before = new uint256[](rewardTokens.length);

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            rewards_before[i] = rewards[user][i];
            if (rewards_before[i] > 0) {
                rewards[user][i] = 0;
                TransferHelper.safeTransfer(rewardTokens[i], user, rewards_before[i]);
                emit RewardPaid(user, rewards_before[i], rewardTokens[i]);
            }
        }

        lastRewardClaimTime[user] = block.timestamp;
    }

    // If the period expired, renew it
    function _retroCatchUp() internal {
        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint256 num_periods_elapsed = uint256(block.timestamp.sub(periodFinish)) / rewardsDuration; // Floor division to the nearest period

        // Make sure there are enough tokens to renew the reward period
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            bool haveTokensToRenew = rewardRates[i].mul(rewardsDuration).mul(num_periods_elapsed + 1) <= IERC20(rewardTokens[i]).balanceOf(address(this));
            if (!haveTokensToRenew) {
                // if there aren't enough tokens to renew the reward period, zero out the rewardRate
                rewardRates[i] = 0;
                emit RewardRateUpdated(rewardTokens[i], 0);
            }
        }

        periodFinish = periodFinish.add((num_periods_elapsed.add(1)).mul(rewardsDuration));

        _updateStoredRewardsAndTime();

        emit RewardsPeriodRenewed(address(stakingToken));
    }

    function _updateStoredRewardsAndTime() internal {
        // Get the rewards
        uint256[] memory rewards_per_token = rewardsPerToken();

        // Update the rewardsPerTokenStored
        for (uint256 i = 0; i < rewardsPerTokenStored.length; i++) {
            rewardsPerTokenStored[i] = rewards_per_token[i];
        }

        // Update the last stored time
        lastUpdateTime = lastTimeRewardApplicable();
    }

    function sync() public {
        require(_farmStarted(), "Farm: not started yet");
        if (block.timestamp >= periodFinish) {
            _retroCatchUp();
        } else {
            _updateStoredRewardsAndTime();
        }
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    // Added to support recovering LP Rewards and other mistaken tokens from other systems to be distributed to holders
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyTknMgrs(tokenAddress) {
        // Cannot rug the staking / LP tokens
        require(tokenAddress != address(stakingToken), "Cannot rug staking / LP tokens");

        // Check if the desired token is a reward token
        bool isRewardToken = false;
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            if (rewardTokens[i] == tokenAddress) {
                isRewardToken = true;
                break;
            }
        }

        // Only the reward managers can take back their reward tokens
        // Note: this resets rewardRate to zero, must set using setRewardRate
        if (isRewardToken && rewardManagers[tokenAddress] == msg.sender) {
            rewardRates[rewardTokenAddrToIdx[tokenAddress]] = 0;
            TransferHelper.safeTransfer(tokenAddress, msg.sender, tokenAmount);
            emit Recovered(msg.sender, tokenAddress, tokenAmount);
            emit RewardRateUpdated(tokenAddress, 0);
            return;
        }
        // Other tokens, like airdrops or accidental deposits, can be withdrawn by the owner
        else if (!isRewardToken && (msg.sender == owner())) {
            TransferHelper.safeTransfer(tokenAddress, msg.sender, tokenAmount);
            emit Recovered(msg.sender, tokenAddress, tokenAmount);
            return;
        }
        // If none of the above conditions are true
        else {
            revert("No valid tokens to recover");
        }
    }

    function setRewardsDuration(uint256 _rewardsDuration) external onlyOwner {
        require(_rewardsDuration >= 86400, "Rewards duration too short");
        require(periodFinish == 0 || block.timestamp > periodFinish, "Reward period incomplete");
        rewardsDuration = _rewardsDuration;
        emit RewardsDurationUpdated(rewardsDuration);
    }

    function setMultipliers(uint256 _lock_max_multiplier) external onlyOwner {
        require(_lock_max_multiplier >= uint256(1e18), "Multiplier must be greater than or equal to 1e18");
        lock_max_multiplier = _lock_max_multiplier;
        emit LockedStakeMaxMultiplierUpdated(lock_max_multiplier);
    }

    function setLockedStakeTimeForMinAndMaxMultiplier(uint256 _lock_time_for_max_multiplier, uint256 _lock_time_min) external onlyOwner {
        require(_lock_time_for_max_multiplier >= 1, "Mul max time must be >= 1");
        require(_lock_time_for_max_multiplier >= _lock_time_min, "Mul max time must be >= min time");

        lock_time_for_max_multiplier = _lock_time_for_max_multiplier;
        lock_time_min = _lock_time_min;

        emit LockedStakeTimeForMaxMultiplier(lock_time_for_max_multiplier);
        emit LockedStakeMinTime(_lock_time_min);
    }

    function setGreylist(address _address, bool _status) external onlyOwner {
        greylist[_address] = _status;
        emit GreylistSet(_address, _status);
    }

    function setStakesUnlocked(bool _status) external onlyOwner {
        stakesUnlocked = _status;
        emit StakesUnlockedSet(_status);
    }

    function setStakingPaused(bool _status) external onlyOwner {
        stakingPaused = _status;
        emit StakingPausedSet(_status);
    }

    function setRewardsCollectionPaused(bool _status) external onlyOwner {
        rewardsCollectionPaused = _status;
        emit RewardsCollectionPausedSet(_status);
    }

    // The owner or the reward token managers can set reward rates
    function setRewardRate(address _rewardToken, uint256 _rewardRate, bool sync_too) external onlyTknMgrs(_rewardToken) {
        uint256 i = rewardTokenAddrToIdx[_rewardToken];
        uint256 old_rate = rewardRates[i];
        if (_rewardRate > old_rate && _farmStarted()) {
            uint256 fundingNeeded = rewardFundingNeeded(_rewardToken, _rewardRate);
            if (fundingNeeded > 0) {
                TransferHelper.safeTransferFrom(_rewardToken, msg.sender, address(this), fundingNeeded);
            }
        }

        rewardRates[i] = _rewardRate;

        if (sync_too) {
            sync();
        }

        emit RewardRateUpdated(_rewardToken, _rewardRate);
    }

    // The owner or the reward token managers can change managers
    function changeTokenManager(address reward_token_address, address new_manager_address) external onlyTknMgrs(reward_token_address) {
        rewardManagers[reward_token_address] = new_manager_address;
        emit RewardManagerSet(reward_token_address, new_manager_address);
    }

    function addNewRewardToken(address _rewardToken, address _rewardManager, uint256 _rewardRate) external onlyOwner {
        require(_rewardToken != address(0), "Zero address detected");
        require(rewardTokenAddrToIdx[_rewardToken] == 0 && _rewardToken != rewardTokens[0], "Token already added");

        if (_farmStarted()) {
            sync();
            uint256 fundingNeeded = rewardFundingNeeded(_rewardToken, _rewardRate);
            if (fundingNeeded > 0) {
                TransferHelper.safeTransferFrom(_rewardToken, msg.sender, address(this), fundingNeeded);
            }
        }

        rewardTokens.push(_rewardToken);
        rewardRates.push(_rewardRate);

        rewardTokenAddrToIdx[_rewardToken] = rewardTokens.length - 1;
        rewardsPerTokenStored.push(0);
        rewardManagers[_rewardToken] = _rewardManager;

        emit RewardTokenAdded(_rewardToken);
    }

    function setStakingTokenCap(uint256 _stakingTokenCap) external onlyOwner {
        stakingTokenCap = _stakingTokenCap;
        emit StakingTokenCapUpdated(_stakingTokenCap);
    }

    /* ========== EVENTS ========== */

    event StakeLocked(address indexed user, uint256 amount, uint256 secs, bytes32 kek_id);
    event WithdrawLocked(address indexed user, uint256 amount, bytes32 kek_id);
    event RewardPaid(address indexed user, uint256 reward, address indexed token_address);
    event RewardsDurationUpdated(uint256 newDuration);
    event RewardRateUpdated(address indexed token, uint256 newRate);
    event RewardManagerSet(address indexed token, address newManager);
    event Recovered(address indexed destination_address, address indexed token, uint256 amount);
    event RewardsPeriodRenewed(address indexed token);
    event LockedStakeMaxMultiplierUpdated(uint256 multiplier);
    event LockedStakeTimeForMaxMultiplier(uint256 secs);
    event LockedStakeMinTime(uint256 secs);
    event RewardTokenAdded(address rewardToken);
    event StakingTokenCapUpdated(uint256 stakingTokenCap);
    event StakingPausedSet(bool _status);
    event RewardsCollectionPausedSet(bool _status);
    event StakesUnlockedSet(bool _status);
    event GreylistSet(address indexed _address, bool _status);
    event FarmStarted();
}
