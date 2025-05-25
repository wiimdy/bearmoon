// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {IBeaconDeposit} from "@berachain/pol/interfaces/IBeaconDeposit.sol";
import {Errors, Upgradeable} from "src/utils/Upgradeable.sol";
import {IInfraredBERA} from "src/interfaces/IInfraredBERA.sol";
import {IInfraredBERADepositor} from "src/interfaces/IInfraredBERADepositor.sol";
import {InfraredBERAConstants} from "./InfraredBERAConstants.sol";

/// @title InfraredBERADepositor
/// @notice Depositor to deposit BERA to CL for Infrared liquid staking token
contract InfraredBERADepositor is Upgradeable {
    /// @notice https://eth2book.info/capella/part2/deposits-withdrawals/withdrawal-processing/
    uint8 public constant ETH1_ADDRESS_WITHDRAWAL_PREFIX = 0x01;
    /// @notice The Deposit Contract Address for Berachain
    address public DEPOSIT_CONTRACT;
    /// @notice the main InfraredBERA contract address
    address public InfraredBERA;
    /// @notice the queued amount of BERA to be deposited
    uint256 public reserves;

    event Queue(uint256 amount);
    event Execute(bytes pubkey, uint256 amount);

    /// Reserve storage slots for future upgrades for safety
    uint256[40] private __gap;

    /// @notice Initialize the contract (replaces the constructor)
    /// @param _gov Address for admin / gov to upgrade
    /// @param _keeper Address for keeper
    /// @param ibera The initial IBERA address
    /// @param _depositContract The ETH2 (Berachain) Deposit Contract Address
    function initialize(
        address _gov,
        address _keeper,
        address ibera,
        address _depositContract
    ) public initializer {
        if (
            _gov == address(0) || _keeper == address(0) || ibera == address(0)
                || _depositContract == address(0)
        ) revert Errors.ZeroAddress();
        __Upgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _gov);
        _grantRole(GOVERNANCE_ROLE, _gov);
        _grantRole(KEEPER_ROLE, _keeper);

        InfraredBERA = ibera;
        DEPOSIT_CONTRACT = _depositContract;
    }

    /// @notice Queues a deposit by sending BERA to this contract and storing the amount
    /// in the pending deposits acculimator
    function queue() external payable {
        /// @dev can only be called by InfraredBERA for adding to the reserves and by withdrawor for rebalancing
        /// when validators get kicked out of the set, TODO: link the set kickout code.
        if (
            msg.sender != InfraredBERA
                && msg.sender != IInfraredBERA(InfraredBERA).withdrawor()
        ) {
            revert Errors.Unauthorized(msg.sender);
        }

        // @dev accumulate the amount of BERA to be deposited with `execute`
        reserves += msg.value;

        emit Queue(msg.value);
    }

    /// @notice Executes a deposit to the deposit contract for the specified pubkey and amount.
    /// @param pubkey The pubkey of the validator to deposit for
    /// @param amount The amount of BERA to deposit
    /// @dev Only callable by the keeper
    /// @dev Only callable if the deposits are enabled
    function execute(bytes calldata pubkey, uint256 amount)
        external
        onlyKeeper
    {
        // check if pubkey is a valid validator being tracked by InfraredBERA
        if (!IInfraredBERA(InfraredBERA).validator(pubkey)) {
            revert Errors.InvalidValidator();
        }

        // The amount must be a multiple of 1 gwei as per the deposit contract, cannot be more eth than we have, and must be at least the minimum deposit amount.
        if (amount == 0 || (amount % 1 gwei) != 0 || amount > reserves) {
            revert Errors.InvalidAmount();
        }

        // cache the withdrawor address since we will be using it multiple times.
        address withdrawor = IInfraredBERA(InfraredBERA).withdrawor();

        // Check if there is any forced exits on the withdrawor contract.
        // @notice if the balance of the withdrawor is more than INITIAL_DEPOSIT, we can assume that there is an unprocessed forced exit and
        // we should sweep it before we can deposit the BERA. This stops the protocol from staking into exited validators.
        if (withdrawor.balance >= InfraredBERAConstants.INITIAL_DEPOSIT) {
            revert Errors.HandleForceExitsBeforeDeposits();
        }

        // The validator balance + amount must not surpase MaxEffectiveBalance of 10 million BERA.
        if (
            IInfraredBERA(InfraredBERA).stakes(pubkey) + amount
                > InfraredBERAConstants.MAX_EFFECTIVE_BALANCE
        ) {
            revert Errors.ExceedsMaxEffectiveBalance();
        }

        // @dev determin what to set the operator, if the operator is not set we know this is the first deposit and we should set it to infrared.
        // if not we know this is the second or subsequent deposit (subject to internal test below) and we should set the operator to address(0).
        address operatorBeacon =
            IBeaconDeposit(DEPOSIT_CONTRACT).getOperator(pubkey);
        address operator = IInfraredBERA(InfraredBERA).infrared();
        // check if first beacon deposit by checking if the registered operator is set
        if (operatorBeacon != address(0)) {
            // Not first deposit. Ensure the correct operator is set for subsequent deposits
            if (operatorBeacon != operator) {
                revert Errors.UnauthorizedOperator();
            }
            // check whether first deposit via internal logic to protect against bypass beacon deposit attack
            if (!IInfraredBERA(InfraredBERA).staked(pubkey)) {
                revert Errors.OperatorAlreadySet();
            }
            // A nuance of berachain is that subsequent deposits set operator to address(0)
            operator = address(0);
        } else {
            /// First deposit, overwrite the amount to the initial deposit amount.
            amount = InfraredBERAConstants.INITIAL_DEPOSIT;
        }

        // @notice load the signature for the pubkey. This is only used for the first deposit but can be re-used safley since this is checked only on the first deposit.
        // https://github.com/berachain/beacon-kit/blob/395085d18667e48395503a20cd1b367309fe3d11/state-transition/core/state_processor_staking.go#L101
        bytes memory signature = IInfraredBERA(InfraredBERA).signatures(pubkey);
        if (signature.length == 0) {
            revert Errors.InvalidSignature();
        }

        // @notice ethereum/consensus-specs/blob/dev/specs/phase0/validator.md#eth1_address_withdrawal_prefix
        // @dev similar to the signiture above, this is only used for the first deposit but can be re-used safley since this is checked only on the first deposit.
        bytes memory credentials = abi.encodePacked(
            ETH1_ADDRESS_WITHDRAWAL_PREFIX,
            uint88(0), // 11 zero bytes
            withdrawor
        );

        /// @dev reduce the reserves by the amount deposited.
        reserves -= amount;

        /// @dev register the increase in stake to the validator.
        IInfraredBERA(InfraredBERA).register(pubkey, int256(amount));

        // @dev deposit the BERA to the deposit contract.
        // @dev the amount being divided by 1 gwei is checked inside.
        IBeaconDeposit(DEPOSIT_CONTRACT).deposit{value: amount}(
            pubkey, credentials, signature, operator
        );

        emit Execute(pubkey, amount);
    }
}
