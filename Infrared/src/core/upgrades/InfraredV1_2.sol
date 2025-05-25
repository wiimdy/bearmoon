// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {EnumerableSet} from
    "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {IBeraChef} from "@berachain/pol/interfaces/IBeraChef.sol";
import {IRewardVault as IBerachainRewardsVault} from
    "@berachain/pol/interfaces/IRewardVault.sol";
import {IRewardVaultFactory as IBerachainRewardsVaultFactory} from
    "@berachain/pol/interfaces/IRewardVaultFactory.sol";
import {IBerachainBGT} from "src/interfaces/IBerachainBGT.sol";
import {DataTypes} from "src/utils/DataTypes.sol";
import {Errors} from "src/utils/Errors.sol";
import {InfraredVaultDeployer} from "src/utils/InfraredVaultDeployer.sol";
import {IVoter} from "src/voting/interfaces/IVoter.sol";
import {IWBERA} from "src/interfaces/IWBERA.sol";
import {InfraredBGT} from "src/core/InfraredBGT.sol";
import {IInfraredGovernanceToken} from
    "src/interfaces/IInfraredGovernanceToken.sol";
import {IBribeCollector} from "src/interfaces/IBribeCollector.sol";
import {IInfraredDistributor} from "src/interfaces/IInfraredDistributor.sol";
import {IInfraredVault} from "src/interfaces/IInfraredVault.sol";
import {
    ConfigTypes,
    IInfraredV1_2
} from "src/interfaces/upgrades/IInfraredV1_2.sol";
import {InfraredUpgradeable} from "src/core/InfraredUpgradeable.sol";
import {InfraredVault} from "src/core/InfraredVault.sol";
import {IInfraredBERA} from "src/interfaces/IInfraredBERA.sol";
import {ValidatorManagerLib} from "src/core/libraries/ValidatorManagerLib.sol";
import {ValidatorTypes} from "src/core/libraries/ValidatorTypes.sol";
import {VaultManagerLib} from "src/core/libraries/VaultManagerLib.sol";
import {RewardsLib} from "src/core/libraries/RewardsLib.sol";

