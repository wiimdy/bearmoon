// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {IPOLErrors} from "@berachain/pol/interfaces/IPOLErrors.sol";

interface IBribeCollector is IPOLErrors {
    /**
     * @notice Emitted when the payout amount is updated by the governor
     * @param oldPayoutAmount Previous payout amount
     * @param newPayoutAmount New payout amount set
     */
    event PayoutAmountSet(
        uint256 indexed oldPayoutAmount, uint256 indexed newPayoutAmount
    );

    /**
     * @notice Emitted when the fees are claimed
     * @param caller Caller of the `claimFees` function
     * @param recipient The address to which collected POL bribes will be transferred
     * @param feeToken The address of the fee token to collect
     * @param amount The amount of fee token to transfer
     */
    event FeesClaimed(
        address indexed caller,
        address indexed recipient,
        address indexed feeToken,
        uint256 amount
    );

    /**
     * @notice Token used for fee payments when claiming bribes
     * @return Address of the payout token
     */
    function payoutToken() external view returns (address);

    /**
     * @notice The amount of payout token that is required to claim POL bribes for all tokens
     * @dev This works as first come first serve basis. whoever pays this much amount of the payout amount first will
     * get the fees
     */
    function payoutAmount() external view returns (uint256);

    /**
     * @notice Update the payout amount to a new value. Must be called by governor
     * @param _newPayoutAmount The value that will be the new payout amount
     */
    function setPayoutAmount(uint256 _newPayoutAmount) external;

    /**
     * @notice Claims accumulated bribes in exchange for payout token
     * @dev Caller must approve payoutAmount of payout token to this contract.
     * @param _recipient The Address to receive claimed tokens
     * @param _feeTokens Array of token addresses to claim
     * @param _feeAmounts Array of amounts to claim for each fee token
     */
    function claimFees(
        address _recipient,
        address[] calldata _feeTokens,
        uint256[] calldata _feeAmounts
    ) external;
}
