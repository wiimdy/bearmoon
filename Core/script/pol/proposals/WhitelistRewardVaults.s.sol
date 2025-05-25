// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { console2 } from "forge-std/Script.sol";
import { BaseScript } from "../../base/Base.s.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { GOVERNANCE_ADDRESS } from "../../gov/GovernanceAddresses.sol";
import { BERACHEF_ADDRESS, BGT_ADDRESS } from "../POLAddresses.sol";
import { IBeraChef } from "src/pol/interfaces/IBeraChef.sol";
import { BerachainGovernance } from "src/gov/BerachainGovernance.sol";

/// @notice This script create a proposal to whitelist reward vaults
contract SetDefaultRewardAllocationScript is BaseScript {
    // Placeholder. Reward vault addresses to whitelist and metadata.
    // METADATAs are used from indexer to save and then display the vault's informations.
    // TDB: Format of METADATA (can be empty string)
    address internal constant REWARD_VAULT_BERA_HONEY = address(0);
    string internal constant REWARD_VAULT_BERA_HONEY_METADATA = "BERA-HONEY";
    address internal constant REWARD_VAULT_BERA_ETH = address(0);
    string internal constant REWARD_VAULT_BERA_ETH_METADATA = "BERA-ETH";
    address internal constant REWARD_VAULT_BERA_WBTC = address(0);
    string internal constant REWARD_VAULT_BERA_WBTC_METADATA = "BERA-WBTC";
    address internal constant REWARD_VAULT_USDC_HONEY = address(0);
    string internal constant REWARD_VAULT_USDC_HONEY_METADATA = "USDC-HONEY";
    address internal constant REWARD_VAULT_BEE_HONEY = address(0);
    string internal constant REWARD_VAULT_BEE_HONEY_METADATA = "BEE-HONEY";
    address internal constant REWARD_VAULT_USDS_HONEY = address(0);
    string internal constant REWARD_VAULT_USDS_HONEY_METADATA = "USDS-HONEY";

    address[] internal REWARD_VAULTS = [
        REWARD_VAULT_BERA_HONEY,
        REWARD_VAULT_BERA_ETH,
        REWARD_VAULT_BERA_WBTC,
        REWARD_VAULT_USDC_HONEY,
        REWARD_VAULT_BEE_HONEY,
        REWARD_VAULT_USDS_HONEY
    ];

    string[] internal REWARD_VAULTS_METADATA = [
        REWARD_VAULT_BERA_HONEY_METADATA,
        REWARD_VAULT_BERA_ETH_METADATA,
        REWARD_VAULT_BERA_WBTC_METADATA,
        REWARD_VAULT_USDC_HONEY_METADATA,
        REWARD_VAULT_BEE_HONEY_METADATA,
        REWARD_VAULT_USDS_HONEY_METADATA
    ];

    function run() public broadcast {
        _validateCode("Governance", GOVERNANCE_ADDRESS);
        _validateCode("BeraChef", BERACHEF_ADDRESS);
        _validateVaultAddresses();

        require(
            REWARD_VAULTS.length == REWARD_VAULTS_METADATA.length,
            "WhitelistRewardVaultsScript: vaults and metadata length must match"
        );

        BerachainGovernance governance = BerachainGovernance(payable(GOVERNANCE_ADDRESS));
        uint256 proposalThreshold = governance.proposalThreshold();
        require(
            IERC20(BGT_ADDRESS).balanceOf(msg.sender) >= proposalThreshold,
            "SetDefaultRewardAllocationScript: insufficient BGT balance"
        );

        address[] memory targets = new address[](REWARD_VAULTS.length);
        bytes[] memory calldatas = new bytes[](REWARD_VAULTS_METADATA.length);
        for (uint8 i = 0; i < REWARD_VAULTS.length; i++) {
            targets[i] = BERACHEF_ADDRESS;
            calldatas[i] = abi.encodeCall(
                IBeraChef.setVaultWhitelistedStatus, (REWARD_VAULTS[i], true, REWARD_VAULTS_METADATA[i])
            );
        }

        string memory description = string(abi.encodePacked("Whitelist reward vaults"));

        console2.log("Creating proposal to set default reward allocation...");
        uint256 proposalId = governance.propose(targets, new uint256[](REWARD_VAULTS.length), calldatas, description);
        console2.log("Proposal ID: %d", proposalId);
    }

    function _validateVaultAddresses() internal view {
        _validateCode("REWARD_VAULT_BERA_HONEY", REWARD_VAULT_BERA_HONEY);
        _validateCode("REWARD_VAULT_BERA_ETH", REWARD_VAULT_BERA_ETH);
        _validateCode("REWARD_VAULT_BERA_WBTC", REWARD_VAULT_BERA_WBTC);
        _validateCode("REWARD_VAULT_USDC_HONEY", REWARD_VAULT_USDC_HONEY);
        _validateCode("REWARD_VAULT_BEE_HONEY", REWARD_VAULT_BEE_HONEY);
        _validateCode("REWARD_VAULT_USDS_HONEY", REWARD_VAULT_USDS_HONEY);
    }
}
