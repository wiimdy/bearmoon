# MultiRewards
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/core/MultiRewards.sol)

**Inherits:**
ReentrancyGuard, Pausable, [IMultiRewards](/src/interfaces/IMultiRewards.sol/interface.IMultiRewards.md)

*Fork of https://github.com/curvefi/multi-rewards with hooks on stake/withdraw of LP tokens*


## State Variables
### stakingToken
The token that users stake to earn rewards

*This is the base token that users deposit into the contract*


```solidity
IERC20 public stakingToken;
```


### rewardData
Stores reward-related data for each reward token

*Maps reward token addresses to their Reward struct containing distribution parameters*


```solidity
mapping(address => Reward) public override rewardData;
```


### rewardTokens
Array of all reward token addresses

*Used to iterate through all reward tokens when updating or claiming rewards*


```solidity
address[] public rewardTokens;
```


### userRewardPerTokenPaid
Tracks the reward per token paid to each user for each reward token

*Maps user address to reward token address to amount already paid
Used to calculate new rewards since last claim*


```solidity
mapping(address => mapping(address => uint256)) public userRewardPerTokenPaid;
```


### rewards
Tracks the unclaimed rewards for each user for each reward token

*Maps user address to reward token address to unclaimed amount*


```solidity
mapping(address => mapping(address => uint256)) public rewards;
```


### _totalSupply
The total amount of staking tokens in the contract

*Used to calculate rewards per token*


```solidity
uint256 internal _totalSupply;
```


### _balances
Maps user addresses to their staked token balance

*Internal mapping used to track individual stake amounts*


```solidity
mapping(address => uint256) internal _balances;
```


## Functions
### updateReward

Updates the reward for the given account before executing the
function body.


```solidity
modifier updateReward(address account);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|address The account to update the reward for.|


### constructor

Constructs the MultiRewards contract.


```solidity
constructor(address _stakingToken);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_stakingToken`|`address`|address The token that users stake to earn rewards.|


### totalSupply

Returns the total amount of staked tokens in the contract


```solidity
function totalSupply() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 The total supply of staked tokens|


### balanceOf

Returns the balance of staked tokens for the given account


```solidity
function balanceOf(address account) external view returns (uint256 _balance);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account to get the balance for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_balance`|`uint256`|The balance of staked tokens|


### lastTimeRewardApplicable

Calculates the last time reward is applicable for a given rewards token


```solidity
function lastTimeRewardApplicable(address _rewardsToken)
    public
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
function rewardPerToken(address _rewardsToken) public view returns (uint256);
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
    public
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


### stake

Stakes tokens into the contract

*Transfers `amount` of staking tokens from the user to this contract*


```solidity
function stake(uint256 amount)
    external
    nonReentrant
    whenNotPaused
    updateReward(msg.sender);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of tokens to stake|


### onStake

Hook called in the stake function after transfering staking token in


```solidity
function onStake(uint256 amount) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of staking token transferred in to the contract|


### withdraw

Withdraws staked tokens from the contract

*Transfers `amount` of staking tokens back to the user*


```solidity
function withdraw(uint256 amount)
    public
    nonReentrant
    updateReward(msg.sender);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of tokens to withdraw|


### onWithdraw

Hook called in withdraw function before transferring staking token out


```solidity
function onWithdraw(uint256 amount) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of staking token to be transferred out of the contract|


### getRewardForUser

Claims all pending rewards for a specified user

*Iterates through all reward tokens and transfers any accrued rewards to the user*


```solidity
function getRewardForUser(address _user)
    public
    nonReentrant
    updateReward(_user);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_user`|`address`|The address of the user to claim rewards for|


### onReward

Hook called in getRewardForUser function


```solidity
function onReward() internal virtual;
```

### getReward

Claims all pending rewards for the caller

*Transfers all accrued rewards to the caller*


```solidity
function getReward() public;
```

### exit

Withdraws all staked tokens and claims pending rewards

*Combines withdraw and getReward operations*


```solidity
function exit() external;
```

### _setRewardsDistributor

Sets the rewards distributor for a reward token.


```solidity
function _setRewardsDistributor(
    address _rewardsToken,
    address _rewardsDistributor
) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_rewardsToken`|`address`|      address The address of the reward token.|
|`_rewardsDistributor`|`address`|address The address of the rewards distributor.|


### _addReward

Adds a reward token to the contract.


```solidity
function _addReward(
    address _rewardsToken,
    address _rewardsDistributor,
    uint256 _rewardsDuration
) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_rewardsToken`|`address`|      address The address of the reward token.|
|`_rewardsDistributor`|`address`|address The address of the rewards distributor.|
|`_rewardsDuration`|`uint256`|   uint256 The duration of the rewards period.|


### _notifyRewardAmount

Notifies the contract that reward tokens is being sent to the contract.


```solidity
function _notifyRewardAmount(address _rewardsToken, uint256 reward)
    internal
    updateReward(address(0));
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_rewardsToken`|`address`|address The address of the reward token.|
|`reward`|`uint256`|       uint256 The amount of reward tokens is being sent to the contract.|


### _recoverERC20

Recovers ERC20 tokens sent to the contract.

*Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders*


```solidity
function _recoverERC20(address to, address tokenAddress, uint256 tokenAmount)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|          address The address to send the tokens to.|
|`tokenAddress`|`address`|address The address of the token to withdraw.|
|`tokenAmount`|`uint256`| uint256 The amount of tokens to withdraw.|


### _setRewardsDuration

Updates the reward duration for a reward token.


```solidity
function _setRewardsDuration(address _rewardsToken, uint256 _rewardsDuration)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_rewardsToken`|`address`|   address The address of the reward token.|
|`_rewardsDuration`|`uint256`|uint256 The new duration of the rewards period.|


