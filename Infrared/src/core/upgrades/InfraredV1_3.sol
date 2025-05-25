// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {
    ConfigTypes,
    IInfraredV1_2
} from "src/interfaces/upgrades/IInfraredV1_2.sol";
import {IInfraredV1_3} from "src/interfaces/upgrades/IInfraredV1_3.sol";
import {InfraredV1_2, Errors} from "src/core/upgrades/InfraredV1_2.sol";
/*

        Helping Bears get their Bread, since Day One

⠀⠀⠀⠀⠀⠀⠀⣀⣠⣤⣤⣤⣤⣄⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⢀⣤⣾⣿⡿⠿⠿⠛⠛⠻⠿⢿⣿⣷⣤⡀⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⣰⣿⣿⠟⠁⠀⠀⠀⠀⠀⠀⠀⠀⠈⠙⢿⣿⣮⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣴⣶⣿⣿⣿⣿⣿⣶⣦⣄⡀⠀⠀⠀⠀
⠀⣼⣿⠟⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢿⣿⣧⠀⠀⢀⣀⣀⣤⣤⣤⣤⣤⣤⣤⣤⣀⣀⠀⠀⠀⠀⠀⠀⠀⠀⣴⣿⡿⠟⠋⠁⠀⠀⠀⠈⠉⠛⢿⣿⣦⡀⠀⠀
⢸⣿⣿⣶⣶⣶⣶⣤⣄⡀⠀⠀⠀⠀⠀⠀⠀⢀⣨⣿⣿⣾⣿⣿⠿⠿⠟⠛⠛⠛⠛⠛⠻⠿⠿⠿⣿⣿⣷⣶⣤⣤⣀⣼⣿⠟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⣿⣿⡄⠀
⣼⣿⡟⠛⠉⠉⠙⠛⠿⣿⣷⡄⠀⠀⢀⣤⣶⣿⠿⠟⠋⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠙⠛⠻⠿⣿⣿⣤⡀⠀⠀⠀⠀⠀⠀⢀⣀⣤⣤⣤⣌⣿⣷⠀
⣿⣿⠁⠀⠀⠀⠀⠀⠈⠈⢻⣿⣦⣶⣿⠟⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⠻⣿⣷⣄⠀⢀⣴⣾⣿⠿⠛⠛⠛⠻⣿⣿⡄
⢹⣿⡆⠀⠀⠀⠀⠀⠀⠀⢠⣽⣿⠟⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠙⢿⣷⣿⣿⠋⠀⠀⠀⠀⠀⠀⣸⣿⠇
⠘⣿⣿⡄⠀⠀⠀⠀⣠⣴⣿⡟⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⣿⣿⡀⠀⠀⠀⠀⠀⢀⣿⣿⠀
⠀⢈⢿⣿⣦⣀⢀⢤⣾⣿⠏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⣿⣿⡄⡀⠀⠀⢠⣾⣿⠃⠀
⠀⠈⠀⠙⠻⣿⣿⣿⡿⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢿⣿⣔⣦⣾⣿⠟⠁⠀⠀
⠀⠀⠀⠀⠀⣀⣿⣿⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⣿⣿⡟⠋⠁⠀⠀⠀⠀
⠀⠀⠀⠀⠀⣼⣿⠇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⡇⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⢠⣿⡿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⢸⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢻⣿⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠰⣾⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⡆⠀⠀⠀⠀⠀
⠀⠀⠀⠀⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣴⣿⣿⣿⣿⣷⡆⠀⠀⡠⠄⠀⠀⠀⠀⠀⠐⠢⢄⡀⠀⠀⠀⠀⢀⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⡇⠀⠀⠀⠀⠀
⠀⠀⠀⠈⢹⣿⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠻⠿⠿⠿⠟⠁⡠⠋⠀⠀⠀⢠⣿⣿⣷⡄⠀⠀⠈⢦⠀⢠⣿⣿⣿⣿⣿⣶⡄⠀⠀⠀⠀⠀⠀⠀⠀⣼⣿⠃⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠸⣿⣇⠀⠀⠀⠀⠀⠀⠀⠀⠰⢒⢠⠖⡆⡤⡄⢰⠁⠀⠀⠀⠀⣸⣿⣿⣿⠃⠀⠀⠀⠀⢃⠀⠙⠻⠿⠿⠿⠿⠃⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⢿⣿⡆⠀⠀⠀⠀⠀⠀⠀⡇⡼⡜⣰⢻⢀⡇⠀⠀⣀⣤⣶⣿⣿⡿⢿⣿⣷⣄⡀⠀⠀⠘⠀⢠⠒⡆⡤⡆⣀⡀⠀⠀⠀⠀⠀⠀⠀⣸⣿⡇⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠈⢿⣿⣆⠀⠀⠀⠀⠀⠀⠈⠀⠉⠁⢘⣮⣶⣿⠿⠿⠟⣛⣋⣁⠀⠀⠙⠻⢿⣿⣶⣶⣦⣤⣇⣜⡜⢠⢳⢃⡆⠀⠀⠀⠀⠀⠀⣠⣿⡿⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠈⢻⣿⣧⡀⠀⠀⠀⠀⠀⠀⠀⠀⣼⣿⠋⠀⡤⠊⠁⠀⠀⠀⠉⠑⠢⣄⠤⠤⠤⢍⣉⠻⢿⣿⣦⠃⠳⠞⠀⠀⠀⠀⠀⠀⣰⣿⡿⠉⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠙⢿⣿⣦⣀⠀⣀⣠⣤⣄⡀⣿⡇⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠢⡹⣿⣧⠀⠀⠀⠀⠀⠀⣠⣾⣿⠟⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⠻⢿⣿⣿⠟⠛⠻⣿⣿⡿⡠⢈⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⣽⣿⣶⣶⣦⣤⣴⣿⣿⠟⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣿⡿⠁⠀⠀⠀⠈⣿⣿⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣰⣿⠟⠉⠀⠉⠻⣿⣿⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⣿⡇⠀⠀⠀⠀⠀⣾⣿⠀⡎⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⡟⠀⠀⠀⠀⠀⢻⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⣿⣷⣀⠀⠀⢀⣼⣿⠏⢠⠇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣷⠀⠀⠀⠀⠀⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢻⣿⣿⣿⣿⣿⠃⠀⠸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢰⣼⣿⣷⣤⣤⣤⣾⣿⠏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⠇⠀⣿⡿⠁⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡎⣿⡟⢹⣿⡟⠛⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
*/

