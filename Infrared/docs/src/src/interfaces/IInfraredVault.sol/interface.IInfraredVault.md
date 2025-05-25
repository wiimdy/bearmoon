# IInfraredVault
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/interfaces/IInfraredVault.sol)

**Inherits:**
[IMultiRewards](/src/interfaces/IMultiRewards.sol/interface.IMultiRewards.md)


## Functions
### infrared

Returns the Infrared protocol coordinator


```solidity
function infrared() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the Infrared contract|


### rewardsVault

Returns the associated Berachain rewards vault


```solidity
function rewardsVault() external view returns (IBerachainRewardsVault);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IBerachainRewardsVault`|The rewards vault contract instance|


### updateRewardsDuration

Updates reward duration for a specific reward token

*Only callable by Infrared contract*

**Note:**
Requires INFRARED_ROLE


```solidity
function updateRewardsDuration(address _rewardsToken, uint256 _rewardsDuration)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_rewardsToken`|`address`|The address of the reward token|
|`_rewardsDuration`|`uint256`|The new duration in seconds|


### togglePause

Toggles pause state of the vault

*Affects all vault operations when paused*

**Note:**
Requires INFRARED_ROLE


```solidity
function togglePause() external;
```

### addReward

Adds a new reward token to the vault

*Cannot exceed maximum number of reward tokens*

**Note:**
Requires INFRARED_ROLE


```solidity
function addReward(address _rewardsToken, uint256 _rewardsDuration) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_rewardsToken`|`address`|The reward token to add|
|`_rewardsDuration`|`uint256`|The reward period duration|


### notifyRewardAmount

Notifies the vault of newly added rewards

*Updates internal reward rate calculations*


```solidity
function notifyRewardAmount(address _rewardToken, uint256 _reward) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_rewardToken`|`address`|The reward token address|
|`_reward`|`uint256`|The amount of new rewards|


### recoverERC20

Recovers accidentally sent tokens

*Cannot recover staking token or active reward tokens*


```solidity
function recoverERC20(address _to, address _token, uint256 _amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_to`|`address`|The address to receive the recovered tokens|
|`_token`|`address`|The token to recover|
|`_amount`|`uint256`|The amount to recover|


