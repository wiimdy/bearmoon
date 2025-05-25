// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {InfraredVault} from "src/core/InfraredVault.sol";

library InfraredVaultDeployer {
    /**
     * @notice Deploys a new `InfraredVault` or `InfraredBGTVault` contract.
     * @dev If _stakingToken == InfraredBGT, then deploys `InfraredBGTVault`.
     * @param _stakingToken address The address of the staking token.
     * @param _rewardsDuration The duration of the rewards for the vault.
     * @return _new address The address of the new `InfraredVault` contract.
     */
    function deploy(address _stakingToken, uint256 _rewardsDuration)
        public
        returns (address _new)
    {
        return address(new InfraredVault(_stakingToken, _rewardsDuration));
    }
}
