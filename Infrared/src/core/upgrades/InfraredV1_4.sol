// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {InfraredV1_3} from "./InfraredV1_3.sol"; // Adjust if inheritance differs
import {IBGTIncentiveDistributor} from
    "lib/contracts/src/pol/interfaces/IBGTIncentiveDistributor.sol";
import {Errors} from "../../utils/Errors.sol";
import {IInfraredV1_4} from "src/interfaces/upgrades/IInfraredV1_4.sol";
import {UUPSUpgradeable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ValidatorManagerLib} from "../libraries/ValidatorManagerLib.sol";

/**
 * @title Infrared Protocol Core Contract V1.4
 * @notice Upgrade adds integration with BGTIncentiveDistributor for claiming booster rewards.
 * @dev Implements IInfrared_V1_4, inheriting from InfraredV1_3. Maintains UUPS upgradeability.
 *      Uses potentially updated ValidatorManagerLib to allow external validator boosting via existing functions.
 */
contract InfraredV1_4 is InfraredV1_3, IInfraredV1_4 {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       Keeper FUNCTIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Claims BGT incentive rewards via BGTIncentiveDistributor.
    /// @dev Relays call for `msg.sender`. Distributor address is set once during initialization.
    /// @param _claims Array of claim data compatible with IBGTIncentiveDistributor.
    function claimBGTIncentives(
        IBGTIncentiveDistributor.Claim[] calldata _claims
    ) external onlyKeeper {
        address distributor = rewardsFactory.bgtIncentiveDistributor();
        if (distributor == address(0)) revert Errors.ZeroAddress();
        if (_claims.length == 0) revert Errors.InvalidArrayLength();

        IBGTIncentiveDistributor(distributor).claim(_claims);

        // Emit Infrared event
        emit BGTIncentivesClaimAttempted(
            msg.sender, distributor, _claims.length
        ); // Event defined in an appropriate interface
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                 BOOST FUNCTIONS (Inherited)                */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // Functions like queueBoosts, cancelBoosts, activateBoosts, etc., are inherited.
    // Their underlying logic now uses the modified/versioned ValidatorManagerLib,
    // allowing interaction with external validators without specific checks within the lib calls.
}
