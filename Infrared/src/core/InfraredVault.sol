// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IRewardVault as IBerachainRewardsVault} from
    "@berachain/pol/interfaces/IRewardVault.sol";
import {IRewardVaultFactory as IBerachainRewardsVaultFactory} from
    "@berachain/pol/interfaces/IRewardVaultFactory.sol";

import {Errors} from "src/utils/Errors.sol";
import {MultiRewards} from "src/core/MultiRewards.sol";

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";

import {IInfrared} from "src/interfaces/IInfrared.sol";
import {IInfraredVault} from "src/interfaces/IInfraredVault.sol";

/**
 * @title InfraredVault
 * @notice This contract is the vault for staking tokens, and receiving rewards from the Proof of Liquidity protocol.
 * @dev This contract uses the MultiRewards contract to distribute rewards to vault stakers, this is taken from curve.fi. (inspired by Synthetix).
 * @dev Does not support staking tokens with non-standard ERC20 transfer tax behavior.
 */
contract InfraredVault is MultiRewards, IInfraredVault {
    using SafeTransferLib for ERC20;

    /// @notice Maximum number of reward tokens that can be supported
    /// @dev Limited to prevent gas issues with reward calculations
    uint256 public constant MAX_NUM_REWARD_TOKENS = 10;

    /// @notice The infrared contract address acts a vault factory and coordinator
    address public immutable infrared;

    // The address of the berachain rewards vault
    IBerachainRewardsVault public immutable rewardsVault;

    /// Modifier to check that the caller is infrared contract
    modifier onlyInfrared() {
        if (msg.sender != infrared) revert Errors.Unauthorized(msg.sender);
        _;
    }

    constructor(address _stakingToken, uint256 _rewardsDuration)
        MultiRewards(_stakingToken)
    {
        // infrared factory/coordinator
        infrared = msg.sender;

        if (_stakingToken == address(0)) revert Errors.ZeroAddress();
        if (_rewardsDuration == 0) revert Errors.ZeroAmount();

        // set the berachain rewards vault and operator as infrared
        rewardsVault = _createRewardsVaultIfNecessary(infrared, _stakingToken);
        rewardsVault.setOperator(infrared);

        address _ibgt = address(IInfrared(infrared).ibgt());

        _addReward(_ibgt, infrared, _rewardsDuration);

        // to be able to recover rewards which where distributed during periods where there was no stake
        // infrared will have a stake of 1 wei in the vault
        _totalSupply = _totalSupply + 1;
        _balances[msg.sender] = _balances[msg.sender] + 1;
    }

    /**
     * @notice Gets or creates the berachain rewards vault for given staking token
     * @param _infrared The address of Infrared
     * @param _stakingToken The address of the staking token for this vault
     * @return The address of the berachain rewards vault
     */
    function _createRewardsVaultIfNecessary(
        address _infrared,
        address _stakingToken
    ) private returns (IBerachainRewardsVault) {
        IBerachainRewardsVaultFactory rewardsFactory =
            IInfrared(_infrared).rewardsFactory();
        address rewardsVaultAddress = rewardsFactory.getVault(_stakingToken);
        if (rewardsVaultAddress == address(0)) {
            rewardsVaultAddress =
                rewardsFactory.createRewardVault(_stakingToken);
        }
        return IBerachainRewardsVault(rewardsVaultAddress);
    }

    /*//////////////////////////////////////////////////////////////
                            STAKE/WITHDRAW/CLAIM
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Transfers to berachain low level module on staking of LP tokens with the vault after transferring tokens in
     * @param amount The amount of staking token transferred in to the contract
     */
    function onStake(uint256 amount) internal override {
        stakingToken.safeApprove(address(rewardsVault), amount);
        rewardsVault.stake(amount);
    }

    /**
     * @notice Redeems from berachain low level module on withdraw of LP tokens from the vault before transferring tokens out
     * @param amount The amount of staking token transferred out of the contract
     */
    function onWithdraw(uint256 amount) internal override {
        rewardsVault.withdraw(amount);
    }

    /**
     * @notice hook called after the reward is claimed to harvest the rewards from the berachain rewards vault
     */
    function onReward() internal override {
        IInfrared(infrared).harvestVault(address(stakingToken));
    }

    /*//////////////////////////////////////////////////////////////
                            INFRARED ONLY
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IInfraredVault
    function updateRewardsDuration(
        address _rewardsToken,
        uint256 _rewardsDuration
    ) external onlyInfrared {
        if (_rewardsToken == address(0)) revert Errors.ZeroAddress();
        if (_rewardsDuration == 0) revert Errors.ZeroAmount();
        _setRewardsDuration(_rewardsToken, _rewardsDuration);
    }

    /// @inheritdoc IInfraredVault
    function unpauseStaking() external onlyInfrared {
        if (!paused()) return;
        _unpause();
    }

    /// @inheritdoc IInfraredVault
    function pauseStaking() external onlyInfrared {
        if (paused()) return;
        _pause();
    }

    /// @inheritdoc IInfraredVault
    function addReward(address _rewardsToken, uint256 _rewardsDuration)
        external
        onlyInfrared
    {
        if (_rewardsToken == address(0)) revert Errors.ZeroAddress();
        if (_rewardsDuration == 0) revert Errors.ZeroAmount();
        if (
            rewardTokens.length == MAX_NUM_REWARD_TOKENS
                && _rewardsToken != address(IInfrared(infrared).ir())
        ) {
            revert Errors.MaxNumberOfRewards();
        }
        _addReward(_rewardsToken, infrared, _rewardsDuration);
    }

    /// @inheritdoc IInfraredVault
    function removeReward(address _rewardsToken) external onlyInfrared {
        if (_rewardsToken == address(0)) revert Errors.ZeroAddress();
        _removeReward(_rewardsToken);
    }

    /// @inheritdoc IInfraredVault
    function notifyRewardAmount(address _rewardToken, uint256 _reward)
        external
        onlyInfrared
    {
        if (_rewardToken == address(0)) revert Errors.ZeroAddress();
        if (_reward == 0) revert Errors.ZeroAmount();
        _notifyRewardAmount(_rewardToken, _reward);
    }

    /// @inheritdoc IInfraredVault
    function recoverERC20(address _to, address _token, uint256 _amount)
        external
        onlyInfrared
    {
        if (_to == address(0) || _token == address(0)) {
            revert Errors.ZeroAddress();
        }
        if (_amount == 0) revert Errors.ZeroAmount();
        _recoverERC20(_to, _token, _amount);
    }

    /*//////////////////////////////////////////////////////////////
                            Getters
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IInfraredVault
    function getAllRewardTokens() external view returns (address[] memory) {
        return rewardTokens;
    }

    /// @inheritdoc IInfraredVault
    function getAllRewardsForUser(address _user)
        external
        view
        returns (UserReward[] memory)
    {
        uint256 len = rewardTokens.length;
        UserReward[] memory tempRewards = new UserReward[](len);
        uint256 count = 0;

        for (uint256 i = 0; i < len; i++) {
            uint256 amount = earned(_user, rewardTokens[i]);
            if (amount > 0) {
                tempRewards[count] =
                    UserReward({token: rewardTokens[i], amount: amount});
                count++;
            }
        }

        // Create a new array with the exact size of non-zero rewards
        UserReward[] memory userRewards = new UserReward[](count);
        for (uint256 j = 0; j < count; j++) {
            userRewards[j] = tempRewards[j];
        }

        return userRewards;
    }
}
