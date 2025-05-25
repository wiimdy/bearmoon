# InfraredVault
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/core/InfraredVault.sol)

**Inherits:**
[MultiRewards](/src/core/MultiRewards.sol/abstract.MultiRewards.md), [IInfraredVault](/src/interfaces/IInfraredVault.sol/interface.IInfraredVault.md)

This contract is the vault for staking tokens, and receiving rewards from the Proof of Liquidity protocol.

*This contract uses the MultiRewards contract to distribute rewards to vault stakers, this is taken from curve.fi. (inspired by Synthetix).*

*Does not support staking tokens with non-standard ERC20 transfer tax behavior.*


## State Variables
### MAX_NUM_REWARD_TOKENS
Maximum number of reward tokens that can be supported

*Limited to prevent gas issues with reward calculations*


```solidity
uint256 public constant MAX_NUM_REWARD_TOKENS = 10;
```


### infrared
The infrared contract address acts a vault factory and coordinator


```solidity
address public immutable infrared;
```


### rewardsVault

```solidity
IBerachainRewardsVault public rewardsVault;
```


## Functions
### onlyInfrared

Modifier to check that the caller is infrared contract


```solidity
modifier onlyInfrared();
```

### constructor


```solidity
constructor(
    address _stakingToken,
    address[] memory _rewardTokens,
    uint256 _rewardsDuration
) MultiRewards(_stakingToken);
```

### _createRewardsVaultIfNecessary

Gets or creates the berachain rewards vault for given staking token


```solidity
function _createRewardsVaultIfNecessary(
    address _infrared,
    address _stakingToken
) private returns (IBerachainRewardsVault);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_infrared`|`address`|The address of Infrared|
|`_stakingToken`|`address`|The address of the staking token for this vault|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IBerachainRewardsVault`|The address of the berachain rewards vault|


### onStake

Transfers to berachain low level module on staking of LP tokens with the vault after transferring tokens in


```solidity
function onStake(uint256 amount) internal override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of staking token transferred in to the contract|


### onWithdraw

Redeems from berachain low level module on withdraw of LP tokens from the vault before transferring tokens out


```solidity
function onWithdraw(uint256 amount) internal override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of staking token transferred out of the contract|


### onReward

hook called after the reward is claimed to harvest the rewards from the berachain rewards vault


```solidity
function onReward() internal override;
```

### updateRewardsDuration

Updates reward duration for a specific reward token

*Only callable by Infrared contract*

**Note:**
Requires INFRARED_ROLE


```solidity
function updateRewardsDuration(address _rewardsToken, uint256 _rewardsDuration)
    external
    onlyInfrared;
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
function togglePause() external onlyInfrared;
```

### addReward

Adds a new reward token to the vault

*Cannot exceed maximum number of reward tokens*

**Note:**
Requires INFRARED_ROLE


```solidity
function addReward(address _rewardsToken, uint256 _rewardsDuration)
    external
    onlyInfrared;
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
function notifyRewardAmount(address _rewardToken, uint256 _reward)
    external
    onlyInfrared;
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
function recoverERC20(address _to, address _token, uint256 _amount)
    external
    onlyInfrared;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_to`|`address`|The address to receive the recovered tokens|
|`_token`|`address`|The token to recover|
|`_amount`|`uint256`|The amount to recover|


