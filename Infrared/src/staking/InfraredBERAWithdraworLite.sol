// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {Errors, Upgradeable} from "src/utils/Upgradeable.sol";
import {IInfraredBERA} from "src/interfaces/IInfraredBERA.sol";
import {IInfraredBERADepositor} from "src/interfaces/IInfraredBERADepositor.sol";
import {IInfraredBERAClaimor} from "src/interfaces/IInfraredBERAClaimor.sol";
import {IInfraredBERAWithdrawor} from "src/interfaces/IInfraredBERAWithdrawor.sol";
import {InfraredBERAConstants} from "./InfraredBERAConstants.sol";

/// @title InfraredBERAWithdraworLite
/// @notice This contract is only responsible for handling involuntary exits from the CL. It is a light version of the InfraredBERAWithdrawor contract.
/// @dev This contract should be upgraded once withdrawals are enabled by `https://github.com/berachain/beacon-kit`.
/// @dev expects compliance of https://github.com/ethereum/EIPs/blob/master/EIPS/eip-7002.md
contract InfraredBERAWithdraworLite is Upgradeable, IInfraredBERAWithdrawor {
    /// @notice The withdrawal request type, execution layer withdrawal.
    uint8 public constant WITHDRAW_REQUEST_TYPE = 0x01;

    /// @notice The address of the Withdraw Precompile settable in the next upgrade.
    address public WITHDRAW_PRECOMPILE; // @dev: EIP7002

    /// @notice The address of the `InfraredBERA.sol` contract.
    address public InfraredBERA;

    /// @notice The address of the `InfraredBERAClaimor.sol` contract.
    /// @dev This contract will be set in the next upgrade.
    address public claimor;

    /// @notice The request struct for withdrawal requests.
    /// @param receiver The address of the receiver of the withdrawn BERA funds.
    /// @param timestamp The block.timestamp at which the withdraw request was issued.
    /// @param fee The fee escrow for the withdraw precompile request.
    /// @param amountSubmit The amount of withdrawn BERA funds left to submit request to withdraw precompile.
    /// @param amountProcess The amount of withdrawn BERA funds left to process from funds received via withdraw request.
    struct Request {
        address receiver;
        uint96 timestamp;
        uint256 fee;
        uint256 amountSubmit;
        uint256 amountProcess;
    }

    /// @notice Outstanding requests for claims on previously burnt ibera
    /// The key = nonce associated with the claim
    mapping(uint256 => Request) public requests;

    /// @notice Amount of BERA internally set aside for withdraw precompile request fees
    uint256 public fees;

    /// @notice Amount of BERA internally rebalancing amongst Infrared validators
    uint256 public rebalancing;

    /// @notice The next nonce to issue withdraw request for
    uint256 public nonceRequest;

    /// @notice The next nonce to submit withdraw request for
    uint256 public nonceSubmit;

    /// @inheritdoc IInfraredBERAWithdrawor
    uint256 public nonceProcess;

    /// Reserve storage slots for future upgrades for safety
    uint256[40] private __gap;

    /// @notice Initialize the contract (replaces the constructor)
    /// @param _gov Address for admin / gov to upgrade
    /// @param _keeper Address for keeper
    /// @param ibera The initial InfraredBERA address
    function initialize(
        address _gov,
        address _keeper,
        address ibera
    ) public initializer {
        if (
            _gov == address(0) || _keeper == address(0) || ibera == address(0)
        ) {
            revert Errors.ZeroAddress();
        }
        __Upgradeable_init();
        InfraredBERA = ibera;

        nonceRequest = 1;
        nonceSubmit = 1;
        nonceProcess = 1;

        _grantRole(DEFAULT_ADMIN_ROLE, _gov);
        _grantRole(GOVERNANCE_ROLE, _gov);
        _grantRole(KEEPER_ROLE, _keeper);
    }

    /// @notice Checks whether enough time has passed beyond min delay
    /// @param then The block timestamp in past
    /// @param current The current block timestamp now
    /// @return has Whether time between then and now exceeds forced min delay
    function _enoughtime(
        uint96 then,
        uint96 current
    ) private pure returns (bool has) {
        unchecked {
            has = (current - then) >= InfraredBERAConstants.FORCED_MIN_DELAY;
        }
    }

    /// @notice Amount of BERA internally set aside to process withdraw compile requests from funds received on successful requests
    function reserves() public view returns (uint256) {
        return address(this).balance - fees;
    }

    /// @notice Queues a withdraw from InfraredBERA for chain withdraw precompile escrowing minimum fees for request to withdraw precompile
    /// @dev not used until next upgrade.
    function queue(address, uint256) external payable returns (uint256) {
        revert Errors.WithdrawalsNotEnabled();
    }

    /// @notice Executes a withdraw request to withdraw precompile
    /// @dev not used until next upgrade.
    function execute(bytes calldata, uint256) external payable {
        revert Errors.WithdrawalsNotEnabled();
    }

    /// @notice Processes the funds received from withdraw precompile to next-to-process request receiver
    /// @dev Reverts if balance has not increased by full amount of request for next-to-process request nonce
    /// @dev not used until next upgrade.
    function process() external pure {
        revert Errors.WithdrawalsNotEnabled();
    }

    /// @notice Handles Forced withdrawals from the CL.
    /// @param pubkey The pubkey of the validator that has been forced to exit.
    /// @dev RESTRICTED USAGE: This function should ONLY be called when:
    /// - A validator has been forced to exit from the CL.
    /// @dev The funds will enter the IBERA system as a deposit via the InfraredBERADepositor.
    function sweep(bytes calldata pubkey) external onlyGovernor {
        // only callable when withdrawals are not enabled
        if (IInfraredBERA(InfraredBERA).withdrawalsEnabled()) {
            revert Errors.Unauthorized(msg.sender);
        }
        // Check if validator has already exited - do this before checking stake
        if (IInfraredBERA(InfraredBERA).hasExited(pubkey)) {
            revert Errors.ValidatorForceExited();
        }
        // forced exit always withdraw entire stake of validator
        uint256 amount = IInfraredBERA(InfraredBERA).stakes(pubkey);

        // revert if insufficient balance
        if (amount > address(this).balance) revert Errors.InvalidAmount();

        // register new validator delta
        IInfraredBERA(InfraredBERA).register(pubkey, -int256(amount));

        // re-stake amount back to ibera depositor
        IInfraredBERADepositor(IInfraredBERA(InfraredBERA).depositor()).queue{
            value: amount
        }();

        emit Sweep(InfraredBERA, amount);
    }

    /// @notice Handles excess stake that was refunded from a validator due to non-IBERA deposits exceeding MAX_EFFECTIVE_BALANCE
    /// @dev RESTRICTED USAGE: This function should ONLY be called when:
    /// - A non-IBERA entity deposits to our validator, pushing total stake above MAX_EFFECTIVE_BALANCE
    /// - The excess stake is refunded by the CL to this contract
    /// @dev The funds will enter the IBERA system as yield via the FeeReceivor
    /// @dev This should NEVER be used for:
    /// - Validators exited due to falling out of the validator set
    /// @param amount The amount of excess stake to sweep
    /// @custom:access Only callable by governance
    function sweepUnaccountedForFunds(uint256 amount) external onlyGovernor {
        // only callable when withdrawals are not enabled
        if (IInfraredBERA(InfraredBERA).withdrawalsEnabled()) {
            revert Errors.Unauthorized(msg.sender);
        }

        // revert if amount exceeds balance
        if (amount > address(this).balance) {
            revert Errors.InvalidAmount();
        }

        address receivor = IInfraredBERA(InfraredBERA).receivor();
        // transfer amount to ibera receivor
        SafeTransferLib.safeTransferETH(receivor, amount);

        emit Sweep(receivor, amount);
    }

    receive() external payable {}
}
