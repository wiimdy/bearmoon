// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { BasePredictScript, console2 } from "../base/BasePredict.s.sol";
import { Create2Deployer } from "src/base/Create2Deployer.sol";
import { BerachainGovernance } from "src/gov/BerachainGovernance.sol";
import { TimeLock } from "src/gov/TimeLock.sol";
import { GOVERNANCE_SALT, TIMELOCK_SALT } from "./GovernanceSalts.sol";

contract GovernancePredictAddressesScript is BasePredictScript {
    function run() public pure {
        _predictProxyAddress("Governance", type(BerachainGovernance).creationCode, GOVERNANCE_SALT, GOVERNANCE_SALT);
        _predictProxyAddress("Timelock", type(TimeLock).creationCode, TIMELOCK_SALT, TIMELOCK_SALT);
    }
}
