# IReward
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/voting/interfaces/IReward.sol)

Interface for rewards distribution contracts in the Infrared Voter

*Base interface implemented by all reward-type contracts*


## Functions
### DURATION

Duration of each reward epoch in seconds


```solidity
function DURATION() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Fixed duration of 7 days|


### voter

Address of the Voter contract that manages rewards


```solidity
function voter() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Voter contract address|


### ve

Address of the VotingEscrow contract that manages veNFTs


```solidity
function ve() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|VotingEscrow contract address|


### authorized

Address permitted to call privileged state-changing functions


```solidity
function authorized() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Authorized caller address|


### totalSupply

Total amount of staking tokens locked in contract


```solidity
function totalSupply() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Current total supply of staked tokens|


### balanceOf

Retrieves current staked balance for a veNFT


```solidity
function balanceOf(uint256 tokenId) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|ID of the veNFT to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Current staked token balance|


### tokenRewardsPerEpoch

Gets reward amount allocated for a specific epoch


```solidity
function tokenRewardsPerEpoch(address token, uint256 epochStart)
    external
    view
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Address of reward token|
|`epochStart`|`uint256`|Starting timestamp of epoch|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Amount of token allocated as rewards for the epoch|


### lastEarn

Retrieves timestamp of last reward claim for a veNFT


```solidity
function lastEarn(address token, uint256 tokenId)
    external
    view
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Address of reward token|
|`tokenId`|`uint256`|ID of veNFT that claimed|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Timestamp of last claim for this token/veNFT pair|


### isReward

Checks if a token is configured as a reward token


```solidity
function isReward(address token) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Address of token to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if token is active for rewards|


### numCheckpoints

Number of balance checkpoints for a veNFT


```solidity
function numCheckpoints(uint256 tokenId) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|ID of veNFT to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Number of checkpoints recorded|


### supplyNumCheckpoints

Total number of supply checkpoints recorded


```solidity
function supplyNumCheckpoints() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Count of global supply checkpoints|


### checkpoints

Gets balance checkpoint data for a veNFT at specific index


```solidity
function checkpoints(uint256 tokenId, uint256 index)
    external
    view
    returns (uint256 timestamp, uint256 balanceOf);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|ID of veNFT to query|
|`index`|`uint256`|Checkpoint index to read|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`timestamp`|`uint256`|Time checkpoint was created|
|`balanceOf`|`uint256`|Balance recorded at checkpoint|


### supplyCheckpoints

Gets total supply checkpoint data at specific index


```solidity
function supplyCheckpoints(uint256 index)
    external
    view
    returns (uint256 timestamp, uint256 supply);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|Checkpoint index to read|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`timestamp`|`uint256`|Time checkpoint was created|
|`supply`|`uint256`|Total supply recorded at checkpoint|


### getPriorBalanceIndex

Gets historical balance index for a veNFT at timestamp

*Uses binary search to find checkpoint index*


```solidity
function getPriorBalanceIndex(uint256 tokenId, uint256 timestamp)
    external
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
function getPriorSupplyIndex(uint256 timestamp)
    external
    view
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timestamp`|`uint256`|Time to query supply at|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Index of nearest checkpoint before timestamp|


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
function earned(address token, uint256 tokenId)
    external
    view
    returns (uint256);
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
function getReward(uint256 tokenId, address[] memory tokens) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|ID of veNFT claiming rewards|
|`tokens`|`address[]`|Array of reward token addresses to claim|


### notifyRewardAmount

Adds new reward tokens for distribution

*Transfers tokens from caller and updates reward accounting*


```solidity
function notifyRewardAmount(address token, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Address of token to add as reward|
|`amount`|`uint256`|Amount of token to add to rewards|


## Events
### Deposit
Emitted when tokens are deposited for rewards


```solidity
event Deposit(address indexed from, uint256 indexed tokenId, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|Address depositing tokens|
|`tokenId`|`uint256`|ID of the veNFT receiving deposit|
|`amount`|`uint256`|Amount of tokens deposited|

### Withdraw
Emitted when tokens are withdrawn from rewards


```solidity
event Withdraw(address indexed from, uint256 indexed tokenId, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|Address withdrawing tokens|
|`tokenId`|`uint256`|ID of the veNFT withdrawing from|
|`amount`|`uint256`|Amount of tokens withdrawn|

### NotifyReward
Emitted when new rewards are added


```solidity
event NotifyReward(
    address indexed from,
    address indexed reward,
    uint256 indexed epoch,
    uint256 amount
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|Address supplying the reward tokens|
|`reward`|`address`|Token being added as reward|
|`epoch`|`uint256`|Epoch timestamp for reward distribution|
|`amount`|`uint256`|Amount of reward tokens added|

### ClaimRewards
Emitted when rewards are claimed


```solidity
event ClaimRewards(
    address indexed from, address indexed reward, uint256 amount
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|Address claiming the rewards|
|`reward`|`address`|Token being claimed|
|`amount`|`uint256`|Amount of tokens claimed|

## Errors
### InvalidReward
Thrown when attempting to interact with an invalid reward token


```solidity
error InvalidReward();
```

### NotAuthorized
Thrown when caller is not authorized to perform operation


```solidity
error NotAuthorized();
```

### NotWhitelisted
Thrown when token is not in whitelist


```solidity
error NotWhitelisted();
```

### ZeroAmount
Thrown when attempting operation with zero amount


```solidity
error ZeroAmount();
```

## Structs
### Checkpoint
Balance checkpoint for tracking historical balances


```solidity
struct Checkpoint {
    uint256 timestamp;
    uint256 balanceOf;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`timestamp`|`uint256`|Time of checkpoint|
|`balanceOf`|`uint256`|Balance at checkpoint|

### SupplyCheckpoint
Supply checkpoint for tracking total supply


```solidity
struct SupplyCheckpoint {
    uint256 timestamp;
    uint256 supply;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`timestamp`|`uint256`|Time of checkpoint|
|`supply`|`uint256`|Total supply at checkpoint|

