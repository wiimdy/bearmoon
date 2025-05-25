// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IReward} from "../interfaces/IReward.sol";
import {IVoter} from "../interfaces/IVoter.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import {ReentrancyGuard} from
    "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {VelodromeTimeLibrary} from "../libraries/VelodromeTimeLibrary.sol";

/**
 * @title Reward
 * @author velodrome.finance, @figs999, @pegahcarter
 * @notice Base implementation for reward distribution contracts
 * @dev Abstract contract providing core reward distribution functionality
 */
abstract contract Reward is IReward, ReentrancyGuard {
    using SafeTransferLib for ERC20;

    /// @inheritdoc IReward
    uint256 public constant DURATION = 7 days;

    /// @inheritdoc IReward
    address public immutable voter;
    /// @inheritdoc IReward
    address public immutable ve;
    /// @inheritdoc IReward
    address public immutable authorized;
    /// @inheritdoc IReward
    uint256 public totalSupply;
    /// @inheritdoc IReward
    uint256 public supplyNumCheckpoints;
    /**
     * @notice List of all reward tokens supported by this contract
     * @dev Used for token enumeration and management
     */
    address[] public rewards;
    /// @inheritdoc IReward
    mapping(uint256 => uint256) public balanceOf;
    /// @inheritdoc IReward
    mapping(address => mapping(uint256 => uint256)) public tokenRewardsPerEpoch;
    /// @inheritdoc IReward
    mapping(address => mapping(uint256 => uint256)) public lastEarn;
    /// @inheritdoc IReward
    mapping(address => bool) public isReward;
    /// @notice A record of balance checkpoints for each account, by index
    mapping(uint256 => mapping(uint256 => Checkpoint)) public checkpoints;
    /// @inheritdoc IReward
    mapping(uint256 => uint256) public numCheckpoints;
    /// @notice A record of balance checkpoints for each token, by index
    mapping(uint256 => SupplyCheckpoint) public supplyCheckpoints;

    /**
     * @notice Initializes reward contract with voter address
     * @param _voter Address of voter contract managing rewards
     */
    constructor(address _voter) {
        voter = _voter;
        ve = IVoter(_voter).ve();
    }

    /// @inheritdoc IReward
    function getPriorBalanceIndex(uint256 tokenId, uint256 timestamp)
        public
        view
        returns (uint256)
    {
        uint256 nCheckpoints = numCheckpoints[tokenId];
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (checkpoints[tokenId][nCheckpoints - 1].timestamp <= timestamp) {
            return (nCheckpoints - 1);
        }

        // Next check implicit zero balance
        if (checkpoints[tokenId][0].timestamp > timestamp) {
            return 0;
        }

        uint256 lower = 0;
        uint256 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint256 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[tokenId][center];
            if (cp.timestamp == timestamp) {
                return center;
            } else if (cp.timestamp < timestamp) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return lower;
    }

    /// @inheritdoc IReward
    function getPriorSupplyIndex(uint256 timestamp)
        public
        view
        returns (uint256)
    {
        uint256 nCheckpoints = supplyNumCheckpoints;
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (supplyCheckpoints[nCheckpoints - 1].timestamp <= timestamp) {
            return (nCheckpoints - 1);
        }

        // Next check implicit zero balance
        if (supplyCheckpoints[0].timestamp > timestamp) {
            return 0;
        }

        uint256 lower = 0;
        uint256 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint256 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            SupplyCheckpoint memory cp = supplyCheckpoints[center];
            if (cp.timestamp == timestamp) {
                return center;
            } else if (cp.timestamp < timestamp) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return lower;
    }
    /**
     * @notice Writes user checkpoint with updated balance
     * @dev Updates or creates checkpoint based on epoch timing
     * @param tokenId ID of veNFT to checkpoint
     * @param balance New balance to record
     */

    function _writeCheckpoint(uint256 tokenId, uint256 balance) internal {
        uint256 _nCheckPoints = numCheckpoints[tokenId];
        uint256 _timestamp = block.timestamp;

        if (
            _nCheckPoints > 0
                && VelodromeTimeLibrary.epochStart(
                    checkpoints[tokenId][_nCheckPoints - 1].timestamp
                ) == VelodromeTimeLibrary.epochStart(_timestamp)
        ) {
            checkpoints[tokenId][_nCheckPoints - 1] =
                Checkpoint(_timestamp, balance);
        } else {
            checkpoints[tokenId][_nCheckPoints] =
                Checkpoint(_timestamp, balance);
            numCheckpoints[tokenId] = _nCheckPoints + 1;
        }
    }
    /**
     * @notice Writes global supply checkpoint
     * @dev Updates or creates checkpoint based on epoch timing
     */

    function _writeSupplyCheckpoint() internal {
        uint256 _nCheckPoints = supplyNumCheckpoints;
        uint256 _timestamp = block.timestamp;

        if (
            _nCheckPoints > 0
                && VelodromeTimeLibrary.epochStart(
                    supplyCheckpoints[_nCheckPoints - 1].timestamp
                ) == VelodromeTimeLibrary.epochStart(_timestamp)
        ) {
            supplyCheckpoints[_nCheckPoints - 1] =
                SupplyCheckpoint(_timestamp, totalSupply);
        } else {
            supplyCheckpoints[_nCheckPoints] =
                SupplyCheckpoint(_timestamp, totalSupply);
            supplyNumCheckpoints = _nCheckPoints + 1;
        }
    }

    /// @inheritdoc IReward
    function rewardsListLength() external view returns (uint256) {
        return rewards.length;
    }

    /// @inheritdoc IReward
    function earned(address token, uint256 tokenId)
        public
        view
        returns (uint256)
    {
        if (numCheckpoints[tokenId] == 0) {
            return 0;
        }

        uint256 reward = 0;
        uint256 _supply = 1;
        uint256 _currTs =
            VelodromeTimeLibrary.epochStart(lastEarn[token][tokenId]); // take epoch last claimed in as starting point
        uint256 _index = getPriorBalanceIndex(tokenId, _currTs);
        Checkpoint memory cp0 = checkpoints[tokenId][_index];

        // accounts for case where lastEarn is before first checkpoint
        // max value
        _currTs = _currTs > VelodromeTimeLibrary.epochStart(cp0.timestamp)
            ? _currTs
            : VelodromeTimeLibrary.epochStart(cp0.timestamp);

        // get epochs between current epoch and first checkpoint in same epoch as last claim
        uint256 numEpochs = (
            VelodromeTimeLibrary.epochStart(block.timestamp) - _currTs
        ) / DURATION;

        if (numEpochs > 0) {
            for (uint256 i = 0; i < numEpochs; i++) {
                // get index of last checkpoint in this epoch
                _index = getPriorBalanceIndex(tokenId, _currTs + DURATION - 1);
                // get checkpoint in this epoch
                cp0 = checkpoints[tokenId][_index];
                // get supply of last checkpoint in this epoch
                // max value
                uint256 supplyCP = supplyCheckpoints[getPriorSupplyIndex(
                    _currTs + DURATION - 1
                )].supply;
                _supply = supplyCP > 1 ? supplyCP : 1;
                reward += (cp0.balanceOf * tokenRewardsPerEpoch[token][_currTs])
                    / _supply;
                _currTs += DURATION;
            }
        }

        return reward;
    }

    /// @inheritdoc IReward
    function _deposit(uint256 amount, uint256 tokenId) external {
        if (msg.sender != authorized) revert NotAuthorized();

        totalSupply += amount;
        balanceOf[tokenId] += amount;

        _writeCheckpoint(tokenId, balanceOf[tokenId]);
        _writeSupplyCheckpoint();

        emit Deposit(msg.sender, tokenId, amount);
    }

    /// @inheritdoc IReward
    function _withdraw(uint256 amount, uint256 tokenId) external {
        if (msg.sender != authorized) revert NotAuthorized();

        totalSupply -= amount;
        balanceOf[tokenId] -= amount;

        _writeCheckpoint(tokenId, balanceOf[tokenId]);
        _writeSupplyCheckpoint();

        emit Withdraw(msg.sender, tokenId, amount);
    }

    /// @inheritdoc IReward
    function getReward(uint256 tokenId, address[] memory tokens)
        external
        virtual
        nonReentrant
    {}

    /**
     * @notice Internal helper for processing reward claims
     * @dev Calculates and transfers earned rewards to recipient
     * @param recipient Address to receive claimed rewards
     * @param tokenId ID of veNFT claiming rewards
     * @param tokens Array of reward tokens to claim
     */
    function _getReward(
        address recipient,
        uint256 tokenId,
        address[] memory tokens
    ) internal {
        uint256 _length = tokens.length;
        for (uint256 i = 0; i < _length; i++) {
            uint256 _reward = earned(tokens[i], tokenId);
            lastEarn[tokens[i]][tokenId] = block.timestamp;
            if (_reward > 0) ERC20(tokens[i]).safeTransfer(recipient, _reward);

            emit ClaimRewards(recipient, tokens[i], _reward);
        }
    }

    /// @inheritdoc IReward
    function notifyRewardAmount(address token, uint256 amount)
        external
        virtual
        nonReentrant
    {}

    /// @inheritdoc IReward
    function renotifyRewardAmount(uint256 timestamp, address token) external {
        uint256 epochStart = VelodromeTimeLibrary.epochStart(timestamp);
        uint256 currentEpochStart =
            VelodromeTimeLibrary.epochStart(block.timestamp);
        uint256 rewardAmount = tokenRewardsPerEpoch[token][epochStart];
        uint256 index = getPriorSupplyIndex(timestamp);

        if (rewardAmount == 0) revert ZeroAmount();
        if (currentEpochStart <= epochStart) revert ActiveEpoch();
        if (supplyCheckpoints[index].supply != 0) revert NonZeroSupply();

        tokenRewardsPerEpoch[token][epochStart] = 0;

        // Redistribute rewards to current epoch.
        tokenRewardsPerEpoch[token][currentEpochStart] += rewardAmount;

        emit NotifyReward(address(this), token, epochStart, rewardAmount);
    }

    /**
     * @notice Internal helper for adding rewards
     * @dev Transfers tokens and updates reward accounting
     * @param sender Address providing reward tokens
     * @param token Address of reward token
     * @param amount Amount of tokens to add as rewards
     */
    function _notifyRewardAmount(address sender, address token, uint256 amount)
        internal
    {
        if (amount == 0) revert ZeroAmount();
        ERC20(token).safeTransferFrom(sender, address(this), amount);

        uint256 epochStart = VelodromeTimeLibrary.epochStart(block.timestamp);
        tokenRewardsPerEpoch[token][epochStart] += amount;

        emit NotifyReward(sender, token, epochStart, amount);
    }
}
