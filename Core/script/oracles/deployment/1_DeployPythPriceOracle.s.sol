// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { BaseScript } from "../../base/Base.s.sol";
import { RBAC } from "../../base/RBAC.sol";
import { PythPriceOracleDeployer } from "src/extras/PythPriceOracleDeployer.sol";
import { PythPriceOracle } from "src/extras/PythPriceOracle.sol";
import { PYTH_PRICE_ORACLE_ADDRESS } from "../OraclesAddresses.sol";
import { PYTH_PRICE_ORACLE_SALT } from "../OraclesSalts.sol";

contract DeployPythPriceOracleScript is RBAC, BaseScript {
    function run() public broadcast {
        PythPriceOracleDeployer oracleDeployer = new PythPriceOracleDeployer(msg.sender, PYTH_PRICE_ORACLE_SALT);

        PythPriceOracle pythPriceOracle = PythPriceOracle(oracleDeployer.oracle());
        _checkDeploymentAddress("PythPriceOracle", address(pythPriceOracle), PYTH_PRICE_ORACLE_ADDRESS);

        RBAC.RoleDescription memory adminRole = RBAC.RoleDescription({
            contractName: "PythPriceOracle",
            contractAddr: PYTH_PRICE_ORACLE_ADDRESS,
            name: "DEFAULT_ADMIN_ROLE",
            role: pythPriceOracle.DEFAULT_ADMIN_ROLE()
        });

        RBAC.AccountDescription memory deployer = RBAC.AccountDescription({ name: "deployer", addr: msg.sender });

        _requireRole(adminRole, deployer);
    }
}
