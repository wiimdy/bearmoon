# Voter
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/voting/Voter.sol)

**Inherits:**
[IVoter](/src/voting/interfaces/IVoter.sol/interface.IVoter.md), [InfraredUpgradeable](/src/core/InfraredUpgradeable.sol/abstract.InfraredUpgradeable.md), ReentrancyGuardUpgradeable

**Authors:**
Modified from Velodrome (https://github.com/velodrome-finance/contracts/blob/main/contracts/Voter.sol), Infrared, @NoFront

Ensure new epoch before voting and manage staking tokens and bribe vaults.

*This contract manages votes for POL CuttingBoard allocation and respective bribeVault creation.
It also provides support for depositing and withdrawing from managed veNFTs. Inspired by Velodrome V2 Voter.*


## State Variables
### ve
Returns the VotingEscrow contract address


```solidity
address public ve;
```


### DURATION
Duration over which rewards are released

*Used as constant across various reward calculations*


```solidity
uint256 internal constant DURATION = 7 days;
```


### totalWeight
Returns total voting weight across all votes


```solidity
uint256 public totalWeight;
```


### maxVotingNum
Returns maximum number of staking tokens one voter can vote for


```solidity
uint256 public maxVotingNum;
```


### MIN_MAXVOTINGNUM
Minimum allowed value for maximum voting number

*Used as validation threshold in setMaxVotingNum*


```solidity
uint256 internal constant MIN_MAXVOTINGNUM = 1;
```


### feeVault
Returns global fee distribution vault address


```solidity
address public feeVault;
```


### stakingTokens
*Internal array of all staking tokens with active bribe vaults
Used for token enumeration and state tracking*


```solidity
address[] public stakingTokens;
```


### bribeVaults
Returns bribe vault address for a given staking token


```solidity
mapping(address => address) public bribeVaults;
```


### weights
Returns total weight allocated to a staking token


```solidity
mapping(address => uint256) public weights;
```


### votes
Returns vote weight allocated by token ID for specific staking token


```solidity
mapping(uint256 => mapping(address => uint256)) public votes;
```


### stakingTokenVote
*NFT => List of stakingTokens voted for by NFT*


```solidity
mapping(uint256 => address[]) public stakingTokenVote;
```


### usedWeights
Returns total vote weight used by specific token ID


```solidity
mapping(uint256 => uint256) public usedWeights;
```


### lastVoted
Returns timestamp of last vote for a token ID


```solidity
mapping(uint256 => uint256) public lastVoted;
```


### isWhitelistedNFT
Checks if NFT is whitelisted for special voting


```solidity
mapping(uint256 => bool) public isWhitelistedNFT;
```


### isAlive
Checks if bribe vault is active


```solidity
mapping(address => bool) public isAlive;
```


## Functions
### onlyNewEpoch

Ensures operations only occur in new epochs and outside distribution window

*Validates both epoch transition and proper timing within epoch*


```solidity
modifier onlyNewEpoch(uint256 _tokenId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|The token ID to check last vote timestamp for|


### epochStart

Calculates start of epoch containing timestamp


```solidity
function epochStart(uint256 _timestamp) external pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_timestamp`|`uint256`|Input timestamp|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Start of epoch time|


### epochNext

Calculates start of next epoch after timestamp


```solidity
function epochNext(uint256 _timestamp) external pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_timestamp`|`uint256`|Input timestamp|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Start of next epoch time|


### epochVoteStart

Calculates start of voting window for epoch containing timestamp


```solidity
function epochVoteStart(uint256 _timestamp) external pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_timestamp`|`uint256`|Input timestamp|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Vote window start time|


### epochVoteEnd

Calculates end of voting window for epoch containing timestamp


```solidity
function epochVoteEnd(uint256 _timestamp) external pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_timestamp`|`uint256`|Input timestamp|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Vote window end time|


### constructor

Constructor for Voter contract

*Reverts if infrared address is zero*


```solidity
constructor(address _infrared) InfraredUpgradeable(_infrared);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_infrared`|`address`|Address of the Infrared contract|


### initialize

Initializes the Voter contract with the voting escrow and fee vault

*Sets up initial state including fee vault with configured reward tokens*


```solidity
function initialize(address _ve) external initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_ve`|`address`|Address of the voting escrow contract|


### setMaxVotingNum

Updates maximum allowed votes per voter


```solidity
function setMaxVotingNum(uint256 _maxVotingNum) external onlyGovernor;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_maxVotingNum`|`uint256`|New maximum number of allowed votes|


### reset

Resets voting state for a token ID

*Required before making changes to veNFT state*


```solidity
function reset(uint256 _tokenId) external onlyNewEpoch(_tokenId) nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|veNFT token ID to reset|


### _reset

Resets vote state for a token ID

*Cleans up all vote accounting and emits appropriate events*


```solidity
function _reset(uint256 _tokenId) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|Token ID to reset voting state for|


### poke

Updates voting balances in rewards contracts for a token ID

*Should be called after any action that affects vote weight*


```solidity
function poke(uint256 _tokenId) external nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|veNFT token ID to update|


### _poke

Updates voting power for a token ID

*Recalculates and updates all vote weightings*


```solidity
function _poke(uint256 _tokenId, uint256 _weight) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|Token ID to update voting power for|
|`_weight`|`uint256`|New voting power weight to apply|


### _vote

Core voting logic to allocate weights to staking tokens

*Handles vote accounting, reward deposits and event emissions*

*Implementation sequence:
1. Reset all existing votes and accounting via _reset
2. Calculate total vote weight for normalizing allocations
3. For each staking token:
- Validate bribe vault exists and is active
- Calculate and apply normalized vote weight
- Update token-specific accounting
- Deposit into bribe vault
4. Update global vote accounting if votes were cast*


```solidity
function _vote(
    uint256 _tokenId,
    uint256 _weight,
    address[] memory _stakingTokenVote,
    uint256[] memory _weights
) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|Token ID that is voting|
|`_weight`|`uint256`|Total voting power weight available|
|`_stakingTokenVote`|`address[]`|Array of staking tokens to vote for|
|`_weights`|`uint256[]`|Array of weights to allocate to each token|


### vote

Distributes voting weight to multiple staking tokens

*Weight is allocated proportionally based on provided weights*


```solidity
function vote(
    uint256 _tokenId,
    address[] calldata _stakingTokenVote,
    uint256[] calldata _weights
) external onlyNewEpoch(_tokenId) nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|veNFT token ID voting with|
|`_stakingTokenVote`|`address[]`|Array of staking token addresses receiving votes|
|`_weights`|`uint256[]`|Array of weights to allocate to each token|


### depositManaged

Deposits veNFT into a managed NFT

*NFT will be re-locked to max time on withdrawal*


```solidity
function depositManaged(uint256 _tokenId, uint256 _mTokenId)
    external
    nonReentrant
    onlyNewEpoch(_tokenId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|veNFT token ID to deposit|
|`_mTokenId`|`uint256`|Managed NFT token ID to deposit into|


### withdrawManaged

Withdraws veNFT from a managed NFT

*Withdrawing locks NFT to max lock time*


```solidity
function withdrawManaged(uint256 _tokenId)
    external
    nonReentrant
    onlyNewEpoch(_tokenId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|veNFT token ID to withdraw|


### isWhitelistedToken

Checks if a token is whitelisted for rewards


```solidity
function isWhitelistedToken(address _token) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_token`|`address`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if token is whitelisted|


### whitelistNFT

Updates whitelist status for veNFT for privileged voting


```solidity
function whitelistNFT(uint256 _tokenId, bool _bool) external onlyGovernor;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|veNFT token ID to update|
|`_bool`|`bool`|New whitelist status|


### createBribeVault

Creates new bribe vault for staking token


```solidity
function createBribeVault(address _stakingToken, address[] calldata _rewards)
    external
    onlyKeeper
    nonReentrant
    whenInitialized
    returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_stakingToken`|`address`|Address of staking token|
|`_rewards`|`address[]`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Address of created bribe vault|


### killBribeVault

Disables a bribe vault


```solidity
function killBribeVault(address _stakingToken) external onlyGovernor;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_stakingToken`|`address`|Address of staking token for vault to disable|


### reviveBribeVault

Re-enables a disabled bribe vault


```solidity
function reviveBribeVault(address _stakingToken) external onlyGovernor;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_stakingToken`|`address`|Address of staking token for vault to re-enable|


### length

Returns number of staking tokens with active bribe vaults


```solidity
function length() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Count of staking tokens with bribe vaults|


### claimBribes

Claims bribes from multiple sources for a veNFT


```solidity
function claimBribes(
    address[] memory _bribes,
    address[][] memory _tokens,
    uint256 _tokenId
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bribes`|`address[]`|Array of bribe vault addresses to claim from|
|`_tokens`|`address[][]`|Array of reward tokens to claim for each vault|
|`_tokenId`|`uint256`|veNFT token ID to claim for|


### claimFees

Claims fee rewards for a veNFT


```solidity
function claimFees(address[] memory _tokens, uint256 _tokenId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokens`|`address[]`|Array of fee tokens to claim|
|`_tokenId`|`uint256`|veNFT token ID to claim for|


### getStakingTokenWeights

Returns all staking tokens and their current voting weights

*Helper function that aggregates staking token data*


```solidity
function getStakingTokenWeights()
    public
    view
    returns (
        address[] memory _stakingTokens,
        uint256[] memory _weights,
        uint256 _totalWeight
    );
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_stakingTokens`|`address[]`|Array of staking token addresses|
|`_weights`|`uint256[]`|Array of voting weights corresponding to each token|
|`_totalWeight`|`uint256`|Sum of all voting weights|


