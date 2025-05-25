// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20Upgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {Errors, Upgradeable} from "src/utils/Upgradeable.sol";
import {IInfrared} from "src/interfaces/IInfrared.sol";
import {IInfraredBERADepositor} from "src/interfaces/IInfraredBERADepositor.sol";
import {IInfraredBERAWithdrawor} from
    "src/interfaces/IInfraredBERAWithdrawor.sol";
import {IInfraredBERAFeeReceivor} from
    "src/interfaces/IInfraredBERAFeeReceivor.sol";
import {IInfraredBERA} from "src/interfaces/IInfraredBERA.sol";
import {InfraredBERAConstants} from "./InfraredBERAConstants.sol";
import {InfraredBERADepositor} from "./InfraredBERADepositor.sol";
import {InfraredBERAWithdrawor} from "./InfraredBERAWithdrawor.sol";
import {InfraredBERAClaimor} from "./InfraredBERAClaimor.sol";
import {InfraredBERAFeeReceivor} from "./InfraredBERAFeeReceivor.sol";

/*

    Made with Love by the Bears at Infrared Finance, so that all Bears may
         get the best yields on their BERA. For the Bears, by the Bears. <3


⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⡤⢤⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⣠⠴⠶⢤⡞⢡⡚⣦⠹⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⢰⣃⠀⠀⠈⠁⠀⠉⠁⢺⠇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠈⢯⣄⡀⠀⠀⠀⠀⢀⡞⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠉⠓⠦⠤⣤⣤⠞⠀⠀⢀⣴⠒⢦⣴⣖⢲⡀⠀⠀⠀⠀⣠⣴⠾⠿⠷⣶⣄⠀⣀⣠⣤⣴⣶⣶⣶⣦⣤⣤⣄⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⡇⠀⠈⠳⠼⣰⠃⠀⠀⠀⣼⡟⠁⠀⣀⣀⠀⠙⢿⠟⠋⠉⠀⠀⠀⠀⠀⠀⠉⠉⠛⠿⣶⣤⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠓⣦⣄⣠⣶⣿⣛⠛⠿⣾⣿⠀⢠⣾⠋⣹⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠻⣷⣄⡀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣤⣴⡶⠿⠟⠛⠛⠛⠛⠛⠛⠿⢷⣾⣿⣷⡀⠻⠾⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠹⣷⣄⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣤⣾⠟⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⠻⢿⣦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢿⣿⢷⣦⡀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⣴⡿⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⠿⣶⣶⣤⡀⠀⠀⠀⠀⢀⣤⡶⣦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⣿⣆⠙⣿⡄
⠀⠀⠀⠀⠀⠀⠀⣠⣾⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠹⣷⡀⠀⢷⡄⠸⣯⣀⣼⡷⠒⢉⣉⡙⢢⡀⠀⠀⠀⠀⠀⢸⣿⡀⢸⣿
⠀⠀⠀⠀⠀⠀⢠⣿⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣤⢄⡾⠐⠒⢆⠀⠀⣿⡇⠀⢸⡇⠀⠈⢉⡟⠀⠀⠀⢹⡟⠃⢧⣴⠶⢶⡄⠀⠀⣿⣇⣼⡟
⠀⠀⣠⣴⡶⠶⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣰⡿⢃⡾⠁⠀⠀⢸⠃⠀⣿⡇⠀⣸⡇⠀⠀⣼⠀⠀⠀⢠⡾⠁⠀⢸⣿⣤⣼⠗⠀⠀⣿⣿⠛⠀
⢀⣾⠟⠁⠀⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⠀⠀⢿⠇⡼⠁⠀⠀⢀⡜⠀⢀⣿⠃⠀⠉⠀⠀⠀⢧⠀⠠⡶⣿⠁⠀⢠⠇⠀⠉⠁⠀⠀⠀⣿⡏⠀⠀
⢸⣿⠀⢠⡞⠉⢹⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠰⠾⢿⣠⣷⡄⠀⠁⠳⠤⠖⠋⠀⠀⣸⡟⠀⠀⠀⠀⠀⠀⠘⣄⡀⠀⠛⢀⡴⠋⠀⠀⠀⠀⠀⠀⠀⣿⡇⠀⠀
⢸⣿⡀⠈⠻⣦⣼⠀⠀⠀⠀⠀⠀⠀⢀⣤⣴⡶⠶⠆⠀⢠⣤⡾⠋⠀⣿⠀⠀⠀⠀⠀⠀⠀⢠⣿⠁⠀⠀⠀⠀⠀⠀⠀⠀⠉⠉⠉⠉⠀⠀⠀⠀⠀⠀⠀⠀⠸⣿⡅⠀⠀
⠀⠻⣿⣦⣄⣀⣰⡀⠀⠀⠀⠀⠀⠀⣸⠯⢄⡀⠀⠀⠀⢸⣇⠀⠀⠀⣸⡇⠀⠀⠀⠀⠀⢠⣿⠏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣰⣿⠃⠀⠀
⠀⠀⠀⠉⠙⠛⣿⣇⠀⠀⠀⠀⢀⠎⠀⠀⠀⠈⣆⠀⠀⠀⠻⣦⣄⣴⠟⠀⠀⠀⠀⠀⣰⣿⠏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⡄⠀⠀⠀⠀⠀⠀⠀⠀⣠⣾⡿⠋⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠸⣿⣆⠀⠀⠀⠘⡄⠀⠀⠀⢀⡞⠀⠀⠀⠀⠀⠉⠀⠀⢀⣀⣤⣴⣾⣿⣧⣄⠀⢀⣠⣴⣶⣶⣶⣤⡶⠋⠉⠀⠀⢀⣀⣀⣠⣤⣶⣾⠿⠋⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠘⢿⣦⡀⠀⠀⠈⠒⠤⠔⠋⠀⠀⠀⠀⠀⠀⣠⣴⡾⠟⠋⠉⠀⠀⠀⠛⣹⣷⣿⠟⠒⠀⠀⠀⠉⢻⣷⣶⣾⠿⠿⠿⠛⠛⠋⠉⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠛⢿⣦⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀⣠⠾⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⣹⣿⣿⣄⣀⠀⠀⠀⠀⢀⣿⠇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠛⠿⣷⣶⣶⣤⣤⣶⡦⠀⠁⠀⠀⠀⠀⠀⣀⣀⣀⣤⣴⡾⠟⠁⠙⠿⣷⣶⣤⣴⣾⠿⠛⣷⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⣽⡿⠁⠀⣤⣤⣶⡶⠾⠿⠟⢻⠛⠉⠁⠀⠀⠀⠀⠀⠀⠈⠉⠙⣿⡆⠀⠈⢿⣆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣾⠟⠁⠀⢸⣟⡁⠀⠀⠀⠀⣰⡿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⡇⠀⠀⠈⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣶⣿⡏⠀⠀⠀⠸⣿⣤⣶⣀⣤⣾⠟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣿⣧⣄⣀⣤⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣼⣇⣿⡇⠀⠀⠀⠀⣾⣿⠛⠋⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⣿⣍⠛⠛⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠛⣿⡇⠀⠀⠀⠀⠉⣿⣆⠀⠀⠀⠀⠀⠀⠀⢴⣶⣶⠆⠀⠀⠀⠀⠀⠀⣈⣿⣧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣴⡿⠀⠀⠀⠀⠀⠀⣸⣿⡄⠀⠀⠀⠀⠀⠀⢸⣟⢿⣿⣦⠀⠀⢠⣄⣠⣿⡿⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣥⣤⣶⣀⣠⣶⣴⡿⢻⣷⣄⣴⣆⣀⣆⣠⣿⡇⠈⠻⣿⣵⣶⡿⠿⠛⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
*/

