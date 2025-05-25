# Reward
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/voting/rewards/Reward.sol)

**Inherits:**
[IReward](/src/voting/interfaces/IReward.sol/interface.IReward.md), ReentrancyGuard

**Author:**
velodrome.finance, @figs999, @pegahcarter

Base implementation for reward distribution contracts

*Abstract contract providing core reward distribution functionality*


## State Variables
### DURATION
Duration of each reward epoch in seconds


```solidity
uint256 public constant DURATION = 7 days;
```


### voter
Address of the Voter contract that manages rewards


```solidity
address public immutable voter;
```


### ve
Address of the VotingEscrow contract that manages veNFTs


```solidity
address public immutable ve;
```


### authorized
Address permitted to call privileged state-changing functions


```solidity
address public authorized;
```


### totalSupply
Total amount of staking tokens locked in contract


```solidity
uint256 public totalSupply;
```


### supplyNumCheckpoints
Total number of supply checkpoints recorded


```solidity
uint256 public supplyNumCheckpoints;
```


### rewards
List of all reward tokens supported by this contract

*Used for token enumeration and management*


```solidity
address[] public rewards;
```


### balanceOf
Retrieves current staked balance for a veNFT


```solidity
mapping(uint256 => uint256) public balanceOf;
```


### tokenRewardsPerEpoch
Gets reward amount allocated for a specific epoch


```solidity
mapping(address => mapping(uint256 => uint256)) public tokenRewardsPerEpoch;
```


### lastEarn
Retrieves timestamp of last reward claim for a veNFT


```solidity
mapping(address => mapping(uint256 => uint256)) public lastEarn;
```


### isReward
Checks if a token is configured as a reward token


```solidity
mapping(address => bool) public isReward;
```


### checkpoints
A record of balance checkpoints for each account, by index


```solidity
mapping(uint256 => mapping(uint256 => Checkpoint)) public checkpoints;
```


### numCheckpoints
Number of balance checkpoints for a veNFT


```solidity
mapping(uint256 => uint256) public numCheckpoints;
```


### supplyCheckpoints
A record of balance checkpoints for each token, by index


```solidity
mapping(uint256 => SupplyCheckpoint) public supplyCheckpoints;
```


## Functions
### constructor

Initializes reward contract with voter address


```solidity
constructor(address _voter);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_voter`|`address`|Address of voter contract managing rewards|


### getPriorBalanceIndex

Gets historical balance index for a veNFT at timestamp

*Uses binary search to find checkpoint index*


```solidity
function getPriorBalanceIndex(uint256 tokenId, uint256 timestamp)
    public
    view
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|ID of veNFT to query|
|`timestamp`|`uint256`|Time to query balance at|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Index of nearest checkpoint before timestamp|


### getPriorSupplyIndex

Gets historical supply index at timestamp

*Uses binary search to find checkpoint index*


```solidity
function getPriorSupplyIndex(uint256 timestamp) public view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timestamp`|`uint256`|Time to query supply at|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Index of nearest checkpoint before timestamp|


### _writeCheckpoint

Writes user checkpoint with updated balance

*Updates or creates checkpoint based on epoch timing*


```solidity
function _writeCheckpoint(uint256 tokenId, uint256 balance) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|ID of veNFT to checkpoint|
|`balance`|`uint256`|New balance to record|


### _writeSupplyCheckpoint

Writes global supply checkpoint

*Updates or creates checkpoint based on epoch timing*


```solidity
function _writeSupplyCheckpoint() internal;
```

### rewardsListLength

Number of tokens configured for rewards


```solidity
function rewardsListLength() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Length of rewards token list|


### earned

Calculates unclaimed rewards for a veNFT


```solidity
function earned(address token, uint256 tokenId) public view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Address of reward token to calculate|
|`tokenId`|`uint256`|ID of veNFT to calculate for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Amount of unclaimed rewards|


### _deposit

Records a token deposit and updates checkpoints

*Can only be called by authorized address*


```solidity
function _deposit(uint256 amount, uint256 tokenId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of tokens being deposited|
|`tokenId`|`uint256`|ID of veNFT receiving deposit|


### _withdraw

Records a token withdrawal and updates checkpoints

*Can only be called by authorized address*


```solidity
function _withdraw(uint256 amount, uint256 tokenId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of tokens being withdrawn|
|`tokenId`|`uint256`|ID of veNFT withdrawing from|


### getReward

Claims accumulated rewards for a veNFT


```solidity
function getReward(uint256 tokenId, address[] memory tokens)
    external
    virtual
    nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|ID of veNFT claiming rewards|
|`tokens`|`address[]`|Array of reward token addresses to claim|


### _getReward

Internal helper for processing reward claims

*Calculates and transfers earned rewards to recipient*


```solidity
function _getReward(address recipient, uint256 tokenId, address[] memory tokens)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|Address to receive claimed rewards|
|`tokenId`|`uint256`|ID of veNFT claiming rewards|
|`tokens`|`address[]`|Array of reward tokens to claim|


### notifyRewardAmount

Adds new reward tokens for distribution

*Transfers tokens from caller and updates reward accounting*


```solidity
function notifyRewardAmount(address token, uint256 amount)
    external
    virtual
    nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Address of token to add as reward|
|`amount`|`uint256`|Amount of token to add to rewards|


### _notifyRewardAmount

Internal helper for adding rewards

*Transfers tokens and updates reward accounting*


```solidity
function _notifyRewardAmount(address sender, address token, uint256 amount)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sender`|`address`|Address providing reward tokens|
|`token`|`address`|Address of reward token|
|`amount`|`uint256`|Amount of tokens to add as rewards|


