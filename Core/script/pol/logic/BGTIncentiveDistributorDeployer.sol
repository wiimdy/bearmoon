// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { BGTIncentiveDistributor } from "src/pol/rewards/BGTIncentiveDistributor.sol";
import { Create2Deployer } from "src/base/Create2Deployer.sol";

abstract contract BGTIncentiveDistributorDeployer is Create2Deployer {
    /// @notice Deploy BGTIncentiveDistributor contract
    function deployBGTIncentiveDistributor(
        address owner,
        uint256 bgtIncentiveDistributorSalt
    )
        internal
        returns (address)
    {
        address bgtIncentiveDistributorImpl = deployWithCreate2(0, type(BGTIncentiveDistributor).creationCode);
        BGTIncentiveDistributor bgtIncentiveDistributor =
            BGTIncentiveDistributor(deployProxyWithCreate2(bgtIncentiveDistributorImpl, bgtIncentiveDistributorSalt));
        bgtIncentiveDistributor.initialize(owner);
        return address(bgtIncentiveDistributor);
    }
}
