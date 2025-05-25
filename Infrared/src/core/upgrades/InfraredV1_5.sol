// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {InfraredV1_4} from "./InfraredV1_4.sol";
import {IRewardVault as IBerachainRewardsVault} from
    "lib/contracts/src/pol/interfaces/IRewardVault.sol";
import {IInfraredV1_5} from "src/interfaces/upgrades/IInfraredV1_5.sol";
import {Errors} from "src/utils/Errors.sol";
import {RewardsLib} from "../libraries/RewardsLib.sol";

/**
 * @title Infrared Protocol Core Contract V1.5
 * @notice Upgrade adds claiming BGT on behalf of external user using berachain reward vaults directly, minting iBGT to user.
 * @dev Implements IInfrared_V1_5, inheriting from InfraredV1_4. Maintains UUPS upgradeability.
 *      Uses updated RewardLib to allow external validator boosting via existing functions.
 */
contract InfraredV1_5 is InfraredV1_4, IInfraredV1_5 {
    /// @notice Claims all the BGT rewards for the user associated with the berachain vault given staking token.
    /// @param _asset address The address of the staking asset that the vault is for.
    /// @param user address The address of the user to get rewards for and mint ibgt to
    function claimExternalVaultRewards(address _asset, address user)
        external
        whenNotPaused
    {
        // permissioned access: sender can be user or keeper
        address sender = msg.sender;
        if (!hasRole(KEEPER_ROLE, sender) && sender != user) {
            revert Errors.Unauthorized(sender);
        }
        IBerachainRewardsVault vault =
            IBerachainRewardsVault(rewardsFactory.getVault(_asset));
        uint256 bgtAmt = RewardsLib.harvestVaultForUser(
            _rewardsStorage(),
            vault,
            address(_bgt),
            address(ibgt),
            address(voter),
            address(user)
        );
        emit ExternalVaultClaimed(user, _asset, address(vault), bgtAmt);
    }

    /// @notice View expected iBGT rewards to claim for the user associated with the berachain vault given staking token.
    /// @param _asset address The address of the staking asset that the vault is for.
    /// @param user address The address of the user to get rewards for and mint ibgt to
    /// @return iBgtAmount amount of iBGT to be minted to user
    function externalVaultRewards(address _asset, address user)
        external
        view
        returns (uint256 iBgtAmount)
    {
        IBerachainRewardsVault vault =
            IBerachainRewardsVault(rewardsFactory.getVault(_asset));
        iBgtAmount = RewardsLib.externalVaultRewards(
            _rewardsStorage(), vault, address(user)
        );
    }
}
