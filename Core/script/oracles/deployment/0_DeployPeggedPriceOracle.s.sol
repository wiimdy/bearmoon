// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { BaseScript } from "../../base/Base.s.sol";
import { PeggedPriceOracle } from "src/extras/PeggedPriceOracle.sol";
import { Create2Deployer } from "src/base/Create2Deployer.sol";
import { PEGGED_PRICE_ORACLE_ADDRESS } from "../OraclesAddresses.sol";
import { PEGGED_PRICE_ORACLE_SALT } from "../OraclesSalts.sol";

contract DeployPeggedPriceOracleScript is Create2Deployer, BaseScript {
    function run() public broadcast {
        address oracle = deployWithCreate2(PEGGED_PRICE_ORACLE_SALT, type(PeggedPriceOracle).creationCode);
        _checkDeploymentAddress("PeggedPriceOracle", oracle, PEGGED_PRICE_ORACLE_ADDRESS);
    }
}
