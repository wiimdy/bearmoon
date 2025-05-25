// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {IInfraredV1_4} from "./IInfraredV1_4.sol";

/**
 * @title IInfraredV1_5 Interface
 * @notice Interface for Infrared V1.5 upgrade. Adds external berachain user BGT reward claiming, minting iBGT to user.
 * @dev Defines external functions and events for V1.5. Inherits from IInfraredV1_4.
 */
interface IInfraredV1_5 is IInfraredV1_4 {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         EVENTS                             */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Emitted when claimExternalVaultRewards is called.
    /// @param user Address to claim on behalf of.
    /// @param stakingAsset staking asset of berachain reward vault to claim for.
    /// @param berachainRewardVault vault address
    /// @param bgtAmt Amount of BGT claimed.
    event ExternalVaultClaimed(
        address indexed user,
        address indexed stakingAsset,
        address indexed berachainRewardVault,
        uint256 bgtAmt
    );

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       FUNCTIONS                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Claims all the BGT rewards for the user associated with the berachain vault given staking token.
    /// @param _asset address The address of the staking asset that the vault is for.
    /// @param user address The address of the user to get rewards for and mint ibgt to
    function claimExternalVaultRewards(address _asset, address user) external;

    /// @notice View expected iBGT rewards to claim for the user associated with the berachain vault given staking token.
    /// @param _asset address The address of the staking asset that the vault is for.
    /// @param user address The address of the user to get rewards for and mint ibgt to
    /// @return iBgtAmount amount of iBGT to be minted to user
    function externalVaultRewards(address _asset, address user)
        external
        view
        returns (uint256 iBgtAmount);

    // --- Inherited elements from IInfraredV1_4 ---
}