/*

        Helping Bears get their Bread, since Day One

⠀⠀⠀⠀⠀⠀⠀⣀⣠⣤⣤⣤⣤⣄⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⢀⣤⣾⣿⡿⠿⠿⠛⠛⠻⠿⢿⣿⣷⣤⡀⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⣰⣿⣿⠟⠁⠀⠀⠀⠀⠀⠀⠀⠀⠈⠙⢿⣿⣮⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣴⣶⣿⣿⣿⣿⣿⣶⣦⣄⡀⠀⠀⠀⠀
⠀⣼⣿⠟⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢿⣿⣧⠀⠀⢀⣀⣀⣤⣤⣤⣤⣤⣤⣤⣤⣀⣀⠀⠀⠀⠀⠀⠀⠀⠀⣴⣿⡿⠟⠋⠁⠀⠀⠀⠈⠉⠛⢿⣿⣦⡀⠀⠀
⢸⣿⣿⣶⣶⣶⣶⣤⣄⡀⠀⠀⠀⠀⠀⠀⠀⢀⣨⣿⣿⣾⣿⣿⠿⠿⠟⠛⠛⠛⠛⠛⠻⠿⠿⠿⣿⣿⣷⣶⣤⣤⣀⣼⣿⠟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⣿⣿⡄⠀
⣼⣿⡟⠛⠉⠉⠙⠛⠿⣿⣷⡄⠀⠀⢀⣤⣶⣿⠿⠟⠋⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠙⠛⠻⠿⣿⣿⣤⡀⠀⠀⠀⠀⠀⠀⢀⣀⣤⣤⣤⣌⣿⣷⠀
⣿⣿⠁⠀⠀⠀⠀⠀⠈⠈⢻⣿⣦⣶⣿⠟⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⠻⣿⣷⣄⠀⢀⣴⣾⣿⠿⠛⠛⠛⠻⣿⣿⡄
⢹⣿⡆⠀⠀⠀⠀⠀⠀⠀⢠⣽⣿⠟⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠙⢿⣷⣿⣿⠋⠀⠀⠀⠀⠀⠀⣸⣿⠇
⠘⣿⣿⡄⠀⠀⠀⠀⣠⣴⣿⡟⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⣿⣿⡀⠀⠀⠀⠀⠀⢀⣿⣿⠀
⠀⢈⢿⣿⣦⣀⢀⢤⣾⣿⠏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⣿⣿⡄⡀⠀⠀⢠⣾⣿⠃⠀
⠀⠈⠀⠙⠻⣿⣿⣿⡿⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢿⣿⣔⣦⣾⣿⠟⠁⠀⠀
⠀⠀⠀⠀⠀⣀⣿⣿⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⣿⣿⡟⠋⠁⠀⠀⠀⠀
⠀⠀⠀⠀⠀⣼⣿⠇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⡇⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⢠⣿⡿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⢸⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢻⣿⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠰⣾⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⡆⠀⠀⠀⠀⠀
⠀⠀⠀⠀⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣴⣿⣿⣿⣿⣷⡆⠀⠀⡠⠄⠀⠀⠀⠀⠀⠐⠢⢄⡀⠀⠀⠀⠀⢀⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⡇⠀⠀⠀⠀⠀
⠀⠀⠀⠈⢹⣿⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠻⠿⠿⠿⠟⠁⡠⠋⠀⠀⠀⢠⣿⣿⣷⡄⠀⠀⠈⢦⠀⢠⣿⣿⣿⣿⣿⣶⡄⠀⠀⠀⠀⠀⠀⠀⠀⣼⣿⠃⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠸⣿⣇⠀⠀⠀⠀⠀⠀⠀⠀⠰⢒⢠⠖⡆⡤⡄⢰⠁⠀⠀⠀⠀⣸⣿⣿⣿⠃⠀⠀⠀⠀⢃⠀⠙⠻⠿⠿⠿⠿⠃⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⢿⣿⡆⠀⠀⠀⠀⠀⠀⠀⡇⡼⡜⣰⢻⢀⡇⠀⠀⣀⣤⣶⣿⣿⡿⢿⣿⣷⣄⡀⠀⠀⠘⠀⢠⠒⡆⡤⡆⣀⡀⠀⠀⠀⠀⠀⠀⠀⣸⣿⡇⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠈⢿⣿⣆⠀⠀⠀⠀⠀⠀⠈⠀⠉⠁⢘⣮⣶⣿⠿⠿⠟⣛⣋⣁⠀⠀⠙⠻⢿⣿⣶⣶⣦⣤⣇⣜⡜⢠⢳⢃⡆⠀⠀⠀⠀⠀⠀⣠⣿⡿⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠈⢻⣿⣧⡀⠀⠀⠀⠀⠀⠀⠀⠀⣼⣿⠋⠀⡤⠊⠁⠀⠀⠀⠉⠑⠢⣄⠤⠤⠤⢍⣉⠻⢿⣿⣦⠃⠳⠞⠀⠀⠀⠀⠀⠀⣰⣿⡿⠉⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠙⢿⣿⣦⣀⠀⣀⣠⣤⣄⡀⣿⡇⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠢⡹⣿⣧⠀⠀⠀⠀⠀⠀⣠⣾⣿⠟⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⠻⢿⣿⣿⠟⠛⠻⣿⣿⡿⡠⢈⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⣽⣿⣶⣶⣦⣤⣴⣿⣿⠟⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣿⡿⠁⠀⠀⠀⠈⣿⣿⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣰⣿⠟⠉⠀⠉⠻⣿⣿⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⣿⡇⠀⠀⠀⠀⠀⣾⣿⠀⡎⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⡟⠀⠀⠀⠀⠀⢻⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⣿⣷⣀⠀⠀⢀⣼⣿⠏⢠⠇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣷⠀⠀⠀⠀⠀⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢻⣿⣿⣿⣿⣿⠃⠀⠸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢰⣼⣿⣷⣤⣤⣤⣾⣿⠏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⠇⠀⣿⡿⠁⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡎⣿⡟⢹⣿⡟⠛⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
*/

