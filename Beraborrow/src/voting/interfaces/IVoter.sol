// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IVoter
 * @notice Interface for Infrared's voting system that manages votes for POL CuttingBoard allocation
 * and bribe vault creation
 * @dev Handles voting power allocation, managed veNFT deposits, and bribe distribution
 */
interface IVoter {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /* @notice Thrown when attempting to vote or deposit when already done in current epoch */
    error AlreadyVotedOrDeposited();
    /* @notice Thrown when attempting to kill an already killed bribe vault */
    error BribeVaultAlreadyKilled();
    /* @notice Thrown when attempting to revive an already active bribe vault */
    error BribeVaultAlreadyRevived();
    /* @notice Thrown when attempting to create a bribe vault that already exists */
    error BribeVaultExists();
    /* @notice Thrown when attempting to interact with a non-existent bribe vault */
    error BribeVaultDoesNotExist(address _stakingToken);
    /* @notice Thrown when attempting to interact with an inactive bribe vault */
    error BribeVaultNotAlive(address _stakingToken);
    /* @notice Thrown when attempting to interact with an inactive managed NFT */
    error InactiveManagedNFT();
    /* @notice Thrown when setting maximum voting number below required threshold */
    error MaximumVotingNumberTooLow();
    /* @notice Thrown when attempting to reset with active votes */
    error NonZeroVotes();
    /* @notice Thrown when token provided is not a valid staking token */
    error NotAStakingToken();
    /* @notice Thrown when caller is not approved or owner of the token */
    error NotApprovedOrOwner();
    /* @notice Thrown when NFT is not in whitelist */
    error NotWhitelistedNFT();
    /* @notice Thrown when token is not in whitelist */
    error NotWhitelistedToken();
    /* @notice Thrown when new value matches current value */
    error SameValue();
    /* @notice Thrown when operation attempted during privileged voting window */
    error SpecialVotingWindow();
    /* @notice Thrown when too many staking tokens provided */
    error TooManyStakingTokens();
    /* @notice Thrown when array lengths don't match */
    error UnequalLengths();
    /* @notice Thrown when balance is zero */
    error ZeroBalance();
    /* @notice Thrown when zero address provided */
    error ZeroAddress();
    /* @notice Thrown when vault is not registered */
    error VaultNotRegistered();
    /* @notice Thrown when caller is not governor */
    error NotGovernor();
    /* @notice Thrown when operation attempted during distribution window */
    error DistributeWindow();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when a new bribe vault is created
     * @param stakingToken The staking token address for which the vault was created
     * @param bribeVault The address of the newly created bribe vault
     * @param creator The address that created the bribe vault
     */
    event BribeVaultCreated(
        address stakingToken, address bribeVault, address creator
    );

    /**
     * @notice Emitted when a bribe vault is killed (disabled)
     * @param bribeVault The address of the killed bribe vault
     */
    event BribeVaultKilled(address indexed bribeVault);

    /**
     * @notice Emitted when a killed bribe vault is revived (re-enabled)
     * @param bribeVault The address of the revived bribe vault
     */
    event BribeVaultRevived(address indexed bribeVault);

    /**
     * @notice Emitted when votes are cast for a staking token
     * @param voter Address of the account casting the vote
     * @param stakingToken The staking token being voted for
     * @param tokenId ID of the veNFT used to vote
     * @param weight Vote weight allocated
     * @param totalWeight New total vote weight for the staking token
     * @param timestamp Block timestamp when vote was cast
     */
    event Voted(
        address indexed voter,
        address indexed stakingToken,
        uint256 indexed tokenId,
        uint256 weight,
        uint256 totalWeight,
        uint256 timestamp
    );

    /**
     * @notice Emitted when votes are withdrawn/reset
     * @param voter Address of the account withdrawing votes
     * @param stakingToken The staking token votes are withdrawn from
     * @param tokenId ID of the veNFT used to vote
     * @param weight Vote weight withdrawn
     * @param totalWeight New total vote weight for the staking token
     * @param timestamp Block timestamp when votes were withdrawn
     */
    event Abstained(
        address indexed voter,
        address indexed stakingToken,
        uint256 indexed tokenId,
        uint256 weight,
        uint256 totalWeight,
        uint256 timestamp
    );

    /**
     * @notice Emitted when an NFT's whitelist status changes
     * @param whitelister Address making the whitelist change
     * @param tokenId ID of the NFT being whitelisted/unwhitelisted
     * @param _bool New whitelist status
     */
    event WhitelistNFT(
        address indexed whitelister, uint256 indexed tokenId, bool indexed _bool
    );

    /**
     * @notice Emitted when a killed bribe vault is skipped
     * @param stakingToken Address of staking token for vault to skip
     * @param tokenId ID of the veNFT used to vote
     */
    event SkipKilledBribeVault(
        address indexed stakingToken, uint256 indexed tokenId
    );

    /**
     * @notice Emitted when maximum voting number is set
     * @param maxVotingNum New maximum number of allowed votes
     */
    event MaxVotingNumSet(uint256 indexed maxVotingNum);

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the VotingEscrow contract address
     * @return Address of the VE token that governs these contracts
     */
    function ve() external view returns (address);

    /**
     * @notice Returns total voting weight across all votes
     * @return Total weight sum of all active votes
     */
    function totalWeight() external view returns (uint256);

    /**
     * @notice Returns maximum number of staking tokens one voter can vote for
     * @return Maximum number of allowed votes per voter
     */
    function maxVotingNum() external view returns (uint256);

    /**
     * @notice Returns global fee distribution vault address
     * @return Address of the fee vault
     */
    function feeVault() external view returns (address);

    /**
     * @notice Returns bribe vault address for a given staking token
     * @param stakingToken Address of staking token
     * @return Address of associated bribe vault
     */
    function bribeVaults(address stakingToken)
        external
        view
        returns (address);

