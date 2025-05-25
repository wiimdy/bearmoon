// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./POLGasSim.t.sol";

contract POLGasSimulationMax is POLGasSimulationSimple {
    function setUp() public override {
        super.setUp();

        // Create reward vaults with consensus assets
        RewardVault[] memory vaults = createVaults(7);

        // configure reward allocation with multiple consensus assets
        uint96[] memory weights = new uint96[](7);
        weights[0] = 1000;
        weights[1] = 1000;
        weights[2] = 1000;
        weights[3] = 1000;
        weights[4] = 1000;
        weights[5] = 2000;
        weights[6] = 3000;

        configureWeights(vaults, weights);

        // whitelist and add validator incentives
        addIncentives(vaults, 2);
    }

    /// @dev Test reward distribution for multiple blocks
    /// @notice 11.75% of Arbitrum block gas limit
    function testGasPOLDistributionCatchUp() public {
        for (uint256 i; i < 10; ++i) {
            validateAndDistribute(proof, signature, abi.encode(valData.pubkey, block.number - 1));
        }
    }
}
