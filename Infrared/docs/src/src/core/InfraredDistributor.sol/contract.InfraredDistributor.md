# InfraredDistributor
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/core/InfraredDistributor.sol)

**Inherits:**
[InfraredUpgradeable](/src/core/InfraredUpgradeable.sol/abstract.InfraredUpgradeable.md), [IInfraredDistributor](/src/interfaces/IInfraredDistributor.sol/interface.IInfraredDistributor.md)

A contract for distributing rewards in a single ERC20 token (iBGT) to validators


## State Variables
### token
Token used for reward distributions


```solidity
IERC20 public token;
```


### amountsCumulative
Tracks reward amount accumulation per validator


```solidity
uint256 public amountsCumulative;
```


### snapshots
Get validator's reward snapshots

*Returns (0,0) if validator doesn't exist*


```solidity
mapping(bytes pubkey => Snapshot) public snapshots;
```


### validators
Get validator's registered claim address


```solidity
mapping(bytes pubkey => address) public validators;
```


## Functions
### constructor


```solidity
constructor(address _infrared) InfraredUpgradeable(_infrared);
```

### initialize


```solidity
function initialize() external initializer;
```

### add

Register new validator for rewards

*Only callable by Infrared contract*

**Notes:**
- Requires INFRARED_ROLE

- ValidatorAlreadyExists if validator already registered


```solidity
function add(bytes calldata pubkey, address validator) external onlyInfrared;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pubkey`|`bytes`|Validator's public key|
|`validator`|`address`|Address authorized to claim rewards|


### remove

Removes validator from reward-eligible set

*Only callable by Infrared contract*

**Note:**
Requires INFRARED_ROLE


```solidity
function remove(bytes calldata pubkey) external onlyInfrared;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pubkey`|`bytes`|Validator's public key|


### purge

Purges validator from registry completely

*Only possible after all rewards are claimed*

**Note:**
ClaimableRewardsExist if unclaimed rewards remain


```solidity
function purge(bytes calldata pubkey) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pubkey`|`bytes`|Validator's public key|


### notifyRewardAmount

Distributes new commission rewards to validator set

**Note:**
ZeroAmount if amount is 0


```solidity
function notifyRewardAmount(uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount to distribute equally among validators|


### claim

Claims outstanding commission rewards

**Note:**
InvalidValidator if caller not authorized


```solidity
function claim(bytes calldata pubkey, address recipient) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pubkey`|`bytes`|Validator's public key|
|`recipient`|`address`|Address to receive the claimed rewards|