    /**
     * @notice Returns total weight allocated to a staking token
     * @param stakingToken Address of staking token
     * @return Total voting weight for the token
     */
    function weights(address stakingToken) external view returns (uint256);

    /**
     * @notice Returns vote weight allocated by token ID for specific staking token
     * @param tokenId NFT token ID
     * @param stakingToken Address of staking token
     * @return Vote weight allocated
     */
    function votes(uint256 tokenId, address stakingToken)
        external
        view
        returns (uint256);

    /**
     * @notice Returns total vote weight used by specific token ID
     * @param tokenId NFT token ID
     * @return Total used voting weight
     */
    function usedWeights(uint256 tokenId) external view returns (uint256);

    /**
     * @notice Returns timestamp of last vote for a token ID
     * @param tokenId NFT token ID
     * @return Timestamp of last vote
     */
    function lastVoted(uint256 tokenId) external view returns (uint256);

    /**
     * @notice Checks if a token is whitelisted for rewards
     * @param token Address of token to check
     * @return True if token is whitelisted
     */
    function isWhitelistedToken(address token) external view returns (bool);

    /**
     * @notice Checks if NFT is whitelisted for special voting
     * @param tokenId NFT token ID to check
     * @return True if NFT is whitelisted
     */
    function isWhitelistedNFT(uint256 tokenId) external view returns (bool);

    /**
     * @notice Checks if bribe vault is active
     * @param bribeVault Address of bribe vault to check
     * @return True if vault is active
     */
    function isAlive(address bribeVault) external view returns (bool);

    /**
     * @notice Returns number of staking tokens with active bribe vaults
     * @return Count of staking tokens with bribe vaults
     */
    function length() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                        TIME HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates start of epoch containing timestamp
     * @param _timestamp Input timestamp
     * @return Start of epoch time
     */
    function epochStart(uint256 _timestamp) external pure returns (uint256);

    /**
     * @notice Calculates start of next epoch after timestamp
     * @param _timestamp Input timestamp
     * @return Start of next epoch time
     */
    function epochNext(uint256 _timestamp) external pure returns (uint256);

    /**
     * @notice Calculates start of voting window for epoch containing timestamp
     * @param _timestamp Input timestamp
     * @return Vote window start time
     */
    function epochVoteStart(uint256 _timestamp)
        external
        pure
        returns (uint256);

    /**
     * @notice Calculates end of voting window for epoch containing timestamp
     * @param _timestamp Input timestamp
     * @return Vote window end time
     */
    function epochVoteEnd(uint256 _timestamp) external pure returns (uint256);

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Updates voting balances in rewards contracts for a token ID
     * @dev Should be called after any action that affects vote weight
     * @param _tokenId veNFT token ID to update
     */
    function poke(uint256 _tokenId) external;

    /**
     * @notice Distributes voting weight to multiple staking tokens
     * @dev Weight is allocated proportionally based on provided weights
     * @param _tokenId veNFT token ID voting with
     * @param _stakingTokenVote Array of staking token addresses receiving votes
     * @param _weights Array of weights to allocate to each token
     */
    function vote(
        uint256 _tokenId,
        address[] calldata _stakingTokenVote,
        uint256[] calldata _weights
    ) external;

    /**
     * @notice Resets voting state for a token ID
     * @dev Required before making changes to veNFT state
     * @param _tokenId veNFT token ID to reset
     */
    function reset(uint256 _tokenId) external;

    /**
     * @notice Deposits veNFT into a managed NFT
     * @dev NFT will be re-locked to max time on withdrawal
     * @param _tokenId veNFT token ID to deposit
     * @param _mTokenId Managed NFT token ID to deposit into
     */
    function depositManaged(uint256 _tokenId, uint256 _mTokenId) external;

    /**
     * @notice Withdraws veNFT from a managed NFT
     * @dev Withdrawing locks NFT to max lock time
     * @param _tokenId veNFT token ID to withdraw
     */
    function withdrawManaged(uint256 _tokenId) external;

    /**
     * @notice Claims bribes from multiple sources for a veNFT
     * @param _bribes Array of bribe vault addresses to claim from
     * @param _tokens Array of reward tokens to claim for each vault
     * @param _tokenId veNFT token ID to claim for
     */
    function claimBribes(
        address[] memory _bribes,
        address[][] memory _tokens,
        uint256 _tokenId
    ) external;

    /**
     * @notice Claims fee rewards for a veNFT
     * @param _tokens Array of fee tokens to claim
     * @param _tokenId veNFT token ID to claim for
     */
    function claimFees(address[] memory _tokens, uint256 _tokenId) external;

    /**
     * @notice Updates maximum allowed votes per voter
     * @param _maxVotingNum New maximum number of allowed votes
     */
    function setMaxVotingNum(uint256 _maxVotingNum) external;

    /**
     * @notice Updates whitelist status for veNFT for privileged voting
     * @param _tokenId veNFT token ID to update
     * @param _bool New whitelist status
     */
    function whitelistNFT(uint256 _tokenId, bool _bool) external;

    /**
     * @notice Creates new bribe vault for staking token
     * @param _stakingToken Address of staking token
     * @param _rewardTokens Array of reward token addresses
     * @return Address of created bribe vault
     */
    function createBribeVault(
        address _stakingToken,
        address[] calldata _rewardTokens
    ) external returns (address);

    /**
     * @notice Disables a bribe vault
     * @param _stakingToken Address of staking token for vault to disable
     */
    function killBribeVault(address _stakingToken) external;

    /**
     * @notice Re-enables a disabled bribe vault
     * @param _stakingToken Address of staking token for vault to re-enable
     */
    function reviveBribeVault(address _stakingToken) external;
}