/// @title InfraredBERA
/// @notice Infrared BERA is a liquid staking token for Berachain
/// @dev This is the main "Front-End" contract for the whole BERA staking system.
contract InfraredBERA is ERC20Upgradeable, Upgradeable, IInfraredBERA {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       STORAGE                              */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Withdrawals are not enabled by default, not supported by https://github.com/berachain/beacon-kit yet.
    bool public withdrawalsEnabled;

    /// @notice Whether the contract has been initialized
    bool private _initialized;

    /// @notice The fee divisor for protocol + operator + voter fees. 1/N, where N is the divisor. example 100 = 1/100 = 1%
    uint16 public feeDivisorShareholders;

    /// @notice The `Infrared.sol` smart contract.
    address public infrared;

    /// @notice The `InfraredBERADepositor.sol` smart contract.
    address public depositor;

    /// @notice The `InfraredBERAWithdrawor.sol` smart contract.
    address public withdrawor;

    /// @notice The `InfraredBERAFeeReceivor.sol` smart contract.
    address public receivor;

    /// @notice The total amount of `BERA` deposited by the system.
    uint256 public deposits;

    /// @notice Mapping of validator pubkeyHash to their stake in `BERA`.
    mapping(bytes32 pubkeyHash => uint256 stake) internal _stakes;

    /// @notice Mapping of validator pubkeyHash to whether they have recieved stake from this contract.
    mapping(bytes32 pubkeyHash => bool isStaked) internal _staked;

    /// @notice Mapping of validator pubkeyHash to whether they have exited from this contract. (voluntarily or force).
    mapping(bytes32 pubkeyHash => bool hasExited) internal _exited;

    /// @notice Mapping of validator pubkeyHash to their deposit signature. All validators MUST have their signiture amounts set to `INITIAL_DEPOSIT` to be valid.
    mapping(bytes32 pubkeyHash => bytes) internal _signatures;

    /// @dev Reserve storage slots for future upgrades for safety
    uint256[40] private __gap;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       INITIALIZATION                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Initiializer for `InfraredBERA`.
    /// @param _gov The address of the governance contract.
    /// @param _keeper The address of the keeper contract.
    /// @param _infrared The address of the `Infrared.sol` contract.
    /// @param _depositor The address of the `InfraredBERADepositor.sol` contract.
    /// @param _withdrawor The address of the `InfraredBERAWithdrawor.sol` contract.
    /// @param _receivor The address of the `InfraredBERAFeeReceivor.sol` contract.
    function initialize(
        address _gov,
        address _keeper,
        address _infrared,
        address _depositor,
        address _withdrawor,
        address _receivor
    ) external payable initializer {
        if (
            _gov == address(0) || _infrared == address(0)
                || _depositor == address(0) || _withdrawor == address(0)
                || _receivor == address(0)
        ) revert Errors.ZeroAddress();
        __ERC20_init("Infrared BERA", "iBERA");
        __Upgradeable_init();

        infrared = _infrared;
        depositor = _depositor;
        withdrawor = _withdrawor;
        receivor = _receivor;

        _grantRole(DEFAULT_ADMIN_ROLE, _gov);
        _grantRole(GOVERNANCE_ROLE, _gov);
        _grantRole(KEEPER_ROLE, _keeper);

        // mint minimum amount to mitigate inflation attack with shares
        _initialized = true;
        mint(address(this));
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       AUTH                                 */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Checks if account has the governance role.
    /// @param account The address to check.
    /// @return True if the account has the governance role.
    function governor(address account) public view returns (bool) {
        return hasRole(GOVERNANCE_ROLE, account);
    }

    /// @notice Checks if account has the keeper role.
    /// @param account The address to check.
    /// @return True if the account has the keeper role.
    function keeper(address account) public view returns (bool) {
        return hasRole(KEEPER_ROLE, account);
    }

    /// @notice Checks if a given pubkey is a validator in the `Infrared` contract.
    /// @param pubkey The pubkey to check.
    /// @return True if the pubkey is a validator.
    function validator(bytes calldata pubkey) external view returns (bool) {
        return IInfrared(infrared).isInfraredValidator(pubkey);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       ADMIN                                */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Allows withdrawals to be enabled or disabled.
    /// @param flag The flag to set for withdrawals.
    /// @dev Only callable by the governor.
    function setWithdrawalsEnabled(bool flag) external onlyGovernor {
        withdrawalsEnabled = flag;
        emit WithdrawalFlagSet(flag);
    }

    /// @notice Sets the fee shareholders taken on yield from EL coinbase priority fees + MEV
    /// @param to The new fee shareholders represented as an integer denominator (1/x)%
    function setFeeDivisorShareholders(uint16 to) external onlyGovernor {
        compound();
        emit SetFeeShareholders(feeDivisorShareholders, to);
        feeDivisorShareholders = to;
    }

    /// @notice Sets the deposit signature for a given pubkey. Ensure that the pubkey has signed the correct deposit amount of `INITIAL_DEPOSIT`.
    /// @param pubkey The pubkey to set the deposit signature for.
    /// @param signature The signature to set for the pubkey.
    /// @dev Only callable by the governor.
    function setDepositSignature(
        bytes calldata pubkey,
        bytes calldata signature
    ) external onlyGovernor {
        if (signature.length != 96) revert Errors.InvalidSignature();
        emit SetDepositSignature(
            pubkey, _signatures[keccak256(pubkey)], signature
        );
        _signatures[keccak256(pubkey)] = signature;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       MINT/BURN                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Mints `ibera` to the `receiver` in exchange for `bera`.
    /// @dev takes in msg.value as amount to mint `ibera` with.
    /// @param receiver The address to mint `ibera` to.
    /// @return shares The amount of `ibera` minted.
    function mint(address receiver) public payable returns (uint256 shares) {
        // @dev make sure to compound yield earned from EL rewards first to avoid accounting errors.
        compound();

        // cache prior since updated in _deposit call
        uint256 d = deposits;
        uint256 ts = totalSupply();

        // deposit bera request
        uint256 amount = msg.value;
        _deposit(amount);

        // mint shares to receiver of ibera, if there are no deposits or total supply, mint full amount
        // else mint amount based on total supply and deposits: (totalSupply * amount) / deposits
        shares = (d != 0 && ts != 0) ? (ts * amount) / d : amount;
        if (shares == 0) revert Errors.InvalidShares();
        _mint(receiver, shares);

        emit Mint(receiver, amount, shares);
    }

    /// @notice Burns `ibera` from the `msg.sender` and sets a receiver to get the `BERA` in exchange for `iBERA`.
    /// @param receiver The address to send the `BERA` to.
    /// @param shares The amount of `ibera` to burn.
    /// @return nonce The nonce of the withdrawal. Queue based system for withdrawals.
    /// @return amount The amount of `BERA` withdrawn for the exchange of `iBERA`.
    function burn(address receiver, uint256 shares)
        external
        payable
        returns (uint256 nonce, uint256 amount)
    {
        if (!withdrawalsEnabled) revert Errors.WithdrawalsNotEnabled();
        // @dev make sure to compound yield earned from EL rewards first to avoid accounting errors.
        compound();

        uint256 ts = totalSupply();
        if (shares == 0 || ts == 0) revert Errors.InvalidShares();

        amount = (deposits * shares) / ts;
        if (amount == 0) revert Errors.InvalidAmount();

        // burn shares from sender of ibera
        _burn(msg.sender, shares);

        // withdraw bera request
        // @dev pay withdraw precompile fee via funds sent in on payable call
        uint256 fee = msg.value;
        if (fee < InfraredBERAConstants.MINIMUM_WITHDRAW_FEE) {
            revert Errors.InvalidFee();
        }
        nonce = _withdraw(receiver, amount, fee);

        emit Burn(receiver, nonce, amount, shares, fee);
    }

    /// @notice Internal function to update top level accounting and minimum deposit.
    /// @param amount The amount of `BERA` to deposit.
    function _deposit(uint256 amount) internal {
        // @dev check at internal deposit level to prevent donations prior
        if (!_initialized) revert Errors.NotInitialized();

        // update tracked deposits with validators
        deposits += amount;
        // escrow funds to depositor contract to eventually forward to precompile
        IInfraredBERADepositor(depositor).queue{value: amount}();
    }

    /// @notice Internal function to update top level accounting.
    /// @param receiver The address to withdraw `BERA` to.
    /// @param amount The amount of `BERA` to withdraw.
    /// @param fee The fee to pay for the withdrawal.
    function _withdraw(address receiver, uint256 amount, uint256 fee)
        private
        returns (uint256 nonce)
    {
        if (!_initialized) revert Errors.NotInitialized();

        // request to withdrawor contract to eventually forward to precompile
        nonce = IInfraredBERAWithdrawor(withdrawor).queue{value: fee}(
            receiver, amount
        );
        // update tracked deposits with validators *after* queue given used by withdrawor via confirmed
        deposits -= amount;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       ACCOUNTING                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Previews the amount of InfraredBERA shares that would be minted for a given BERA amount
    /// @param beraAmount The amount of BERA to simulate depositing
    /// @return shares The amount of InfraredBERA shares that would be minted, returns 0 if the operation would fail
    function previewMint(uint256 beraAmount)
        public
        view
        returns (uint256 shares)
    {
        if (!_initialized) {
            return 0;
        }

        // First simulate compound effects like in actual mint
        (uint256 compoundAmount,) =
            IInfraredBERAFeeReceivor(receivor).distribution();

        // Calculate shares considering both:
        // 1. The compound effect (compoundAmount - fee)
        // 2. The new deposit (beraAmount - fee)
        uint256 ts = totalSupply();
        uint256 depositsAfterCompound = deposits;

        // First simulate compound effect on deposits
        if (compoundAmount > 0) {
            depositsAfterCompound += (compoundAmount);
        }

        // Then calculate shares based on user deposit
        uint256 amount = beraAmount;
        if (depositsAfterCompound == 0 || ts == 0) {
            shares = amount;
        } else {
            shares = (ts * amount) / depositsAfterCompound;
        }
    }

    /// @notice Previews the amount of BERA that would be received for burning InfraredBERA shares
    /// @param shareAmount The amount of InfraredBERA shares to simulate burning
    /// @return beraAmount The amount of BERA that would be received, returns 0 if the operation would fail
    /// @return fee The fee that would be charged for the burn operation
    function previewBurn(uint256 shareAmount)
        public
        view
        returns (uint256 beraAmount, uint256 fee)
    {
        if (!_initialized || shareAmount == 0) {
            return (0, 0);
        }

        // First simulate compound effects like in actual burn
        (uint256 compoundAmount,) =
            IInfraredBERAFeeReceivor(receivor).distribution();

        uint256 ts = totalSupply();
        if (ts == 0) {
            return (0, InfraredBERAConstants.MINIMUM_WITHDRAW_FEE);
        }

        // Calculate amount considering compound effect
        uint256 depositsAfterCompound = deposits;

        if (compoundAmount > 0) {
            depositsAfterCompound += (compoundAmount);
        }

        beraAmount = (depositsAfterCompound * shareAmount) / ts;
        fee = InfraredBERAConstants.MINIMUM_WITHDRAW_FEE;

        if (beraAmount == 0) {
            return (0, fee);
        }
    }

    /// @notice Returns the amount of BERA staked in validator with given pubkey
    /// @return The amount of BERA staked in validator
    function stakes(bytes calldata pubkey) external view returns (uint256) {
        return _stakes[keccak256(pubkey)];
    }

    /// @notice Returns whether initial deposit has been staked to validator with given pubkey
    /// @return Whethere initial deposit has been staked to validator
    function staked(bytes calldata pubkey) external view returns (bool) {
        return _staked[keccak256(pubkey)];
    }

    /// @notice Pending deposits yet to be forwarded to CL
    /// @return The amount of BERA yet to be deposited to CL
    function pending() public view returns (uint256) {
        return (
            IInfraredBERADepositor(depositor).reserves()
                + IInfraredBERAWithdrawor(withdrawor).rebalancing()
        );
    }

    /// @notice Confirmed deposits sent to CL, total - future deposits
    /// @return The amount of BERA confirmed to be deposited to CL
    function confirmed() external view returns (uint256) {
        uint256 _pending = pending();
        // If pending is greater than deposits, return 0 instead of underflowing
        return _pending > deposits ? 0 : deposits - _pending;
    }

    /// @inheritdoc IInfraredBERA
    function compound() public {
        IInfraredBERAFeeReceivor(receivor).sweep();
    }

    /// @notice Compounds accumulated EL yield in fee receivor into deposits
    /// @dev Called internally at bof whenever InfraredBERA minted or burned
    /// @dev Only sweeps if amount transferred from fee receivor would exceed min deposit thresholds
    function sweep() external payable {
        if (msg.sender != receivor) {
            revert Errors.Unauthorized(msg.sender);
        }
        _deposit(msg.value);
        emit Sweep(msg.value);
    }

    /// @notice Collects yield from fee receivor and mints ibera shares to Infrared
    /// @dev Called in `RewardsLib::harvestOperatorRewards()` in `Infrared.sol`
    /// @dev Only Infrared can call this function
    /// @return sharesMinted The amount of ibera shares
    function collect() external returns (uint256 sharesMinted) {
        if (msg.sender != address(infrared)) {
            revert Errors.Unauthorized(msg.sender);
        }
        sharesMinted = IInfraredBERAFeeReceivor(receivor).collect();
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       VALIDATORS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Updates the accounted for stake of a validator pubkey.
    /// @notice This does NOT mean its the balance on the CL, edge case is if another user has staked to the pubkey.
    /// @param pubkey The pubkey of the validator.
    /// @param delta The change in stake.
    function register(bytes calldata pubkey, int256 delta) external {
        if (msg.sender != depositor && msg.sender != withdrawor) {
            revert Errors.Unauthorized(msg.sender);
        }
        if (_exited[keccak256(pubkey)]) {
            revert Errors.ValidatorForceExited();
        }
        // update validator pubkey stake for delta
        uint256 stake = _stakes[keccak256(pubkey)];
        if (delta > 0) stake += uint256(delta);
        else stake -= uint256(-delta);
        _stakes[keccak256(pubkey)] = stake;
        // update whether have staked to validator before
        if (delta > 0 && !_staked[keccak256(pubkey)]) {
            _staked[keccak256(pubkey)] = true;
        }
        // only 0 if validator was force exited
        if (stake == 0) {
            _staked[keccak256(pubkey)] = false;
            _exited[keccak256(pubkey)] = true;
        }

        emit Register(pubkey, delta, stake);
    }

    /// @notice Returns whether a validator pubkey has exited.
    function hasExited(bytes calldata pubkey) external view returns (bool) {
        return _exited[keccak256(pubkey)];
    }

    /// @notice Returns the deposit signature to use for given pubkey
    /// @return The deposit signature for pubkey
    function signatures(bytes calldata pubkey)
        external
        view
        returns (bytes memory)
    {
        return _signatures[keccak256(pubkey)];
    }
}
