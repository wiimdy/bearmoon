# IVoter
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/voting/interfaces/IVoter.sol)

Interface for Infrared's voting system that manages votes for POL CuttingBoard allocation
and bribe vault creation

*Handles voting power allocation, managed veNFT deposits, and bribe distribution*


## Functions
### ve

Returns the VotingEscrow contract address


```solidity
function ve() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Address of the VE token that governs these contracts|


### totalWeight

Returns total voting weight across all votes


```solidity
function totalWeight() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total weight sum of all active votes|


### maxVotingNum

Returns maximum number of staking tokens one voter can vote for


```solidity
function maxVotingNum() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Maximum number of allowed votes per voter|


### feeVault

Returns global fee distribution vault address


```solidity
function feeVault() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Address of the fee vault|


### bribeVaults

Returns bribe vault address for a given staking token


```solidity
function bribeVaults(address stakingToken) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`stakingToken`|`address`|Address of staking token|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Address of associated bribe vault|


### weights

Returns total weight allocated to a staking token


```solidity
function weights(address stakingToken) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`stakingToken`|`address`|Address of staking token|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total voting weight for the token|


### votes

Returns vote weight allocated by token ID for specific staking token


```solidity
function votes(uint256 tokenId, address stakingToken)
    external
    view
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|NFT token ID|
|`stakingToken`|`address`|Address of staking token|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Vote weight allocated|


### usedWeights

Returns total vote weight used by specific token ID


```solidity
function usedWeights(uint256 tokenId) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|NFT token ID|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total used voting weight|


### lastVoted

Returns timestamp of last vote for a token ID


```solidity
function lastVoted(uint256 tokenId) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|NFT token ID|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Timestamp of last vote|


### isWhitelistedToken

Checks if a token is whitelisted for rewards


```solidity
function isWhitelistedToken(address token) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Address of token to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if token is whitelisted|


### isWhitelistedNFT

Checks if NFT is whitelisted for special voting


```solidity
function isWhitelistedNFT(uint256 tokenId) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|NFT token ID to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if NFT is whitelisted|


### isAlive

Checks if bribe vault is active


```solidity
function isAlive(address bribeVault) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`bribeVault`|`address`|Address of bribe vault to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if vault is active|


### length

Returns number of staking tokens with active bribe vaults


