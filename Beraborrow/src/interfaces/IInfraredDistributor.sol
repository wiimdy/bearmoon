// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@solmate/tokens/ERC20.sol";

/**
 * @title Infrared Distributor Interface
 * @notice Interface for distributing validator commissions and rewards
 * @dev Handles reward distribution snapshots and claiming logic for validators
 */
interface IInfraredDistributor {
    /**
     * @notice Emitted when validator is added to commission-eligible set
     * @param pubkey Validator's public key
     * @param operator Address authorized to claim rewards
     * @param amountCumulative Starting point for commission stream
     */
    event Added(bytes pubkey, address operator, uint256 amountCumulative);

    /**
     * @notice Emitted when validator is removed from commission-eligible set
     * @param pubkey Validator's public key
     * @param operator Address previously authorized for claims
     * @param amountCumulative Final point for commission stream
     */
    event Removed(bytes pubkey, address operator, uint256 amountCumulative);

    /**
     * @notice Emitted when validator is fully purged from registry
     * @param pubkey Validator's public key
     * @param validator Address being purged
     */
    event Purged(bytes pubkey, address validator);

    /**
     * @notice Emitted when new commission rewards are added
     * @param amount New rewards being distributed
     * @param num Current number of eligible validators
     */
    event Notified(uint256 amount, uint256 num);

    /**
     * @notice Emitted when validator claims their commission
     * @param pubkey Claiming validator's public key
     * @param validator Address authorized for claims
     * @param recipient Address receiving the commission
     * @param amount Amount of commission claimed
     */
    event Claimed(
        bytes pubkey, address validator, address recipient, uint256 amount
    );

    /**
     * @notice Reward accumulation checkpoints for validators
     * @dev Used to calculate claimable rewards between snapshots
     */
    struct Snapshot {
        /**
         * @notice Last claimed reward accumulator value
         */
        uint256 amountCumulativeLast;
        /**
         * @notice Final reward accumulator value (set on removal)
         */
        uint256 amountCumulativeFinal;
    }

    /**
     * @notice Token used for reward distributions
     * @return The ERC20 token interface of the reward token
     */
    function token() external view returns (ERC20);

    /**
     * @notice Tracks reward amount accumulation per validator
     * @return Current cumulative amount of rewards
     */
    function amountsCumulative() external view returns (uint256);

    /**
     * @notice Get validator's reward snapshots
     * @param pubkey Validator's public key
     * @return amountCumulativeLast Last claimed accumulator value
     * @return amountCumulativeFinal Final accumulator value if removed
     * @dev Returns (0,0) if validator doesn't exist
     */
    function getSnapshot(bytes calldata pubkey)
        external
        view
        returns (uint256 amountCumulativeLast, uint256 amountCumulativeFinal);

    /**
     * @notice Get validator's registered claim address
     * @param pubkey Validator's public key
     * @return Address authorized to claim validator rewards
     */
    function getValidator(bytes calldata pubkey)
        external
        view
        returns (address);

    /**
     * @notice Register new validator for rewards
     * @dev Only callable by Infrared contract
     * @param pubkey Validator's public key
     * @param validator Address authorized to claim rewards
     * @custom:access-control Requires INFRARED_ROLE
     * @custom:error ValidatorAlreadyExists if validator already registered
     */
    function add(bytes calldata pubkey, address validator) external;

    /**
     * @notice Removes validator from reward-eligible set
     * @dev Only callable by Infrared contract
     * @param pubkey Validator's public key
     * @custom:access-control Requires INFRARED_ROLE
     */
    function remove(bytes calldata pubkey) external;

    /**
     * @notice Purges validator from registry completely
     * @dev Only possible after all rewards are claimed
     * @param pubkey Validator's public key
     * @custom:error ClaimableRewardsExist if unclaimed rewards remain
     */
    function purge(bytes calldata pubkey) external;

    /**
     * @notice Distributes new commission rewards to validator set
     * @param amount Amount to distribute equally among validators
     * @custom:error ZeroAmount if amount is 0
     * @custom:error InvalidValidator if no validators exist
     */
    function notifyRewardAmount(uint256 amount) external;

    /**
     * @notice Claims outstanding commission rewards
     * @param pubkey Validator's public key
     * @param recipient Address to receive the claimed rewards
     * @custom:error InvalidValidator if caller not authorized
     * @custom:error ZeroAmount if no rewards to claim
     */
    function claim(bytes calldata pubkey, address recipient) external;
}
