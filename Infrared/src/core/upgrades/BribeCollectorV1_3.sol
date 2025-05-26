// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";

import {InfraredUpgradeable} from "src/core/InfraredUpgradeable.sol";
import {Errors} from "src/utils/Errors.sol";

import {IBribeCollector} from "src/interfaces/IBribeCollector.sol";

/**
 * @title BribeCollector v1.3
 * @notice The Bribe Collector contract is responsible for collecting bribes from Berachain rewards vaults and
 * auctioning them for a Payout token which then is distributed among Infrared validators.
 * @dev This contract is forked from Berachain POL which is forked from Uniswap V3 Factory Owner contract.
 * https://github.com/uniswapfoundation/UniStaker/blob/main/src/V3FactoryOwner.sol
 * @dev v1.3 adds a permission check to require KEEPER_ROLE for claiming fees. This is necessary because
 * Infrared now boosts external validators and collects POL incentives from them. Since Merkle proofs for
 * these incentives are only updated periodically, this can lead to unpredictable value inflow. If timed
 * unfortunately, this could create a significant loss for the protocol if the value far exceeds the payout amount.
 * The onlyKeeper modifier is a temporary security measure until a smoothing mechanism for available tokens
 * to claim is implemented.
 */
contract BribeCollectorV1_3 is InfraredUpgradeable, IBribeCollector {
    using SafeTransferLib for ERC20;

    /// @notice Payout token, required to be WBERA token as its unwrapped and used to compound rewards in the `iBera` system.
    address public payoutToken;

    /// @notice Payout amount is a constant value that is paid by the caller of the `claimFees` function.
    uint256 public payoutAmount;

    // Reserve storage slots for future upgrades for safety
    uint256[40] private __gap;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       ADMIN FUNCTIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Set the payout amount for the bribe collector.
    /// @param _newPayoutAmount updated payout amount
    function setPayoutAmount(uint256 _newPayoutAmount) external onlyGovernor {
        if (_newPayoutAmount == 0) revert Errors.ZeroAmount();
        emit PayoutAmountSet(payoutAmount, _newPayoutAmount);
        payoutAmount = _newPayoutAmount;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       WRITE FUNCTIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @inheritdoc IBribeCollector
    /// @dev Only callable by accounts with the KEEPER_ROLE for security to prevent
    /// potential economic losses from unpredictable external validator incentives
    function claimFees(
        address _recipient,
        address[] calldata _feeTokens,
        uint256[] calldata _feeAmounts
    ) external onlyKeeper {
        if (_feeTokens.length != _feeAmounts.length) {
            revert Errors.InvalidArrayLength();
        }
        if (_recipient == address(0)) revert Errors.ZeroAddress();

        uint256 senderBalance = ERC20(payoutToken).balanceOf(msg.sender);
        if (senderBalance < payoutAmount) {
            revert Errors.InsufficientBalance();
        }

        // transfer price of claiming tokens (payoutAmount) from the sender to this contract
        ERC20(payoutToken).safeTransferFrom(
            msg.sender, address(this), payoutAmount
        );
        // set the allowance of the payout token to the infrared contract to be sent to
        // validator distribution contract
        ERC20(payoutToken).safeApprove(
            address(infrared), ERC20(payoutToken).balanceOf(address(this))
        );
        // Callback into infrared post auction to split amount to vaults and protocol
        infrared.collectBribes(
            payoutToken, ERC20(payoutToken).balanceOf(address(this))
        );
        // payoutAmount will be transferred out at this point

        // For all the specified fee tokens, transfer them to the recipient.
        for (uint256 i; i < _feeTokens.length; i++) {
            address feeToken = _feeTokens[i];
            uint256 feeAmount = _feeAmounts[i];
            if (feeToken == payoutToken) {
                revert Errors.InvalidFeeToken();
            }

            if (!infrared.whitelistedRewardTokens(feeToken)) {
                revert Errors.FeeTokenNotWhitelisted();
            }

            uint256 contractBalance = ERC20(feeToken).balanceOf(address(this));
            if (feeAmount > contractBalance) {
                revert Errors.InsufficientFeeTokenBalance();
            }
            ERC20(feeToken).safeTransfer(_recipient, feeAmount);
            emit FeesClaimed(msg.sender, _recipient, feeToken, feeAmount);
        }
    }

    function sweepPayoutToken() external {
        uint256 balance = ERC20(payoutToken).balanceOf(address(this));
        if (balance == 0) revert Errors.InsufficientBalance();
        // set the allowance of the payout token to the infrared contract to be sent to
        // validator distribution contract
        ERC20(payoutToken).safeApprove(address(infrared), balance);
        // Callback into infrared split amount to vaults and protocol
        infrared.collectBribes(payoutToken, balance);
    }
}