```solidity
function length() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Count of staking tokens with bribe vaults|


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


### poke

Updates voting balances in rewards contracts for a token ID

*Should be called after any action that affects vote weight*


```solidity
function poke(uint256 _tokenId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|veNFT token ID to update|


### vote

Distributes voting weight to multiple staking tokens

*Weight is allocated proportionally based on provided weights*


```solidity
function vote(
    uint256 _tokenId,
    address[] calldata _stakingTokenVote,
    uint256[] calldata _weights
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|veNFT token ID voting with|
|`_stakingTokenVote`|`address[]`|Array of staking token addresses receiving votes|
|`_weights`|`uint256[]`|Array of weights to allocate to each token|


### reset

Resets voting state for a token ID

*Required before making changes to veNFT state*


```solidity
function reset(uint256 _tokenId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|veNFT token ID to reset|


### depositManaged

Deposits veNFT into a managed NFT

*NFT will be re-locked to max time on withdrawal*


```solidity
function depositManaged(uint256 _tokenId, uint256 _mTokenId) external;
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
function withdrawManaged(uint256 _tokenId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|veNFT token ID to withdraw|


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


### setMaxVotingNum

Updates maximum allowed votes per voter


```solidity
function setMaxVotingNum(uint256 _maxVotingNum) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_maxVotingNum`|`uint256`|New maximum number of allowed votes|


### whitelistNFT

Updates whitelist status for veNFT for privileged voting


```solidity
function whitelistNFT(uint256 _tokenId, bool _bool) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|veNFT token ID to update|
|`_bool`|`bool`|New whitelist status|


### createBribeVault

Creates new bribe vault for staking token


```solidity
function createBribeVault(
    address _stakingToken,
    address[] calldata _rewardTokens
) external returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_stakingToken`|`address`|Address of staking token|
|`_rewardTokens`|`address[]`|Array of reward token addresses|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Address of created bribe vault|


### killBribeVault

Disables a bribe vault


```solidity
function killBribeVault(address _stakingToken) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_stakingToken`|`address`|Address of staking token for vault to disable|


### reviveBribeVault

Re-enables a disabled bribe vault


```solidity
function reviveBribeVault(address _stakingToken) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_stakingToken`|`address`|Address of staking token for vault to re-enable|


## Events
### BribeVaultCreated
Emitted when a new bribe vault is created


```solidity
event BribeVaultCreated(
    address stakingToken, address bribeVault, address creator
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`stakingToken`|`address`|The staking token address for which the vault was created|
|`bribeVault`|`address`|The address of the newly created bribe vault|
|`creator`|`address`|The address that created the bribe vault|

### BribeVaultKilled
Emitted when a bribe vault is killed (disabled)


```solidity
event BribeVaultKilled(address indexed bribeVault);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`bribeVault`|`address`|The address of the killed bribe vault|

### BribeVaultRevived
Emitted when a killed bribe vault is revived (re-enabled)


```solidity
event BribeVaultRevived(address indexed bribeVault);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`bribeVault`|`address`|The address of the revived bribe vault|

### Voted
Emitted when votes are cast for a staking token


```solidity
event Voted(
    address indexed voter,
    address indexed stakingToken,
    uint256 indexed tokenId,
    uint256 weight,
    uint256 totalWeight,
    uint256 timestamp
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`voter`|`address`|Address of the account casting the vote|
|`stakingToken`|`address`|The staking token being voted for|
|`tokenId`|`uint256`|ID of the veNFT used to vote|
|`weight`|`uint256`|Vote weight allocated|
|`totalWeight`|`uint256`|New total vote weight for the staking token|
|`timestamp`|`uint256`|Block timestamp when vote was cast|

### Abstained
Emitted when votes are withdrawn/reset


```solidity
event Abstained(
    address indexed voter,
    address indexed stakingToken,
    uint256 indexed tokenId,
    uint256 weight,
    uint256 totalWeight,
    uint256 timestamp
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`voter`|`address`|Address of the account withdrawing votes|
|`stakingToken`|`address`|The staking token votes are withdrawn from|
|`tokenId`|`uint256`|ID of the veNFT used to vote|
|`weight`|`uint256`|Vote weight withdrawn|
|`totalWeight`|`uint256`|New total vote weight for the staking token|
|`timestamp`|`uint256`|Block timestamp when votes were withdrawn|

### WhitelistToken
Emitted when a token's whitelist status changes


```solidity
event WhitelistToken(
    address indexed whitelister, address indexed token, bool indexed _bool
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`whitelister`|`address`|Address making the whitelist change|
|`token`|`address`|Token address being whitelisted/unwhitelisted|
|`_bool`|`bool`|New whitelist status|

### WhitelistNFT
Emitted when an NFT's whitelist status changes


```solidity
event WhitelistNFT(
    address indexed whitelister, uint256 indexed tokenId, bool indexed _bool
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`whitelister`|`address`|Address making the whitelist change|
|`tokenId`|`uint256`|ID of the NFT being whitelisted/unwhitelisted|
|`_bool`|`bool`|New whitelist status|

## Errors
### AlreadyVotedOrDeposited

```solidity
error AlreadyVotedOrDeposited();
```

### BribeVaultAlreadyKilled

```solidity
error BribeVaultAlreadyKilled();
```

### BribeVaultAlreadyRevived

```solidity
error BribeVaultAlreadyRevived();
```

### BribeVaultExists

```solidity
error BribeVaultExists();
```

### BribeVaultDoesNotExist

```solidity
error BribeVaultDoesNotExist(address _stakingToken);
```

### BribeVaultNotAlive

```solidity
error BribeVaultNotAlive(address _stakingToken);
```

### InactiveManagedNFT

```solidity
error InactiveManagedNFT();
```

### MaximumVotingNumberTooLow

```solidity
error MaximumVotingNumberTooLow();
```

### NonZeroVotes

```solidity
error NonZeroVotes();
```

### NotAStakingToken

```solidity
error NotAStakingToken();
```

### NotApprovedOrOwner

```solidity
error NotApprovedOrOwner();
```

### NotWhitelistedNFT

```solidity
error NotWhitelistedNFT();
```

### NotWhitelistedToken

```solidity
error NotWhitelistedToken();
```

### SameValue

```solidity
error SameValue();
```

### SpecialVotingWindow

```solidity
error SpecialVotingWindow();
```

### TooManyStakingTokens

```solidity
error TooManyStakingTokens();
```

### UnequalLengths

```solidity
error UnequalLengths();
```

### ZeroBalance

```solidity
error ZeroBalance();
```

### ZeroAddress

```solidity
error ZeroAddress();
```

### VaultNotRegistered

```solidity
error VaultNotRegistered();
```

### NotGovernor

```solidity
error NotGovernor();
```

### DistributeWindow

```solidity
error DistributeWindow();
```

