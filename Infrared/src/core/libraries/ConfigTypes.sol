// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library ConfigTypes {
    /// @notice Fee type enum for determining rates to charge on reward distribution.
    enum FeeType {
        HarvestOperatorFeeRate,
        HarvestOperatorProtocolRate,
        HarvestVaultFeeRate,
        HarvestVaultProtocolRate,
        HarvestBribesFeeRate,
        HarvestBribesProtocolRate,
        HarvestBoostFeeRate,
        HarvestBoostProtocolRate
    }
}
