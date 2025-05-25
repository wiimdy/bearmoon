# IMultiRewards
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/interfaces/IMultiRewards.sol)


## Functions
### totalSupply

Returns the total amount of staked tokens in the contract


```solidity
function totalSupply() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 The total supply of staked tokens|


### stake

Stakes tokens into the contract

*Transfers `amount` of staking tokens from the user to this contract*


```solidity
function stake(uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of tokens to stake|


### withdraw

Withdraws staked tokens from the contract

*Transfers `amount` of staking tokens back to the user*


```solidity
function withdraw(uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of tokens to withdraw|


### getReward

Claims all pending rewards for the caller

*Transfers all accrued rewards to the caller*


```solidity
function getReward() external;
```

### exit

Withdraws all staked tokens and claims pending rewards

*Combines withdraw and getReward operations*


```solidity
function exit() external;
```

### balanceOf

Returns the balance of staked tokens for the given account


```solidity
function balanceOf(address account) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account to get the balance for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The balance of staked tokens|


### lastTimeRewardApplicable

Calculates the last time reward is applicable for a given rewards token


```solidity
function lastTimeRewardApplicable(address _rewardsToken)
    external
    view
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_rewardsToken`|`address`|The address of the rewards token|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The timestamp when the reward was last applicable|


### rewardPerToken

Calculates the reward per token for a given rewards token


```solidity
function rewardPerToken(address _rewardsToken)
    external
    view
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_rewardsToken`|`address`|The address of the rewards token|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The reward amount per token|


### earned

Calculates the earned rewards for a given account and rewards token


```solidity
function earned(address account, address _rewardsToken)
    external
    view
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The address of the account|
|`_rewardsToken`|`address`|The address of the rewards token|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of rewards earned|


### getRewardForDuration

Calculates the total reward for the duration of a given rewards token


```solidity
function getRewardForDuration(address _rewardsToken)
    external
    view
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_rewardsToken`|`address`|The address of the rewards token|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total reward amount for the duration of a given rewards token|


### rewardData

Gets the reward data for a given rewards token


```solidity
function rewardData(address _rewardsToken)
    external
    view
    returns (
        address rewardsDistributor,
        uint256 rewardsDuration,
        uint256 periodFinish,
        uint256 rewardRate,
        uint256 lastUpdateTime,
        uint256 rewardPerTokenStored
    );
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_rewardsToken`|`address`|The address of the rewards token|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`rewardsDistributor`|`address`|The address authorized to distribute rewards|
|`rewardsDuration`|`uint256`|The duration of the reward period|
|`periodFinish`|`uint256`|The timestamp when rewards finish|
|`rewardRate`|`uint256`|The rate of rewards distributed per second|
|`lastUpdateTime`|`uint256`|The last time rewards were updated|
|`rewardPerTokenStored`|`uint256`|The last calculated reward per token|


### rewardTokens

Returns the reward token address at a specific index


```solidity
function rewardTokens(uint256 index) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The index in the reward tokens array|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the reward token at the given index|


### getRewardForUser

Claims all pending rewards for a specified user

*Iterates through all reward tokens and transfers any accrued rewards to the user*


```solidity
function getRewardForUser(address _user) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_user`|`address`|The address of the user to claim rewards for|


## Events
### Staked
Emitted when tokens are staked


```solidity
event Staked(address indexed user, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user who staked|
|`amount`|`uint256`|The amount of tokens staked|

### Withdrawn
Emitted when tokens are withdrawn


```solidity
event Withdrawn(address indexed user, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user who withdrew|
|`amount`|`uint256`|The amount of tokens withdrawn|

### RewardPaid
Emitted when rewards are claimed


```solidity
event RewardPaid(
    address indexed user, address indexed rewardsToken, uint256 reward
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user claiming the reward|
|`rewardsToken`|`address`|The address of the reward token|
|`reward`|`uint256`|The amount of rewards claimed|

### RewardAdded
Emitted when rewards are added to the contract


```solidity
event RewardAdded(address indexed rewardsToken, uint256 reward);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rewardsToken`|`address`|The address of the reward token|
|`reward`|`uint256`|The amount of rewards added|

### RewardsDistributorUpdated
Emitted when a rewards distributor is updaRewardAddedd


```solidity
event RewardsDistributorUpdated(
    address indexed rewardsToken, address indexed newDistributor
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rewardsToken`|`address`|The address of the reward token|
|`newDistributor`|`address`|The address of the new distributor|

### RewardsDurationUpdated
Emitted when the rewards duration for a token is updated


```solidity
event RewardsDurationUpdated(address token, uint256 newDuration);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|The reward token address whose duration was updated|
|`newDuration`|`uint256`|The new duration set for the rewards period|

### Recovered
Emitted when tokens are recovered from the contract


```solidity
event Recovered(address token, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|The address of the token that was recovered|
|`amount`|`uint256`|The amount of tokens that were recovered|

### RewardStored
Emitted when new reward data is stored


```solidity
event RewardStored(address rewardsToken, uint256 rewardsDuration);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rewardsToken`|`address`|The address of the reward token|
|`rewardsDuration`|`uint256`|The duration set for the reward period|

## Structs
### Reward
Reward data for a particular reward token

*Struct containing all relevant information for reward distribution*


```solidity
struct Reward {
    address rewardsDistributor;
    uint256 rewardsDuration;
    uint256 periodFinish;
    uint256 rewardRate;
    uint256 lastUpdateTime;
    uint256 rewardPerTokenStored;
}
```

