// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { BaseScript } from "../../base/Base.s.sol";
import { WBERADeployer } from "../logic/WBERADeployer.sol";
import { WBERA_ADDRESS } from "../POLAddresses.sol";
import { WBERA_SALT } from "../POLSalts.sol";

/// @dev Deprecated. WBERA is deployed during genesis.
contract DeployWBERAScript is BaseScript, WBERADeployer {
    function run() public broadcast {
        address wbera = deployWBERA(WBERA_SALT);
        _checkDeploymentAddress("WBERA", wbera, WBERA_ADDRESS);
    }
}
