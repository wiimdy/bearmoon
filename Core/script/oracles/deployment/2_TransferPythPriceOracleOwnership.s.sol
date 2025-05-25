// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { console2 } from "forge-std/Script.sol";
import { BaseScript } from "../../base/Base.s.sol";
import { RBAC } from "../../base/RBAC.sol";
import { PythPriceOracle } from "src/extras/PythPriceOracle.sol";
import { TIMELOCK_ADDRESS } from "../../gov/GovernanceAddresses.sol";
import { PYTH_PRICE_ORACLE_ADDRESS } from "../OraclesAddresses.sol";

contract TransferPythPriceOracleOwnershipScript is RBAC, BaseScript {
    // Placholder. Change before running the script.
    address internal constant NEW_OWNER = address(0); // TIMELOCK_ADDRESS;
    address internal constant PYTH_PRICE_ORACLE_MANAGER = address(0);

    function run() public virtual broadcast {
        require(NEW_OWNER != address(0), "NEW_OWNER must be set");
        require(PYTH_PRICE_ORACLE_MANAGER != address(0), "Pyth price oracle manager address not set");
        if (NEW_OWNER == TIMELOCK_ADDRESS) {
            _validateCode("TimeLock", NEW_OWNER);
        }
        _validateCode("PythPriceOracle", PYTH_PRICE_ORACLE_ADDRESS);

        PythPriceOracle pythPriceOracle = PythPriceOracle(PYTH_PRICE_ORACLE_ADDRESS);

        RBAC.RoleDescription memory adminRole = RBAC.RoleDescription({
            contractName: "PythPriceOracle",
            contractAddr: PYTH_PRICE_ORACLE_ADDRESS,
            name: "DEFAULT_ADMIN_ROLE",
            role: pythPriceOracle.DEFAULT_ADMIN_ROLE()
        });

        RBAC.RoleDescription memory managerRole = RBAC.RoleDescription({
            contractName: "PythPriceOracle",
            contractAddr: PYTH_PRICE_ORACLE_ADDRESS,
            name: "MANAGER_ROLE",
            role: pythPriceOracle.MANAGER_ROLE()
        });

        RBAC.AccountDescription memory governance = RBAC.AccountDescription({ name: "governance", addr: NEW_OWNER });

        RBAC.AccountDescription memory manager =
            RBAC.AccountDescription({ name: "manager", addr: PYTH_PRICE_ORACLE_MANAGER });

        RBAC.AccountDescription memory deployer = RBAC.AccountDescription({ name: "deployer", addr: msg.sender });

        _transferRole(managerRole, deployer, manager);
        _transferRole(adminRole, deployer, governance);
    }
}
