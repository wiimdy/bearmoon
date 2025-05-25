// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

library ValidatorTypes {
    /// @notice Validator information for validator set
    struct Validator {
        /// pubkey of the validator for beacon deposit contract
        bytes pubkey;
        /// address of the validator for claiming infrared rewards
        address addr;
    }
}
