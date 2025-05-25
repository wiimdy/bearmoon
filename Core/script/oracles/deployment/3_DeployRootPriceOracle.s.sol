// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { console2 } from "forge-std/Script.sol";
import { BaseScript } from "../../base/Base.s.sol";
import { RBAC } from "../../base/RBAC.sol";
import { RootPriceOracle } from "src/extras/RootPriceOracle.sol";
import { RootPriceOracleDeployer } from "src/extras/RootPriceOracleDeployer.sol";
import { ROOT_PRICE_ORACLE_ADDRESS } from "../OraclesAddresses.sol";
import { ROOT_PRICE_ORACLE_SALT } from "../OraclesSalts.sol";

contract DeployRootPriceOracleScript is RBAC, BaseScript {
    function run() public broadcast {
        RootPriceOracleDeployer oracleDeployer = new RootPriceOracleDeployer(msg.sender, ROOT_PRICE_ORACLE_SALT);

        RootPriceOracle rootPriceOracle = oracleDeployer.rootPriceOracle();
        console2.log("RootPriceOracle deployed at:", address(rootPriceOracle));
        _checkDeploymentAddress("RootPriceOracle", address(rootPriceOracle), ROOT_PRICE_ORACLE_ADDRESS);

        require(
            rootPriceOracle.hasRole(rootPriceOracle.DEFAULT_ADMIN_ROLE(), msg.sender),
            "RootPriceOracle admin role not set correctly"
        );

        RBAC.RoleDescription memory managerRole = RBAC.RoleDescription({
            contractName: "RootPriceOracle",
            contractAddr: ROOT_PRICE_ORACLE_ADDRESS,
            name: "MANAGER_ROLE",
            role: rootPriceOracle.MANAGER_ROLE()
        });

        RBAC.AccountDescription memory deployer = RBAC.AccountDescription({ name: "deployer", addr: msg.sender });

        _grantRole(managerRole, deployer);
    }
}