/// @title Infrared Protocol Core Contract
/// @notice Provides core functionalities for managing validators, vaults, and reward distribution in the Infrared protocol.
/// @dev Serves as the main entry point for interacting with the Infrared protocol
/// @dev The contract is upgradeable, ensuring flexibility for governance-led upgrades and chain compatibility.
contract InfraredV1_2 is InfraredUpgradeable, IInfraredV1_2 {
    using SafeTransferLib for ERC20;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using ValidatorManagerLib for ValidatorManagerLib.ValidatorStorage;
    using VaultManagerLib for VaultManagerLib.VaultStorage;
    using RewardsLib for RewardsLib.RewardsStorage;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       STORAGE                              */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice The Canonical BGT token Contract
    IBerachainBGT internal _bgt;

    /// @notice The InfraredBGT liquid staked token
    InfraredBGT public ibgt;

    /// @notice IBerachainRewardsVaultFactory instance of the rewards factory contract address
    IBerachainRewardsVaultFactory public rewardsFactory;

    /// @notice The Berachain chef contract for distributing validator rewards
    IBeraChef public chef;

    /// @notice The WBERA token contract
    IWBERA public wbera;

    /// @notice The Honey token contract
    ERC20 public honey;

    /// @notice The Berachain Bribe Collector
    IBribeCollector public collector;

    /// @notice The InfraredDistributor contract
    IInfraredDistributor public distributor;

    /// @notice The Infrared Voter contract
    IVoter public voter;

    /// @notice iBera Contract Instance
    IInfraredBERA public ibera;

    /// @notice The Infrared Governance Token
    IInfraredGovernanceToken public ir;

    /// @notice The Infrared BGT Vault
    IInfraredVault public ibgtVault;

    /// @notice Upgradeable ERC-7201 storage for Validator lib
    /// @dev keccak256(abi.encode(uint256(keccak256(bytes("infrared.validatorStorage"))) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant VALIDATOR_STORAGE_LOCATION =
        0x8ea5a3cc3b9a6be40b16189aeb1b6e6e61492e06efbfbe10619870b5bc1cc500;

    /// @notice Upgradeable ERC-7201 storage for Vault lib
    /// @dev keccak256(abi.encode(uint256(keccak256(bytes("infrared.vaultStorage"))) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant VAULT_STORAGE_LOCATION =
        0x1bb2f1339407e6d63b93b8b490a9d43c5651f6fc4327c66addd5939450742a00;

    /// @notice Upgradeable ERC-7201 storage for Rewards lib
    /// @dev keccak256(abi.encode(uint256(keccak256(bytes("infrared.rewardsStorage"))) - 1)) & ~bytes32(uint256(0xff));
    bytes32 public constant REWARDS_STORAGE_LOCATION =
        0xad12e6d08cc0150709acd6eed0bf697c60a83227922ab1d254d1ca4d3072ca00;

    /// Reserve storage slots for future upgrades for safety
    uint256[40] private __gap;

    /// @return vs The validator storage struct
    function _validatorStorage()
        internal
        pure
        returns (ValidatorManagerLib.ValidatorStorage storage vs)
    {
        bytes32 position = VALIDATOR_STORAGE_LOCATION;
        assembly {
            vs.slot := position
        }
    }

    /// @return vs The vault storage struct
    function _vaultStorage()
        internal
        pure
        returns (VaultManagerLib.VaultStorage storage vs)
    {
        bytes32 position = VAULT_STORAGE_LOCATION;
        assembly {
            vs.slot := position
        }
    }

    /// @return rs The rewards storage struct
    function _rewardsStorage()
        internal
        pure
        returns (RewardsLib.RewardsStorage storage rs)
    {
        bytes32 position = REWARDS_STORAGE_LOCATION;
        assembly {
            rs.slot := position
        }
    }

    /// @dev Ensures that only the collector contract can call the function
    ///     Reverts if the caller is not the collector
    modifier onlyCollector() {
        if (msg.sender != address(collector)) {
            revert Errors.Unauthorized(msg.sender);
        }
        _;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       INITIALIZATION                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function initializeV1_2(address[] calldata _stakingTokens)
        external
        onlyGovernor
    {
        // migrate initial reward pools
        uint256 len = _stakingTokens.length;
        for (uint256 i; i < len; i++) {
            address _token = _stakingTokens[i];
            _migrateVault(_token, uint8(1));
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       VAULT REGISTRY                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    ///////
    /// @notice Registers a new vault for a given asset
    /// @dev Infrared.sol must be admin over MINTER_ROLE on InfraredBGT to grant minter role to deployed vault
    /// @param _asset The address of the asset, such as a specific LP token
    /// @return vault The address of the newly created InfraredVault contract
    /// @custom:emits NewVault with the caller, asset address, and new vault address.
    ////
    function registerVault(address _asset)
        external
        returns (IInfraredVault vault)
    {
        vault = IInfraredVault(_vaultStorage().registerVault(_asset));
        emit NewVault(msg.sender, _asset, address(vault));
    }

    /// @notice Sets new vault registration paused or not
    /// @param pause True to pause, False to un pause
    function setVaultRegistrationPauseStatus(bool pause)
        external
        onlyGovernor
    {
        _vaultStorage().setVaultRegistrationPauseStatus(pause);
        emit VaultRegistrationPauseStatus(pause);
    }

    /// @notice Adds a new reward token to a specific staking vault
    /// @dev Only callable by governance when contract is initialized
    /// @param _stakingToken The address of the staking token associated with the vault
    /// @param _rewardsToken The address of the token to be added as a reward
    /// @param _rewardsDuration The duration period for the rewards distribution, in seconds
    /// @custom:error ZeroAmount if _rewardsDuration is 0
    /// @custom:error RewardTokenNotWhitelisted if _rewardsToken is not whitelisted
    /// @custom:error NoRewardsVault if vault doesn't exist for _stakingToken
    function addReward(
        address _stakingToken,
        address _rewardsToken,
        uint256 _rewardsDuration
    ) external onlyGovernor {
        _vaultStorage().addReward(
            _stakingToken, _rewardsToken, _rewardsDuration
        );
    }

    /// @notice Removes a malicious or failing reward token from a staking vault
    /// @dev CAUTION: This is an emergency function that will result in loss of unclaimed rewards.
    /// @dev Only callable by governance when:
    ///      1. The reward token is malfunctioning (e.g., transfers failing)
    ///      2. The reward token is malicious
    ///      3. The reward distribution needs to be forcefully terminated
    /// @dev Consequences:
    ///      - All unclaimed rewards will be permanently lost
    ///      - Users will not be able to claim outstanding rewards
    ///      - Remaining reward tokens will need to be recovered separately
    /// @param _stakingToken The address of the staking token associated with the vault
    /// @param _rewardsToken The address of the reward token to be removed
    function removeReward(address _stakingToken, address _rewardsToken)
        external
        onlyGovernor
    {
        _vaultStorage().removeReward(_stakingToken, _rewardsToken);
    }

    /// @notice Adds reward incentives to a specific staking vault
    /// @dev Transfers reward tokens from caller to this contract, then notifies vault of new rewards
    /// @param _stakingToken The address of the staking token associated with the vault
    /// @param _rewardsToken The address of the token being added as incentives
    /// @param _amount The amount of reward tokens to add as incentives
    /// @custom:error ZeroAmount if _amount is 0
    /// @custom:error NoRewardsVault if vault doesn't exist for _stakingToken
    /// @custom:error RewardTokenNotWhitelisted if reward token hasn't been configured for the vault
    /// @custom:access Callable when contract is initialized
    /// @custom:security Requires caller to have approved this contract to spend _rewardsToken
    function addIncentives(
        address _stakingToken,
        address _rewardsToken,
        uint256 _amount
    ) external {
        bool whitelistStatus = whitelistedRewardTokens(_rewardsToken);

        if (!whitelistStatus) {
            revert Errors.RewardTokenNotWhitelisted();
        }

        _vaultStorage().addIncentives(_stakingToken, _rewardsToken, _amount);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       ADMIN                                */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    // string public constant CURRENT_VAULT_VERSION = "1.0.1";

    /// @notice Migrates reward vault from old v0 to new v1
    /// @param _asset Staking asset of vault
    /// @param versionToUpgradeTo Vault version number to update to (initial version is 0)
    function migrateVault(address _asset, uint8 versionToUpgradeTo)
        external
        onlyGovernor
        returns (address newVault)
    {
        newVault = _migrateVault(_asset, versionToUpgradeTo);
    }

    function _migrateVault(address _asset, uint8 versionToUpgradeTo)
        internal
        returns (address newVault)
    {
        uint8 currentVersion = _vaultStorage().vaultVersions[_asset];

        if (currentVersion >= versionToUpgradeTo) {
            revert Errors.VaultAlreadyUpToDate();
        }

        IInfraredVault oldVault = _vaultStorage().vaultRegistry[_asset];
        if (address(oldVault) == address(0)) {
            revert Errors.NoRewardsVault();
        }

        // Create new vault
        newVault = InfraredVaultDeployer.deploy(
            _asset, _vaultStorage().rewardsDuration
        );
        emit NewVault(msg.sender, _asset, address(newVault));

        IInfraredVault vault = IInfraredVault(newVault);

        // Pause old vault to prevent new deposits during migration
        oldVault.pauseStaking();

        // harvest old vault
        uint256 bgtAmt = _rewardsStorage().harvestVault(
            oldVault,
            address(_bgt),
            address(ibgt),
            address(voter),
            address(ir),
            rewardsDuration()
        );
        emit VaultHarvested(msg.sender, _asset, address(oldVault), bgtAmt);

        // Set up rewards in new vault
        address[] memory _rewardTokens = oldVault.getAllRewardTokens();
        uint256 len = _rewardTokens.length;
        for (uint256 i = 0; i < len; i++) {
            address token = _rewardTokens[i];
            if (token == address(ibgt)) continue; // skip ibgt as default reward
            vault.addReward(token, _vaultStorage().rewardsDuration);
        }

        // update ibgtVault if _aaset is ibgt
        if (_asset == address(ibgt)) {
            ibgtVault = vault;
        }

        // Update registry
        _vaultStorage().vaultRegistry[_asset] = vault;
        _vaultStorage().vaultVersions[_asset] = versionToUpgradeTo;

        emit VaultMigrated(msg.sender, _asset, address(oldVault), newVault);
    }

    /// @notice Updates the whitelist status of a reward token
    /// @param _token The address of the token to whitelist or remove from whitelist
    /// @param _whitelisted A boolean indicating if the token should be whitelisted
    function updateWhiteListedRewardTokens(address _token, bool _whitelisted)
        external
        onlyGovernor
    {
        bool previousStatus = whitelistedRewardTokens(_token);
        _vaultStorage().updateWhitelistedRewardTokens(_token, _whitelisted);
        emit WhiteListedRewardTokensUpdated(
            msg.sender, _token, previousStatus, _whitelisted
        );
    }

    /// @notice Sets the new duration for reward distributions in InfraredVaults
    /// @param _rewardsDuration The new reward duration period, in seconds
    /// @dev Only callable by governance
    function updateRewardsDuration(uint256 _rewardsDuration)
        external
        onlyGovernor
    {
        uint256 oldRewardsDuration = rewardsDuration();
        _vaultStorage().updateRewardsDuration(_rewardsDuration);
        emit RewardsDurationUpdated(
            msg.sender, oldRewardsDuration, _rewardsDuration
        );
    }

    /// @notice Updates the rewards duration for a specific reward token on a specific vault
    /// @param _stakingToken The address of the staking asset associated with the vault
    /// @param _rewardsToken The address of the reward token to update the duration for
    /// @param _rewardsDuration The new reward duration period, in seconds
    /// @dev Only callable by governance
    function updateRewardsDurationForVault(
        address _stakingToken,
        address _rewardsToken,
        uint256 _rewardsDuration
    ) external onlyGovernor {
        _vaultStorage().updateRewardsDurationForVault(
            _stakingToken, _rewardsToken, _rewardsDuration
        );
    }

    /// @notice Pauses staking functionality on a specific vault
    /// @param _asset The address of the staking asset associated with the vault to pause
    /// @dev Only callable by pauser, will revert if vault doesn't exist
    function pauseStaking(address _asset) external onlyPauser {
        _vaultStorage().pauseStaking(_asset);
    }

    /// @notice Un-pauses staking functionality on a specific vault
    /// @param _asset The address of the staking asset associated with the vault to unpause
    /// @dev Only callable by gov, will revert if vault doesn't exist
    function unpauseStaking(address _asset) external onlyGovernor {
        _vaultStorage().unpauseStaking(_asset);
    }

    /// @notice Pauses staking functionality on an old vault
    /// @param _vault The address of the vault to pause
    function pauseOldStaking(address _vault) external onlyGovernor {
        VaultManagerLib.pauseOldStaking(_vault);
    }

    /// @notice Un-pauses staking functionality on an old vault
    /// @param _vault The address of the vault to unpause
    /// @dev Only callable by gov, will revert if vault doesn't exist
    function unpauseOldStaking(address _vault) external onlyGovernor {
        VaultManagerLib.unpauseOldStaking(_vault);
    }

    /// @notice Claims lost rewards on a specific vault
    /// @param _asset The address of the staking asset associated with the vault to claim lost rewards on
    /// @dev Only callable by governance, will revert if vault doesn't exist
    function claimLostRewardsOnVault(address _asset) external onlyGovernor {
        _vaultStorage().claimLostRewardsOnVault(_asset);
    }

    /// @notice Recovers ERC20 tokens sent accidentally to the contract
    /// @param _to The address to receive the recovered tokens
    /// @param _token The address of the token to recover
    /// @param _amount The amount of the token to recover
    function recoverERC20(address _to, address _token, uint256 _amount)
        external
        onlyGovernor
    {
        if (_to == address(0) || _token == address(0)) {
            revert Errors.ZeroAddress();
        }
        if (_amount == 0) revert Errors.ZeroAmount();
        // Check if there are any tracked protocol fees for this token
        if (
            ERC20(_token).balanceOf(address(this))
                - _rewardsStorage().protocolFeeAmounts[_token] < _amount
        ) {
            revert Errors.TokensReservedForProtocolFees();
        }

        ERC20(_token).safeTransfer(_to, _amount);
        emit Recovered(msg.sender, _token, _amount);
    }

    /// @notice Recover ERC20 tokens from a vault.
    /// @param _asset  address The address of the staking asset that the vault is for.
    /// @param _to     address The address to send the tokens to.
    /// @param _token  address The address of the token to recover.
    /// @param _amount uint256 The amount of the token to recover.
    function recoverERC20FromVault(
        address _asset,
        address _to,
        address _token,
        uint256 _amount
    ) external onlyGovernor {
        _vaultStorage().recoverERC20FromVault(_asset, _to, _token, _amount);
    }

    /// @notice Recover ERC20 tokens from old vault.
    /// @param _vault  address The address of the old vault.
    /// @param _to     address The address to send the tokens to.
    /// @param _token  address The address of the token to recover.
    /// @param _amount uint256 The amount of the token to recover.
    function recoverERC20FromOldVault(
        address _vault,
        address _to,
        address _token,
        uint256 _amount
    ) external onlyGovernor {
        VaultManagerLib.recoverERC20FromOldVault(_vault, _to, _token, _amount);
    }

    /// @notice Delegates BGT votes to `_delegatee` address.
    /// @param _delegatee  address The address to delegate votes to
    function delegateBGT(address _delegatee) external onlyGovernor {
        RewardsLib.delegateBGT(_delegatee, address(_bgt));
    }

    /// @notice Updates the weight for iBERA bribes
    /// @param _weight uint256 The weight value
    function updateInfraredBERABribeSplit(uint256 _weight)
        external
        onlyGovernor
    {
        uint256 prevWeight = _rewardsStorage().bribeSplitRatio;
        _rewardsStorage().updateInfraredBERABribeSplit(_weight);
        emit InfraredBERABribeSplitUpdated(msg.sender, prevWeight, _weight);
    }

    /// @notice Updates the fee rate charged on different harvest functions
    /// @notice Please harvest all assosiated rewards for a given type before updating
    /// @dev Fee rate in units of 1e6 or hundredths of 1 bip
    /// @param _t   FeeType The fee type
    /// @param _fee uint256 The fee rate to update to
    function updateFee(ConfigTypes.FeeType _t, uint256 _fee)
        external
        onlyGovernor
    {
        uint256 prevFee = fees(uint256(_t));
        _rewardsStorage().updateFee(_t, _fee);
        emit FeeUpdated(msg.sender, _t, prevFee, _fee);
    }

    /// @notice Claims accumulated protocol fees in contract
    /// @param _to     address The recipient of the fees
    /// @param _token  address The token to claim fees in
    function claimProtocolFees(address _to, address _token)
        external
        onlyGovernor
    {
        uint256 _amount = _rewardsStorage().claimProtocolFees(_to, _token);
        emit ProtocolFeesClaimed(msg.sender, _to, _token, _amount);
    }

    /// @notice Sets the address of the IR contract
    /// @dev Infrared must be granted MINTER_ROLE on IR to set the address
    /// @param _ir The address of the IR contract
    function setIR(address _ir) external onlyGovernor {
        if (_ir == address(0)) revert Errors.ZeroAddress();
        if (address(ir) != address(0)) revert Errors.AlreadySet();
        if (
            !IInfraredGovernanceToken(_ir).hasRole(
                IInfraredGovernanceToken(_ir).MINTER_ROLE(), address(this)
            )
        ) {
            revert Errors.Unauthorized(address(this));
        }
        ir = IInfraredGovernanceToken(_ir);
        _vaultStorage().updateWhitelistedRewardTokens(_ir, true);

        emit IRSet(msg.sender, _ir);
    }

    /// @notice Sets the address of the Voter contract
    /// @param _voter The address of the IR contract
    function setVoter(address _voter) external onlyGovernor {
        if (_voter == address(0)) revert Errors.ZeroAddress();
        if (address(voter) != address(0)) revert Errors.AlreadySet();

        voter = IVoter(_voter);
        emit VoterSet(msg.sender, _voter);
    }

    /// @notice Updates the mint rate for IR
    /// @param _irMintRate The new mint rate for IR
    function updateIRMintRate(uint256 _irMintRate) external onlyGovernor {
        uint256 oldRate = _rewardsStorage().irMintRate;
        _rewardsStorage().updateIRMintRate(_irMintRate);

        emit UpdatedIRMintRate(oldRate, _irMintRate, msg.sender);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       REWARDS                              */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function chargedFeesOnRewards(
        uint256 _amt,
        uint256 _feeTotal,
        uint256 _feeProtocol
    )
        public
        pure
        returns (uint256 amtRecipient, uint256 amtVoter, uint256 amtProtocol)
    {
        if (_feeTotal > RewardsLib.UNIT_DENOMINATOR) revert Errors.InvalidFee();
        return RewardsLib.chargedFeesOnRewards(_amt, _feeTotal, _feeProtocol);
    }

    /// @notice Claims all the BGT base and commission rewards minted to this contract for validators.
    function harvestBase() public whenNotPaused {
        uint256 bgtAmt =
            RewardsLib.harvestBase(address(ibgt), address(_bgt), address(ibera));
        emit BaseHarvested(msg.sender, bgtAmt);
    }

    /// @notice Claims all the BGT rewards for the vault associated with the given staking token.
    /// @param _asset address The address of the staking asset that the vault is for.
    function harvestVault(address _asset) external whenNotPaused {
        IInfraredVault vault = vaultRegistry(_asset);
        uint256 bgtAmt = _rewardsStorage().harvestVault(
            vault,
            address(_bgt),
            address(ibgt),
            address(voter),
            address(ir),
            rewardsDuration()
        );
        emit VaultHarvested(msg.sender, _asset, address(vault), bgtAmt);
    }

    /// @notice Claims all the BGT rewards for the old vault
    /// @param _vault The address of the old vault
    function harvestOldVault(address _vault, address _asset)
        external
        onlyKeeper
        whenNotPaused
    {
        uint256 bgtAmt = _rewardsStorage().harvestOldVault(
            IInfraredVault(_vault),
            vaultRegistry(_asset),
            address(_bgt),
            address(ibgt),
            address(voter)
        );

        emit VaultHarvested(msg.sender, _asset, address(_vault), bgtAmt);
    }

    /// @notice Claims all the bribes rewards in the contract forwarded from Berachain POL.
    /// @param _tokens address[] memory The addresses of the tokens to harvest in the contract.
    /// @dev This should be called right before the collector `claimFees` function.
    /// @dev 1. harvestBribes(), 2. collector.claimFees(), 3. collectBribes() (which handles the wBERA -> iBERA + fees distribution)
    function harvestBribes(address[] calldata _tokens) external whenNotPaused {
        /// @dev Check against the whitelisted tokens so that we dont interact with non-whitelisted transfer method.
        uint256 len = _tokens.length;
        bool[] memory whitelisted = new bool[](len);
        for (uint256 i; i < len; ++i) {
            if (whitelistedRewardTokens(_tokens[i])) {
                whitelisted[i] = true;
            }
        }

        /// @dev pass down the total list of _tokens and the whitelisted status of each token returning tokens and amounts harvested.
        (address[] memory tokens, uint256[] memory _amounts) = _rewardsStorage()
            .harvestBribes(address(collector), _tokens, whitelisted);

        /// @dev indexes should match for tokens,amounts, and whitelisted status.
        for (uint256 i; i < len; ++i) {
            if (whitelisted[i]) {
                emit BribeSupplied(address(collector), tokens[i], _amounts[i]);
            } else {
                emit RewardTokenNotSupported(_tokens[i]);
            }
        }
    }

    /// @notice Collects bribes from bribe collector and distributes to wiBERA and iBGT Infrared vaults.
    /// @notice _token The payout token for the bribe collector.
    /// @notice _amount The amount of payout received from bribe collector.
    function collectBribes(address _token, uint256 _amount)
        external
        onlyCollector
    {
        if (_token != address(wbera)) {
            revert Errors.RewardTokenNotSupported();
        }

        (uint256 amtInfraredBERA, uint256 amtIbgtVault) = _rewardsStorage()
            .collectBribesInWBERA(
            _amount,
            address(wbera),
            address(ibera),
            address(ibgtVault),
            address(voter),
            rewardsDuration()
        );

        emit BribesCollected(msg.sender, _token, amtInfraredBERA, amtIbgtVault);
    }

    /// @notice Credits all accumulated rewards to the operator
    function harvestOperatorRewards() public whenNotPaused {
        uint256 _amt = _rewardsStorage().harvestOperatorRewards(
            address(ibera), address(voter), address(distributor)
        );
        emit OperatorRewardsDistributed(
            address(ibera), address(distributor), _amt
        );
    }

    /// @notice Claims all the BGT staker rewards from boosting validators.
    /// @dev Sends rewards to iBGT vault.
    function harvestBoostRewards() external whenNotPaused {
        (address _token, uint256 _amount) = _rewardsStorage()
            .harvestBoostRewards(
            address(_bgt), address(ibgtVault), address(voter), rewardsDuration()
        );
        emit RewardSupplied(address(ibgtVault), _token, _amount);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       VALIDATORS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Adds validators to the set of `InfraredValidators`.
    /// @param _validators Validator[] memory The validators to add.
    function addValidators(ValidatorTypes.Validator[] calldata _validators)
        external
        onlyGovernor
    {
        /// @notice do not harvest if no validators in the system
        /// since `Distributor::notifyRewardAmount` will revert if there are rewards.
        if (_validatorStorage().numInfraredValidators() != 0) {
            harvestBase();
            harvestOperatorRewards();
        }

        _validatorStorage().addValidators(address(distributor), _validators);
        emit ValidatorsAdded(msg.sender, _validators);
    }

    /// @notice Removes validators from the set of `InfraredValidators`.
    /// @param _pubkeys bytes[] memory The pubkeys of the validators to remove.
    function removeValidators(bytes[] calldata _pubkeys)
        external
        onlyGovernor
    {
        harvestBase();
        harvestOperatorRewards();
        _validatorStorage().removeValidators(address(distributor), _pubkeys);
        emit ValidatorsRemoved(msg.sender, _pubkeys);
    }

    /// @notice Replaces a validator in the set of `InfraredValidators`.
    /// @param _current bytes The pubkey of the validator to replace.
    /// @param _new     bytes The new validator pubkey.
    function replaceValidator(bytes calldata _current, bytes calldata _new)
        external
        onlyGovernor
    {
        harvestBase();
        harvestOperatorRewards();
        _validatorStorage().replaceValidator(
            address(distributor), _current, _new
        );
        emit ValidatorReplaced(msg.sender, _current, _new);
    }

    /// @notice Queues a new cutting board on BeraChef for reward weight distribution for validator
    /// @param _pubkey             bytes                         The pubkey of the validator to queue the cutting board for
    /// @param _startBlock         uint64                        The start block for reward weightings
    /// @param _weights            IBeraChef.Weight[] calldata   The weightings used when distributor calls chef to distribute validator rewards
    function queueNewCuttingBoard(
        bytes calldata _pubkey,
        uint64 _startBlock,
        IBeraChef.Weight[] calldata _weights
    ) external onlyKeeper {
        if (!isInfraredValidator(_pubkey)) revert Errors.InvalidValidator();
        chef.queueNewRewardAllocation(_pubkey, _startBlock, _weights);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       BOOST                                */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Queue `_amts` of tokens to `_validators` for boosts.
    /// @param _pubkeys     bytes[] memory The pubkeys of the validators to queue boosts for.
    /// @param _amts        uint128[] memory The amount of BGT to boost with.
    function queueBoosts(bytes[] calldata _pubkeys, uint128[] calldata _amts)
        external
        onlyKeeper
    {
        _validatorStorage().queueBoosts(
            address(_bgt), address(ibgt), _pubkeys, _amts
        );
        emit QueuedBoosts(msg.sender, _pubkeys, _amts);
    }

    /// @notice Removes `_amts` from previously queued boosts to `_validators`.
    /// @dev `_pubkeys` need not be in the current validator set in case just removed but need to cancel.
    /// @param _pubkeys     bytes[] memory The pubkeys of the validators to remove boosts for.
    /// @param _amts        uint128[] memory The amounts of BGT to remove from the queued boosts.
    function cancelBoosts(bytes[] calldata _pubkeys, uint128[] calldata _amts)
        external
        onlyKeeper
    {
        ValidatorManagerLib.cancelBoosts(address(_bgt), _pubkeys, _amts);
        emit CancelledBoosts(msg.sender, _pubkeys, _amts);
    }

    /// @notice Activates queued boosts for `_pubkeys`.
    /// @param _pubkeys   bytes[] memory The pubkeys of the validators to activate boosts for.
    function activateBoosts(bytes[] calldata _pubkeys) external {
        _validatorStorage().activateBoosts(address(_bgt), _pubkeys);
        emit ActivatedBoosts(msg.sender, _pubkeys);
    }

    /// @notice Queues a drop boost of the validators removing an amount of BGT for sender.
    /// @dev Reverts if `user` does not have enough boosted balance to cover amount.
    /// @param _pubkeys     bytes[] calldata The pubkeys of the validators to remove boost from.
    /// @param _amts Amounts of BGT to remove from the queued drop boosts.
    function queueDropBoosts(
        bytes[] calldata _pubkeys,
        uint128[] calldata _amts
    ) external onlyKeeper {
        ValidatorManagerLib.queueDropBoosts(address(_bgt), _pubkeys, _amts);
        emit QueueDropBoosts(msg.sender, _pubkeys, _amts);
    }

    /// @notice Cancels a queued drop boost of the validator removing an amount of BGT for sender.
    /// @param _pubkeys bytes[] calldata   The pubkeys of the validators to remove boost from.
    /// @param _amts    uint128[] calldata Amounts of BGT to remove from the queued drop boosts.
    function cancelDropBoosts(
        bytes[] calldata _pubkeys,
        uint128[] calldata _amts
    ) external onlyKeeper {
        _validatorStorage().cancelDropBoosts(address(_bgt), _pubkeys, _amts);
        emit CancelDropBoosts(msg.sender, _pubkeys, _amts);
    }

    /// @notice Drops an amount of BGT from an existing boost of validators by user.
    /// @param _pubkeys bytes[] memory The pubkeys of the validators to remove boost from.
    function dropBoosts(bytes[] calldata _pubkeys) external {
        ValidatorManagerLib.dropBoosts(address(_bgt), _pubkeys);
        emit DroppedBoosts(msg.sender, _pubkeys);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       HELPERS                                */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Gets the set of infrared validator pubkeys.
    /// @return validators Validator[] memory The set of infrared validators.
    function infraredValidators()
        public
        view
        virtual
        returns (ValidatorTypes.Validator[] memory validators)
    {
        return _validatorStorage().infraredValidators(address(distributor));
    }

    /// @notice Gets the number of infrared validators in validator set.
    /// @return num uint256 The number of infrared validators in validator set.
    function numInfraredValidators() external view returns (uint256) {
        return _validatorStorage().numInfraredValidators();
    }

    /// @notice Checks if a validator is an infrared validator.
    /// @param _pubkey    bytes      The pubkey of the validator to check.
    /// @return _isValidator bool       Whether the validator is an infrared validator.
    function isInfraredValidator(bytes calldata _pubkey)
        public
        view
        returns (bool)
    {
        return _validatorStorage().isValidator(_pubkey);
    }

    /// @notice Gets the BGT balance for this contract
    /// @return bgtBalance The BGT balance held by this address
    function getBGTBalance() public view returns (uint256) {
        return _bgt.balanceOf(address(this));
    }

    /// @notice Mapping of tokens that are whitelisted to be used as rewards or accepted as bribes
    /// @dev serves as central source of truth for whitelisted reward tokens for all Infrared contracts
    function whitelistedRewardTokens(address token)
        public
        view
        returns (bool)
    {
        return _vaultStorage().isWhitelisted(token);
    }

    /// @notice Mapping of staking token addresses to their corresponding InfraredVault
    /// @dev Each staking token can only have one vault
    function vaultRegistry(address _stakingToken)
        public
        view
        returns (IInfraredVault vault)
    {
        vault = _vaultStorage().vaultRegistry[_stakingToken];
    }

    /// @notice The rewards duration
    /// @dev Used as gloabl variabel to set the rewards duration for all new reward tokens on InfraredVaults
    /// @return duration uint256 reward duration period, in seconds
    function rewardsDuration() public view returns (uint256 duration) {
        return _vaultStorage().rewardsDuration;
    }

    /// @notice Protocol fee rates to charge for various harvest function distributions
    /// @param t The index of the fee rate
    /// @return uint256 The fee rate
    function fees(uint256 t) public view override returns (uint256) {
        return _rewardsStorage().fees[t];
    }

    /// @notice The unclaimed Infrared protocol fees of token accumulated by contract
    /// @param _token address The token address for the accumulated fees
    /// @return uint256 The amount of accumulated fees
    function protocolFeeAmounts(address _token)
        external
        view
        returns (uint256)
    {
        return _rewardsStorage().protocolFeeAmounts[_token];
    }

    receive() external payable {}
}
