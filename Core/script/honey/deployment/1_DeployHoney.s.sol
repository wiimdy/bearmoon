// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { console2 } from "forge-std/Script.sol";
import { HoneyDeployer } from "src/honey/HoneyDeployer.sol";
import { BaseScript } from "../../base/Base.s.sol";
import { RBAC } from "../../base/RBAC.sol";
import { HONEY_ADDRESS, HONEY_FACTORY_ADDRESS, HONEY_FACTORY_READER_ADDRESS } from "../HoneyAddresses.sol";
import { PEGGED_PRICE_ORACLE_ADDRESS } from "../../oracles/OraclesAddresses.sol";
import { FEE_COLLECTOR_ADDRESS as POL_FEE_COLLECTOR_ADDRESS } from "../../pol/POLAddresses.sol";
import { HONEY_SALT, HONEY_FACTORY_SALT, HONEY_FACTORY_READER_SALT } from "../HoneySalts.sol";
import { Storage } from "../../base/Storage.sol";

contract DeployHoneyScript is RBAC, BaseScript, Storage {
    // Placeholder. Change before deployment
    address internal constant FEE_RECEIVER = POL_FEE_COLLECTOR_ADDRESS;

    HoneyDeployer internal honeyDeployer;

    function run() public virtual broadcast {
        deployHoney();
    }

    function deployHoney() internal {
        console2.log("Deploying Honey and HoneyFactory...");
        _validateCode("POL FeeCollector", POL_FEE_COLLECTOR_ADDRESS);
        _validateCode("IPriceOracle", PEGGED_PRICE_ORACLE_ADDRESS);

        honeyDeployer = new HoneyDeployer(
            msg.sender,
            POL_FEE_COLLECTOR_ADDRESS,
            FEE_RECEIVER,
            HONEY_SALT,
            HONEY_FACTORY_SALT,
            HONEY_FACTORY_READER_SALT,
            PEGGED_PRICE_ORACLE_ADDRESS
        );

        console2.log("HoneyDeployer deployed at:", address(honeyDeployer));

        honey = honeyDeployer.honey();
        _checkDeploymentAddress("Honey", address(honey), HONEY_ADDRESS);

        honeyFactory = honeyDeployer.honeyFactory();
        _checkDeploymentAddress("HoneyFactory", address(honeyFactory), HONEY_FACTORY_ADDRESS);

        honeyFactoryReader = honeyDeployer.honeyFactoryReader();
        _checkDeploymentAddress("HoneyFactoryReader", address(honeyFactoryReader), HONEY_FACTORY_READER_ADDRESS);

        require(honeyFactory.feeReceiver() == FEE_RECEIVER, "Fee receiver not set");
        console2.log("Fee receiver set to:", FEE_RECEIVER);

        require(honeyFactory.polFeeCollector() == POL_FEE_COLLECTOR_ADDRESS, "Pol fee collector not set");
        console2.log("Pol fee collector set to:", POL_FEE_COLLECTOR_ADDRESS);

        // check roles
        RBAC.AccountDescription memory deployer = RBAC.AccountDescription({ name: "deployer", addr: msg.sender });

        RBAC.RoleDescription memory honeyAdminRole = RBAC.RoleDescription({
            contractName: "Honey",
            contractAddr: HONEY_ADDRESS,
            name: "DEFAULT_ADMIN_ROLE",
            role: honey.DEFAULT_ADMIN_ROLE()
        });
        _requireRole(honeyAdminRole, deployer);
        console2.log("Honey's DEFAULT_ADMIN_ROLE granted to:", msg.sender);

        RBAC.RoleDescription memory honeyFactoryAdminRole = RBAC.RoleDescription({
            contractName: "HoneyFactory",
            contractAddr: HONEY_FACTORY_ADDRESS,
            name: "DEFAULT_ADMIN_ROLE",
            role: honeyFactory.DEFAULT_ADMIN_ROLE()
        });
        _requireRole(honeyFactoryAdminRole, deployer);
        console2.log("HoneyFactory's DEFAULT_ADMIN_ROLE granted to:", msg.sender);

        RBAC.RoleDescription memory honeyFactoryReaderAdminRole = RBAC.RoleDescription({
            contractName: "HoneyFactoryReader",
            contractAddr: HONEY_FACTORY_READER_ADDRESS,
            name: "DEFAULT_ADMIN_ROLE",
            role: honeyFactoryReader.DEFAULT_ADMIN_ROLE()
        });
        _requireRole(honeyFactoryReaderAdminRole, deployer);
        console2.log("HoneyFactoryReader's DEFAULT_ADMIN_ROLE granted to:", msg.sender);

        // granting MANAGER_ROLE to msg.sender as we need to call
        // setMintRate and setRedeemRate while doing `addCollateral`
        RBAC.RoleDescription memory managerRole = RBAC.RoleDescription({
            contractName: "HoneyFactory",
            contractAddr: HONEY_FACTORY_ADDRESS,
            name: "MANAGER_ROLE",
            role: honeyFactory.MANAGER_ROLE()
        });
        _grantRole(managerRole, deployer);

        // grant the PAUSER_ROLE to msg.sender
        RBAC.RoleDescription memory pauserRole = RBAC.RoleDescription({
            contractName: "HoneyFactory",
            contractAddr: HONEY_FACTORY_ADDRESS,
            name: "PAUSER_ROLE",
            role: honeyFactory.PAUSER_ROLE()
        });
        _grantRole(pauserRole, deployer);
    }
}
