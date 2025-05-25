// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IReward
 * @notice Interface for rewards distribution contracts in the Infrared Voter
 * @dev Base interface implemented by all reward-type contracts
 */
interface IReward {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Thrown when attempting to interact with an invalid reward token
     */
    error InvalidReward();
    /**
     * @notice Thrown when caller is not authorized to perform operation
     */
    error NotAuthorized();
    /**
     * @notice Thrown when token is not in whitelist
     */
    error NotWhitelisted();
    /**
     * @notice Thrown when attempting operation with zero amount
     */
    error ZeroAmount();
    /**
     * @notice Thrown when supply is not zero
     */
    error NonZeroSupply();
    /**
     * @notice Thrown when epoch is active
     */
    error ActiveEpoch();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when tokens are deposited for rewards
     * @param from Address depositing tokens
     * @param tokenId ID of the veNFT receiving deposit
     * @param amount Amount of tokens deposited
     */
    event Deposit(
        address indexed from, uint256 indexed tokenId, uint256 amount
    );

    /**
     * @notice Emitted when tokens are withdrawn from rewards
     * @param from Address withdrawing tokens
     * @param tokenId ID of the veNFT withdrawing from
     * @param amount Amount of tokens withdrawn
     */
    event Withdraw(
        address indexed from, uint256 indexed tokenId, uint256 amount
    );

    /**
     * @notice Emitted when new rewards are added
     * @param from Address supplying the reward tokens
     * @param reward Token being added as reward
     * @param epoch Epoch timestamp for reward distribution
     * @param amount Amount of reward tokens added
     */
    event NotifyReward(
        address indexed from,
        address indexed reward,
        uint256 indexed epoch,
        uint256 amount
    );

    /**
     * @notice Emitted when rewards are claimed
     * @param from Address claiming the rewards
     * @param reward Token being claimed
     * @param amount Amount of tokens claimed
     */
    event ClaimRewards(
        address indexed from, address indexed reward, uint256 amount
    );

    /*//////////////////////////////////////////////////////////////
                            STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Balance checkpoint for tracking historical balances
     * @param timestamp Time of checkpoint
     * @param balanceOf Balance at checkpoint
     */
    struct Checkpoint {
        uint256 timestamp;
        uint256 balanceOf;
    }

    /**
     * @notice Supply checkpoint for tracking total supply
     * @param timestamp Time of checkpoint
     * @param supply Total supply at checkpoint
     */
    struct SupplyCheckpoint {
        uint256 timestamp;
        uint256 supply;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Duration of each reward epoch in seconds
     * @return Fixed duration of 7 days
     */
    function DURATION() external view returns (uint256);

    /**
     * @notice Address of the Voter contract that manages rewards
     * @return Voter contract address
     */
    function voter() external view returns (address);

    /**
     * @notice Address of the VotingEscrow contract that manages veNFTs
     * @return VotingEscrow contract address
     */
    function ve() external view returns (address);

    /**
     * @notice Address permitted to call privileged state-changing functions
     * @return Authorized caller address
     */
    function authorized() external view returns (address);

    /**
     * @notice Total amount of staking tokens locked in contract
     * @return Current total supply of staked tokens
     */
    function totalSupply() external view returns (uint256);

    /**
     * @notice Retrieves current staked balance for a veNFT
     * @param tokenId ID of the veNFT to query
     * @return Current staked token balance
     */
    function balanceOf(uint256 tokenId) external view returns (uint256);

    /**
     * @notice Gets reward amount allocated for a specific epoch
     * @param token Address of reward token
     * @param epochStart Starting timestamp of epoch
     * @return Amount of token allocated as rewards for the epoch
     */
    function tokenRewardsPerEpoch(address token, uint256 epochStart)
        external
        view
        returns (uint256);

    /**
     * @notice Retrieves timestamp of last reward claim for a veNFT
     * @param token Address of reward token
     * @param tokenId ID of veNFT that claimed
     * @return Timestamp of last claim for this token/veNFT pair
     */
    function lastEarn(address token, uint256 tokenId)
        external
        view
        returns (uint256);

