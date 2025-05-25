// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {IInfraredV1_2} from "src/interfaces/upgrades/IInfraredV1_2.sol";

/// @title IInfraredV1_3
/// @notice Interface for V1.3 of the Infrared protocol
/// @dev Extends V1.2 with validator commission management functionality
interface IInfraredV1_3 is IInfraredV1_2 {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       EVENTS                               */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Emitted when a validator's commission rate is queued
    /// @param operator The address that queued the commission change
    /// @param pubkey The validator's pubkey
    /// @param commissionRate The queued commission rate
    event ValidatorCommissionQueued(
        address indexed operator, bytes pubkey, uint96 commissionRate
    );

    /// @notice Emitted when a validator's queued commission rate is activated
    /// @param operator The address that activated the commission change
    /// @param pubkey The validator's pubkey
    /// @param commissionRate The new active commission rate
    event ValidatorCommissionActivated(
        address indexed operator, bytes pubkey, uint96 commissionRate
    );

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       VALIDATORS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Queues a commission rate change for a validator on incentive tokens
    /// @param _pubkey The validator's pubkey
    /// @param _commissionRate The commission rate to set
    function queueValCommission(bytes calldata _pubkey, uint96 _commissionRate)
        external;

    /// @notice Queues commission rate changes for multiple validators on incentive tokens
    /// @param _pubkeys The array of validator pubkeys
    /// @param _commissionRate The commission rate to set for all validators
    function queueMultipleValCommissions(
        bytes[] calldata _pubkeys,
        uint96 _commissionRate
    ) external;

    /// @notice Activates the queued commission rate of a validator on incentive tokens
    /// @param _pubkey The validator's pubkey
    function activateQueuedValCommission(bytes calldata _pubkey) external;
}
