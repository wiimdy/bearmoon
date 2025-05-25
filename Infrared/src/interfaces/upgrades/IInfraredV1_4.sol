// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {IInfraredV1_3} from "./IInfraredV1_3.sol";
import {IBGTIncentiveDistributor} from
    "lib/contracts/src/pol/interfaces/IBGTIncentiveDistributor.sol";

/**
 * @title IInfraredV1_4 Interface
 * @notice Interface for Infrared V1.4 upgrade. Adds BGT incentive claims.
 * @dev Defines external functions and events for V1.4. Inherits from IInfraredV1_3.
 */
interface IInfraredV1_4 is IInfraredV1_3 {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         EVENTS                             */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Emitted when claimBGTIncentives is called.
    /// @param caller Address initiating the claim.
    /// @param distributor BGTIncentiveDistributor contract called.
    /// @param numClaims Number of claims submitted.
    event BGTIncentivesClaimAttempted(
        address indexed caller, address indexed distributor, uint256 numClaims
    );

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       FUNCTIONS                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Claims BGT incentive rewards via the BGTIncentiveDistributor.
    /// @param _claims Array of claim data.
    function claimBGTIncentives(
        IBGTIncentiveDistributor.Claim[] calldata _claims
    ) external;

    // --- Inherited elements from IInfraredV1_3 ---
}
