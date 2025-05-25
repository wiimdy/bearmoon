// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { console2 } from "forge-std/Script.sol";
import { BaseScript } from "../../base/Base.s.sol";
import { ConfigPOL } from "../logic/ConfigPOL.sol";
import { BGT } from "src/pol/BGT.sol";
import { POLDeployer } from "src/pol/POLDeployer.sol";
import { BGTFeeDeployer } from "src/pol/BGTFeeDeployer.sol";
import { RBAC } from "../../base/RBAC.sol";
import {
    BEACON_DEPOSIT_ADDRESS,
    WBERA_ADDRESS,
    BGT_ADDRESS,
    BERACHEF_ADDRESS,
    BLOCK_REWARD_CONTROLLER_ADDRESS,
    DISTRIBUTOR_ADDRESS,
    REWARD_VAULT_FACTORY_ADDRESS,
    BGT_STAKER_ADDRESS,
    FEE_COLLECTOR_ADDRESS
} from "../POLAddresses.sol";

import {
    BERA_CHEF_SALT,
    BLOCK_REWARD_CONTROLLER_SALT,
    DISTRIBUTOR_SALT,
    REWARDS_FACTORY_SALT,
    BGT_STAKER_SALT,
    FEE_COLLECTOR_SALT
} from "../POLSalts.sol";

contract DeployPoLScript is BaseScript, ConfigPOL, RBAC {
    // NOTE: By default all POL params are set to 0

    // FeeCollector params
    // The amount to be paid out to the fee collector in order to claim fees.
    uint256 internal constant PAYOUT_AMOUNT = 5000 ether; // WBERA

    // BeraChef params
    // The block delay for activate queued reward allocation.
    uint64 internal constant REWARD_ALLOCATION_BLOCK_DELAY = 8191;

    function run() public broadcast {
        console2.log("BeaconDeposit: ", BEACON_DEPOSIT_ADDRESS);
        _validateCode("BeaconDeposit", BEACON_DEPOSIT_ADDRESS);
        console2.log("WBERA: ", WBERA_ADDRESS);
        _validateCode("WBERA", WBERA_ADDRESS);
        console2.log("BGT: ", BGT_ADDRESS);
        _validateCode("BGT", BGT_ADDRESS);

        bgt = BGT(BGT_ADDRESS);

        // deployment
        _deployPoL();
        _deployBGTFees();

        // configuration
        _setBGTAddresses();
        _setRewardAllocationBlockDelay(REWARD_ALLOCATION_BLOCK_DELAY);
    }

    /// @dev Deploy main POL contract and initialize them
    function _deployPoL() internal {
        console2.log("\n\nDeploying PoL contracts...");

        console2.log("POLDeployer init code size", type(POLDeployer).creationCode.length);
        polDeployer = new POLDeployer(
            BGT_ADDRESS,
            msg.sender,
            BERA_CHEF_SALT,
            BLOCK_REWARD_CONTROLLER_SALT,
            DISTRIBUTOR_SALT,
            REWARDS_FACTORY_SALT
        );
        console2.log("POLDeployer deployed at:", address(polDeployer));

        beraChef = polDeployer.beraChef();
        _checkDeploymentAddress("BeraChef", address(beraChef), BERACHEF_ADDRESS);

        blockRewardController = polDeployer.blockRewardController();
        _checkDeploymentAddress(
            "BlockRewardController", address(blockRewardController), BLOCK_REWARD_CONTROLLER_ADDRESS
        );

        distributor = polDeployer.distributor();
        _checkDeploymentAddress("Distributor", address(distributor), DISTRIBUTOR_ADDRESS);

        // Give roles to the deployer
        RBAC.AccountDescription memory deployer = RBAC.AccountDescription({ name: "deployer", addr: msg.sender });

        // NOTE: the manager role on the distributor is not assigned to anyone, hence there is no need to revoke it.
        RBAC.RoleDescription memory distributorManagerRole = RBAC.RoleDescription({
            contractName: "Distributor",
            contractAddr: DISTRIBUTOR_ADDRESS,
            name: "MANAGER_ROLE",
            role: distributor.MANAGER_ROLE()
        });

        _grantRole(distributorManagerRole, deployer);

        rewardVaultFactory = polDeployer.rewardVaultFactory();
        _checkDeploymentAddress("RewardVaultFactory", address(rewardVaultFactory), REWARD_VAULT_FACTORY_ADDRESS);

        RBAC.RoleDescription memory rewardVaultFactoryManagerRole = RBAC.RoleDescription({
            contractName: "RewardVaultFactory",
            contractAddr: REWARD_VAULT_FACTORY_ADDRESS,
            name: "VAULT_MANAGER_ROLE",
            role: rewardVaultFactory.VAULT_MANAGER_ROLE()
        });
        RBAC.RoleDescription memory rewardVaultFactoryPauserRole = RBAC.RoleDescription({
            contractName: "RewardVaultFactory",
            contractAddr: REWARD_VAULT_FACTORY_ADDRESS,
            name: "VAULT_PAUSER_ROLE",
            role: rewardVaultFactory.VAULT_PAUSER_ROLE()
        });

        _grantRole(rewardVaultFactoryManagerRole, deployer);
        _grantRole(rewardVaultFactoryPauserRole, deployer);
    }

    /// @dev Deploy BGTStaker and FeeCollector
    function _deployBGTFees() internal {
        console2.log("\n\nDeploying BGTFeeDeployer...");

        console2.log("BGTFeeDeployer init code size", type(BGTFeeDeployer).creationCode.length);
        feeDeployer = new BGTFeeDeployer(
            BGT_ADDRESS, msg.sender, WBERA_ADDRESS, BGT_STAKER_SALT, FEE_COLLECTOR_SALT, PAYOUT_AMOUNT
        );
        console2.log("BGTFeeDeployer deployed at:", address(feeDeployer));

        bgtStaker = feeDeployer.bgtStaker();
        _checkDeploymentAddress("BGTStaker", address(bgtStaker), BGT_STAKER_ADDRESS);

        feeCollector = feeDeployer.feeCollector();
        _checkDeploymentAddress("FeeCollector", address(feeCollector), FEE_COLLECTOR_ADDRESS);

        console2.log("Set the payout amount to %d", PAYOUT_AMOUNT);

        // Give roles to the deployer
        RBAC.AccountDescription memory deployer = RBAC.AccountDescription({ name: "deployer", addr: msg.sender });

        RBAC.RoleDescription memory feeCollectorManagerRole = RBAC.RoleDescription({
            contractName: "FeeCollector",
            contractAddr: FEE_COLLECTOR_ADDRESS,
            name: "MANAGER_ROLE",
            role: feeCollector.MANAGER_ROLE()
        });
        RBAC.RoleDescription memory feeCollectorPauserRole = RBAC.RoleDescription({
            contractName: "FeeCollector",
            contractAddr: FEE_COLLECTOR_ADDRESS,
            name: "PAUSER_ROLE",
            role: feeCollector.PAUSER_ROLE()
        });

        _grantRole(feeCollectorManagerRole, deployer);
        _grantRole(feeCollectorPauserRole, deployer);
    }
}