    /**
     * @notice Checks if a token is configured as a reward token
     * @param token Address of token to check
     * @return True if token is active for rewards
     */
    function isReward(address token) external view returns (bool);

    /**
     * @notice Number of balance checkpoints for a veNFT
     * @param tokenId ID of veNFT to query
     * @return Number of checkpoints recorded
     */
    function numCheckpoints(uint256 tokenId) external view returns (uint256);

    /**
     * @notice Total number of supply checkpoints recorded
     * @return Count of global supply checkpoints
     */
    function supplyNumCheckpoints() external view returns (uint256);

    /**
     * @notice Gets balance checkpoint data for a veNFT at specific index
     * @param tokenId ID of veNFT to query
     * @param index Checkpoint index to read
     * @return timestamp Time checkpoint was created
     * @return balanceOf Balance recorded at checkpoint
     */
    function checkpoints(uint256 tokenId, uint256 index)
        external
        view
        returns (uint256 timestamp, uint256 balanceOf);

    /**
     * @notice Gets total supply checkpoint data at specific index
     * @param index Checkpoint index to read
     * @return timestamp Time checkpoint was created
     * @return supply Total supply recorded at checkpoint
     */
    function supplyCheckpoints(uint256 index)
        external
        view
        returns (uint256 timestamp, uint256 supply);

    /**
     * @notice Gets historical balance index for a veNFT at timestamp
     * @dev Uses binary search to find checkpoint index
     * @param tokenId ID of veNFT to query
     * @param timestamp Time to query balance at
     * @return Index of nearest checkpoint before timestamp
     */
    function getPriorBalanceIndex(uint256 tokenId, uint256 timestamp)
        external
        view
        returns (uint256);

    /**
     * @notice Gets historical supply index at timestamp
     * @dev Uses binary search to find checkpoint index
     * @param timestamp Time to query supply at
     * @return Index of nearest checkpoint before timestamp
     */
    function getPriorSupplyIndex(uint256 timestamp)
        external
        view
        returns (uint256);

    /**
     * @notice Number of tokens configured for rewards
     * @return Length of rewards token list
     */
    function rewardsListLength() external view returns (uint256);

    /**
     * @notice Calculates unclaimed rewards for a veNFT
     * @param token Address of reward token to calculate
     * @param tokenId ID of veNFT to calculate for
     * @return Amount of unclaimed rewards
     */
    function earned(address token, uint256 tokenId)
        external
        view
        returns (uint256);

    /*//////////////////////////////////////////////////////////////
                        STATE CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Records a token deposit and updates checkpoints
     * @dev Can only be called by authorized address
     * @param amount Amount of tokens being deposited
     * @param tokenId ID of veNFT receiving deposit
     */
    function _deposit(uint256 amount, uint256 tokenId) external;

    /**
     * @notice Records a token withdrawal and updates checkpoints
     * @dev Can only be called by authorized address
     * @param amount Amount of tokens being withdrawn
     * @param tokenId ID of veNFT withdrawing from
     */
    function _withdraw(uint256 amount, uint256 tokenId) external;

    /**
     * @notice Claims accumulated rewards for a veNFT
     * @param tokenId ID of veNFT claiming rewards
     * @param tokens Array of reward token addresses to claim
     */
    function getReward(uint256 tokenId, address[] memory tokens) external;

    /**
     * @notice Adds new reward tokens for distribution
     * @dev Transfers tokens from caller and updates reward accounting
     * @param token Address of token to add as reward
     * @param amount Amount of token to add to rewards
     */
    function notifyRewardAmount(address token, uint256 amount) external;

    /**
     * @notice in case rewards where distributed during a epoch with no deposits, redistribute the rewards
     * @param timestamp Timestamp of the start of the epoch to renotify
     * @param token Address of token to renotify
     */
    function renotifyRewardAmount(uint256 timestamp, address token) external;
}