/// @title Infrared Protocol Core Contract (V1.3)
/// @notice Extension of V1.2 with validator commission management functionality
/// @dev This upgrade adds support for queuing and activating validator commission changes
contract InfraredV1_3 is InfraredV1_2, IInfraredV1_3 {
    /// @notice Queues a commission rate change for a validator on incentive tokens.
    /// @dev Only the governor can call this function.
    /// @dev Reverts if a commission rate change is already queued.
    /// @param _pubkey The validator's pubkey.
    /// @param _commissionRate The commission rate of the validator on the incentive tokens.
    function queueValCommission(bytes calldata _pubkey, uint96 _commissionRate)
        external
        onlyGovernor
    {
        _queueValCommission(_pubkey, _commissionRate);
    }

    function _queueValCommission(bytes calldata _pubkey, uint96 _commissionRate)
        internal
    {
        if (!isInfraredValidator(_pubkey)) revert Errors.InvalidValidator();
        chef.queueValCommission(_pubkey, _commissionRate);
        emit ValidatorCommissionQueued(msg.sender, _pubkey, _commissionRate);
    }

    /// @notice Queues commission rate changes for multiple validators on incentive tokens.
    /// @dev Only the governor can call this function.
    /// @dev Reverts if any validator is invalid or if any have a commission rate change already queued.
    /// @param _pubkeys The array of validator pubkeys.
    /// @param _commissionRate The commission rate to set for all validators in the array.
    function queueMultipleValCommissions(
        bytes[] calldata _pubkeys,
        uint96 _commissionRate
    ) external onlyGovernor {
        uint256 length = _pubkeys.length;
        for (uint256 i = 0; i < length; i++) {
            _queueValCommission(_pubkeys[i], _commissionRate);
        }
    }

    /// @notice Activates the queued commission rate of a validator on incentive tokens.
    /// @dev Anyone can call this function once the queued commission is ready.
    /// @param _pubkey The validator's pubkey.
    function activateQueuedValCommission(bytes calldata _pubkey) external {
        if (!isInfraredValidator(_pubkey)) revert Errors.InvalidValidator();
        chef.activateQueuedValCommission(_pubkey);

        // Get the current commission rate to include in the event
        uint96 newCommissionRate =
            chef.getValCommissionOnIncentiveTokens(_pubkey);
        emit ValidatorCommissionActivated(
            msg.sender, _pubkey, newCommissionRate
        );
    }
}
