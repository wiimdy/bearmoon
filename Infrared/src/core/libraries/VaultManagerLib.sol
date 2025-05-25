// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {EnumerableSet} from
    "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {IInfraredVault} from "src/interfaces/IInfraredVault.sol";
import {Errors} from "src/utils/Errors.sol";
import {InfraredVaultDeployer} from "src/utils/InfraredVaultDeployer.sol";

/// @title VaultManagerLib
/// @notice Library for managing:
/// - Vault registration
/// - Vault pausing
/// - Reward token whitelisting
/// - Default reward duration
library VaultManagerLib {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeTransferLib for ERC20;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       STORAGE TYPE                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Storage structure for the VaultManagerLib
    /// @param pausedVaultRegistration Flag to pause or unpause vault registration
    /// @param whitelistedRewardTokens Set of whitelisted reward tokens that can be called into.
    /// @param rewardsDuration Default duration for rewards
    struct VaultStorage {
        bool pausedVaultRegistration;
        mapping(address => IInfraredVault) vaultRegistry; // Maps asset to its vault
        EnumerableSet.AddressSet whitelistedRewardTokens; // Set of whitelisted reward tokens
        uint256 rewardsDuration; // Default duration for rewards
        mapping(address => uint8) vaultVersions;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       MODIFIERS                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Modifier to check if vault registration is paused.
    /// @param $ Storage pointer to the VaultStorage struct.
    modifier vaultRegistrationNotPaused(VaultStorage storage $) {
        if ($.pausedVaultRegistration) {
            revert Errors.RegistrationPaused();
        }
        _;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       ADMIN                                */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Pauses staking functionality on a specific vault
    /// @param $ Storage pointer to the VaultStorage struct.
    /// @param asset address of the asset to pause the vault for.
    function pauseStaking(VaultStorage storage $, address asset) external {
        IInfraredVault vault = $.vaultRegistry[asset];
        if (address(vault) == address(0)) revert Errors.NoRewardsVault();

        vault.pauseStaking();
    }

    /// @notice Un-pauses staking functionality on a specific vault
    /// @param $ Storage pointer to the VaultStorage struct.
    /// @param asset address of the asset to un-pause the vault for.
    function unpauseStaking(VaultStorage storage $, address asset) external {
        IInfraredVault vault = $.vaultRegistry[asset];
        if (address(vault) == address(0)) revert Errors.NoRewardsVault();

        vault.unpauseStaking();
    }

    /// @notice Pauses staking functionality on an old vault
    /// @param _vault address of the vault to pause
    function pauseOldStaking(address _vault) external {
        IInfraredVault(_vault).pauseStaking();
    }

    /// @notice Un-pauses staking functionality on an old vault
    /// @param _vault address of the vault to un-pause
    function unpauseOldStaking(address _vault) external {
        IInfraredVault(_vault).unpauseStaking();
    }

    /// @notice Updates the whitelist status of a reward token.
    /// @param $ Storage pointer to the VaultStorage struct.
    /// @param token address of the reward token to update the whitelist status for.
    /// @param whitelisted New whitelist status for the reward token.
    function updateWhitelistedRewardTokens(
        VaultStorage storage $,
        address token,
        bool whitelisted
    ) external {
        if (address(token) == address(0)) revert Errors.NoRewardsVault();
        if (whitelisted) {
            $.whitelistedRewardTokens.add(token);
        } else {
            $.whitelistedRewardTokens.remove(token);
        }
    }

    /// @notice Adds a reward to a vault, if the reward token is whitelisted.
    /// @param $ Storage pointer to the VaultStorage struct.
    /// @param _stakingToken address of the asset to add the reward to.
    /// @param _rewardsToken address of the reward token to add.
    function addReward(
        VaultStorage storage $,
        address _stakingToken,
        address _rewardsToken,
        uint256 _rewardsDuration
    ) external {
        if (!isWhitelisted($, _rewardsToken)) {
            revert Errors.RewardTokenNotWhitelisted();
        }
        if (address($.vaultRegistry[_stakingToken]) == address(0)) {
            revert Errors.NoRewardsVault();
        }

        IInfraredVault vault = $.vaultRegistry[_stakingToken];
        vault.addReward(_rewardsToken, _rewardsDuration);
    }

    function removeReward(
        VaultStorage storage $,
        address _stakingToken,
        address _rewardsToken
    ) external {
        IInfraredVault vault = $.vaultRegistry[_stakingToken];
        if (address(vault) == address(0)) {
            revert Errors.NoRewardsVault();
        }

        vault.removeReward(_rewardsToken);
    }

    /// @notice Updates the global rewards duration for new vaults.
    /// @param $ Storage pointer to the VaultStorage struct.
    /// @param newDuration New rewards duration.
    /// @dev The rewards duration is used as the default duration for new vaults.
    ///     Existing vaults will not be affected by this change.
    function updateRewardsDuration(VaultStorage storage $, uint256 newDuration)
        external
    {
        if (newDuration == 0) revert Errors.ZeroAmount();
        $.rewardsDuration = newDuration;
    }

    /// @notice Recovers ERC20 tokens from a vault.
    /// @param $ Storage pointer to the VaultStorage struct.
    /// @param _asset address of the asset to recover from.
    /// @param _to address to recover the tokens to.
    /// @param _token address of the token to recover.
    /// @param _amount uint256 amount of tokens to recover.
    function recoverERC20FromVault(
        VaultStorage storage $,
        address _asset,
        address _to,
        address _token,
        uint256 _amount
    ) external {
        if (address($.vaultRegistry[_asset]) == address(0)) {
            revert Errors.NoRewardsVault();
        }

        IInfraredVault vault = $.vaultRegistry[_asset];
        vault.recoverERC20(_to, _token, _amount);
    }

    /// @notice Recovers ERC20 tokens from old vault.
    /// @dev removes reward token, cutting user claims. This should be a one time last ditch call for recovery after all users exited
    /// @param _vault address of the asset to recover from.
    /// @param _to address to recover the tokens to.
    /// @param _token address of the token to recover.
    /// @param _amount uint256 amount of tokens to recover.
    function recoverERC20FromOldVault(
        address _vault,
        address _to,
        address _token,
        uint256 _amount
    ) external {
        if (_vault == address(0) || _to == address(0) || _token == address(0)) {
            revert Errors.ZeroAddress();
        }
        (bool success,) = _vault.call(
            abi.encodeWithSignature("removeReward(address)", _token)
        );

        (success,) = _vault.call(
            abi.encodeWithSignature(
                "recoverERC20(address,address,uint256)", _to, _token, _amount
            )
        );
        if (!success) revert();
    }

    /// @notice Updates the rewards duration for a specific reward token on a vault.
    /// @param $ Storage pointer to the VaultStorage struct.
    /// @param _stakingToken address of the asset to update the rewards duration for.
    /// @param _rewardsToken address of the reward token to update the rewards duration for.
    /// @param _rewardsDuration New rewards duration.
    function updateRewardsDurationForVault(
        VaultStorage storage $,
        address _stakingToken,
        address _rewardsToken,
        uint256 _rewardsDuration
    ) external {
        if ($.vaultRegistry[_stakingToken] == IInfraredVault(address(0))) {
            revert Errors.NoRewardsVault();
        }
        IInfraredVault vault = $.vaultRegistry[_stakingToken];
        (, uint256 rewardsDuration,,,,,) = vault.rewardData(_rewardsToken);
        if (rewardsDuration == 0) {
            revert Errors.RewardTokenNotWhitelisted();
        }
        vault.updateRewardsDuration(_rewardsToken, _rewardsDuration);
    }

    /// @notice Pauses or unpauses the registration of new vaults.
    /// @param $ Storage pointer to the VaultStorage struct.
    /// @param pause Flag to pause or unpause vault registration.
    function setVaultRegistrationPauseStatus(VaultStorage storage $, bool pause)
        external
    {
        $.pausedVaultRegistration = pause;
    }

    /// @notice Claims lost rewards from a vault.
    /// @param $ Storage pointer to the VaultStorage struct.
    /// @param _asset address of the asset to claim lost rewards from.
    function claimLostRewardsOnVault(VaultStorage storage $, address _asset)
        external
    {
        IInfraredVault vault = $.vaultRegistry[_asset];
        if (address(vault) == address(0)) {
            revert Errors.NoRewardsVault();
        }
        // unclaimed rewards will end up split between IBERA shareholders
        vault.getReward();
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       EXTERNAL                             */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Adds a reward to a vault, if the reward token is whitelisted.
    /// @param $ Storage pointer to the VaultStorage struct.
    /// @param _stakingToken address The asset to add the reward to.
    /// @param _rewardsToken address The the reward token to add.
    /// @param _amount       uint256 amount of the reward token to add.
    function addIncentives(
        VaultStorage storage $,
        address _stakingToken,
        address _rewardsToken,
        uint256 _amount
    ) external {
        if (address($.vaultRegistry[_stakingToken]) == address(0)) {
            revert Errors.NoRewardsVault();
        }

        IInfraredVault vault = $.vaultRegistry[_stakingToken];

        (
            ,
            uint256 _vaultRewardsDuration,
            uint256 periodFinish,
            uint256 rewardRate,
            ,
            ,
            uint256 rewardResidual
        ) = vault.rewardData(_rewardsToken);
        if (_vaultRewardsDuration == 0) {
            revert Errors.RewardTokenNotWhitelisted();
        }

        if (block.timestamp < periodFinish) {
            // enforce externally added incentives cannot reduce current rate
            // calc new reward residual
            uint256 reward = _amount + rewardResidual;
            rewardResidual = reward % _vaultRewardsDuration;
            reward = reward - rewardResidual;
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            // Calculate total and its residual
            uint256 totalAmount = reward + leftover + rewardResidual;
            rewardResidual = totalAmount % _vaultRewardsDuration;
            // Remove residual before setting rate
            totalAmount = totalAmount - rewardResidual;
            uint256 newRewardRate = totalAmount / _vaultRewardsDuration;
            if (newRewardRate < rewardRate) {
                revert Errors.RewardRateDecreased();
            }
        }

        ERC20(_rewardsToken).safeTransferFrom(
            msg.sender, address(this), _amount
        );
        ERC20(_rewardsToken).safeApprove(address(vault), _amount);

        vault.notifyRewardAmount(_rewardsToken, _amount);
    }

    /// @notice Registers a new vault for a specific asset.
    /// @param $ Storage pointer to the VaultStorage struct.
    /// @param asset address of the asset to register a vault for.
    /// @return address of the newly created vault.
    function registerVault(VaultStorage storage $, address asset)
        external
        vaultRegistrationNotPaused($)
        returns (address)
    {
        if (asset == address(0)) revert Errors.ZeroAddress();

        // Check for duplicate staking asset address
        if (address($.vaultRegistry[asset]) != address(0)) {
            revert Errors.DuplicateAssetAddress();
        }

        address newVault =
            InfraredVaultDeployer.deploy(asset, $.rewardsDuration);
        $.vaultRegistry[asset] = IInfraredVault(newVault);
        return newVault;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       READ                                 */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Checks if a token is whitelisted as a reward token.
    /// @param $ Storage pointer to the VaultStorage struct.
    /// @param token address of the token to check.
    /// @return bool indicating if the token is whitelisted.
    function isWhitelisted(VaultStorage storage $, address token)
        public
        view
        returns (bool)
    {
        return $.whitelistedRewardTokens.contains(token);
    }
}
