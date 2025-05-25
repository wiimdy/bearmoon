// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {Errors, Upgradeable} from "src/utils/Upgradeable.sol";
import {IInfraredBERA} from "src/interfaces/IInfraredBERA.sol";
import {IInfraredBERADepositor} from "src/interfaces/IInfraredBERADepositor.sol";
import {IInfraredBERAClaimor} from "src/interfaces/IInfraredBERAClaimor.sol";
import {IInfraredBERAWithdrawor} from
    "src/interfaces/IInfraredBERAWithdrawor.sol";
import {InfraredBERAConstants} from "./InfraredBERAConstants.sol";

/// @title InfraredBERAWithdrawor
/// @notice Withdrawor to withdraw BERA from CL for Infrared liquid staking token
/// @dev Assumes ETH returned via withdraw precompile credited to contract so receive unnecessary
contract InfraredBERAWithdrawor is Upgradeable, IInfraredBERAWithdrawor {
    uint8 public constant WITHDRAW_REQUEST_TYPE = 0x01;
    address public WITHDRAW_PRECOMPILE; // @dev: EIP7002

    /// @inheritdoc IInfraredBERAWithdrawor
    address public InfraredBERA;

    address public claimor;

    struct Request {
        /// receiver of withdrawn bera funds
        address receiver;
        /// block.timestamp at which withdraw request issued
        uint96 timestamp;
        /// fee escrow for withdraw precompile request
        uint256 fee;
        /// amount of withdrawn bera funds left to submit request to withdraw precompile
        uint256 amountSubmit;
        /// amount of withdrawn bera funds left to process from funds received via withdraw request
        uint256 amountProcess;
    }

    /// @inheritdoc IInfraredBERAWithdrawor
    mapping(uint256 => Request) public requests;

    /// @inheritdoc IInfraredBERAWithdrawor
    uint256 public fees;

    /// @inheritdoc IInfraredBERAWithdrawor
    uint256 public rebalancing;

    /// @inheritdoc IInfraredBERAWithdrawor
    uint256 public nonceRequest;
    /// @inheritdoc IInfraredBERAWithdrawor
    uint256 public nonceSubmit;
    /// @inheritdoc IInfraredBERAWithdrawor
    uint256 public nonceProcess;

    /// Reserve storage slots for future upgrades for safety
    uint256[40] private __gap;

    function initializeV2(address _claimor, address _withdraw_precompile)
        external
        onlyGovernor
    {
        if (_claimor == address(0) || _withdraw_precompile == address(0)) {
            revert Errors.ZeroAddress();
        }
        WITHDRAW_PRECOMPILE = _withdraw_precompile;
        claimor = _claimor;
    }

    /// @notice Checks whether enough time has passed beyond min delay
    /// @param then The block timestamp in past
    /// @param current The current block timestamp now
    /// @return has Whether time between then and now exceeds forced min delay
    function _enoughtime(uint96 then, uint96 current)
        private
        pure
        returns (bool has)
    {
        unchecked {
            has = (current - then) >= InfraredBERAConstants.FORCED_MIN_DELAY;
        }
    }

    /// @inheritdoc IInfraredBERAWithdrawor
    function reserves() public view returns (uint256) {
        return address(this).balance - fees;
    }

    /// @inheritdoc IInfraredBERAWithdrawor
    function queue(address receiver, uint256 amount)
        external
        payable
        returns (uint256 nonce)
    {
        bool kpr = IInfraredBERA(InfraredBERA).keeper(msg.sender);
        address depositor = IInfraredBERA(InfraredBERA).depositor();
        // @dev rebalances can be queued by keeper but receiver must be depositor and amount must exceed deposit fee
        if (msg.sender != InfraredBERA && !kpr) {
            revert Errors.Unauthorized(msg.sender);
        }
        if ((kpr && receiver != depositor) || (!kpr && receiver == depositor)) {
            revert Errors.InvalidReceiver();
        }
        if (
            (receiver != depositor && amount == 0)
                || amount > IInfraredBERA(InfraredBERA).confirmed()
        ) {
            revert Errors.InvalidAmount();
        }

        if (msg.value < InfraredBERAConstants.MINIMUM_WITHDRAW_FEE) {
            revert Errors.InvalidFee();
        }
        fees += msg.value;

        // account for rebalancing amount
        // @dev must update *after* InfraredBERA.confirmed checked given used in confirmed view
        if (kpr) rebalancing += amount;

        nonce = nonceRequest++;
        requests[nonce] = Request({
            receiver: receiver,
            timestamp: uint96(block.timestamp),
            fee: msg.value,
            amountSubmit: amount,
            amountProcess: amount
        });
        emit Queue(receiver, nonce, amount);
    }

    /// @inheritdoc IInfraredBERAWithdrawor
    function execute(bytes calldata pubkey, uint256 amount) external payable {
        bool kpr = IInfraredBERA(InfraredBERA).keeper(msg.sender);
        // no need to check if in *current* validator set as revert before precompile call if have no stake in pubkey
        // allows for possibly removing stake from validators that were previously removed from validator set on Infrared
        // TODO: check whether precompile ultimately modified for amount / 1 gwei to be consistent with deposits
        if (
            amount == 0 || IInfraredBERA(InfraredBERA).stakes(pubkey) < amount
                || (amount % 1 gwei) != 0 || (amount / 1 gwei) > type(uint64).max
        ) {
            revert Errors.InvalidAmount();
        }

        // cache for event after the bundling while loop
        uint256 _nonce = nonceSubmit; // start
        uint256 nonce; // end (inclusive)
        uint256 fee;

        // bundle nonces to meet up to amount
        // @dev care should be taken with choice of amount parameter not to reach gas limit
        uint256 remaining = amount;
        while (remaining > 0) {
            nonce = nonceSubmit;
            Request memory r = requests[nonce];
            if (r.amountSubmit == 0) revert Errors.InvalidAmount();

            // @dev allow user to force withdraw from infrared validator if enough time has passed
            // TODO: check signature not needed (ignored) on second deposit to pubkey (think so)
            if (!kpr && !_enoughtime(r.timestamp, uint96(block.timestamp))) {
                revert Errors.Unauthorized(msg.sender);
            }

            // first time loop ever hits request dedicate fee to this call
            // @dev for large request requiring multiple separate calls to execute, keeper must front fee in subsequent calls
            // @dev but should make up for fronting via protocol fees on size
            if (r.fee > 0) {
                fee += r.fee;
                r.fee = 0;
            }

            // either use all of request amount and increment nonce if remaining > request amount or use remaining
            // not fully filling request in this call
            uint256 delta =
                remaining > r.amountSubmit ? r.amountSubmit : remaining;
            r.amountSubmit -= delta;
            if (r.amountSubmit == 0) nonceSubmit++;
            requests[nonce] = r;

            // always >= 0 due to delta ternary
            remaining -= delta;
        }

        // remove accumulated escrowed fee from each request in bundled withdraws and refund excess to keeper
        fees -= fee;
        // couple with additional msg.value from keeper in case withdraw precompile fee is large or has been used in prior call that did not fully fill
        fee += msg.value;
        // cache balance prior to withdraw compile to calculate refund on fee
        uint256 _balance = address(this).balance;

        // prepare RLP encoded data (for simplicity, using abi.encodePacked for concatenation)
        // @dev must ensure no matter what withdraw call guaranteed to happen
        bytes memory encoded = abi.encodePacked(
            WITHDRAW_REQUEST_TYPE, // 0x01
            msg.sender, // source_address
            pubkey, // validator_pubkey
            uint64(amount / 1 gwei) // amount in gwei
        );
        (bool success,) = WITHDRAW_PRECOMPILE.call{value: fee}(encoded);
        if (!success) revert Errors.CallFailed();

        // calculate excess from withdraw precompile call to refund
        // TODO: test excess value passed over fee actually refunded
        uint256 excess = fee - (_balance - address(this).balance);

        // register update to stake
        IInfraredBERA(InfraredBERA).register(pubkey, -int256(amount)); // safe as max fits in uint96

        // sweep excess fee back to keeper to cover gas
        if (excess > 0) SafeTransferLib.safeTransferETH(msg.sender, excess);

        emit Execute(pubkey, _nonce, nonce, amount);
    }

    /// @inheritdoc IInfraredBERAWithdrawor
    function process() external {
        uint256 nonce = nonceProcess;
        address depositor = IInfraredBERA(InfraredBERA).depositor();
        Request memory r = requests[nonce];
        if (r.amountSubmit != 0 || r.amountProcess == 0) {
            revert Errors.InvalidAmount();
        }

        uint256 amount = r.amountProcess;
        if (amount > reserves()) revert Errors.InvalidReserves();
        r.amountProcess -= amount;
        nonceProcess++;
        requests[nonce] = r;

        if (r.receiver == depositor) {
            // queue up rebalance to depositor
            rebalancing -= amount;
            IInfraredBERADepositor(r.receiver).queue{value: amount}();
        } else {
            // queue up receiver claim to claimor
            IInfraredBERAClaimor(claimor).queue{value: amount}(r.receiver);
        }
        emit Process(r.receiver, nonce, amount);
    }

    /// @inheritdoc IInfraredBERAWithdrawor
    function sweep(bytes calldata pubkey) external {
        // Check withdrawals disabled
        if (IInfraredBERA(InfraredBERA).withdrawalsEnabled()) {
            revert Errors.Unauthorized(msg.sender);
        }
        // Check keeper authorization
        if (!IInfraredBERA(InfraredBERA).keeper(msg.sender)) {
            revert Errors.Unauthorized(msg.sender);
        }
        // Check if validator has already exited - do this before checking stake
        if (IInfraredBERA(InfraredBERA).hasExited(pubkey)) {
            revert Errors.ValidatorForceExited();
        }
        // forced exit always withdraw entire stake of validator
        uint256 amount = IInfraredBERA(InfraredBERA).stakes(pubkey);

        // revert if insufficient balance
        if (amount > reserves()) revert Errors.InvalidAmount();

        // todo: verfiy forced withdrawal against beacon roots

        // register new validator delta
        IInfraredBERA(InfraredBERA).register(pubkey, -int256(amount));

        // re-stake amount back to ibera depositor
        IInfraredBERADepositor(IInfraredBERA(InfraredBERA).depositor()).queue{
            value: amount
        }();

        emit Sweep(IInfraredBERA(InfraredBERA).depositor(), amount);
    }

    receive() external payable {}
}
