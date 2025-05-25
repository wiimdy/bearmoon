# IInfraredDistributor
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/interfaces/IInfraredDistributor.sol)

Interface for distributing validator commissions and rewards

*Handles reward distribution snapshots and claiming logic for validators*


## Functions
### token

Token used for reward distributions


```solidity
function token() external view returns (IERC20);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IERC20`|The ERC20 token interface of the reward token|


### amountsCumulative

Tracks reward amount accumulation per validator


```solidity
function amountsCumulative() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Current cumulative amount of rewards|


### snapshots

Get validator's reward snapshots

*Returns (0,0) if validator doesn't exist*


```solidity
function snapshots(bytes calldata pubkey)
    external
    view
    returns (uint256 amountCumulativeLast, uint256 amountCumulativeFinal);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pubkey`|`bytes`|Validator's public key|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amountCumulativeLast`|`uint256`|Last claimed accumulator value|
|`amountCumulativeFinal`|`uint256`|Final accumulator value if removed|


### validators

Get validator's registered claim address


```solidity
function validators(bytes calldata pubkey) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pubkey`|`bytes`|Validator's public key|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Address authorized to claim validator rewards|


### add

Register new validator for rewards

*Only callable by Infrared contract*

**Notes:**
- Requires INFRARED_ROLE

- ValidatorAlreadyExists if validator already registered


```solidity
function add(bytes calldata pubkey, address validator) external;
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
function remove(bytes calldata pubkey) external;
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

**Notes:**
- ZeroAmount if amount is 0

- InvalidValidator if no validators exist


```solidity
function notifyRewardAmount(uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount to distribute equally among validators|


### claim

Claims outstanding commission rewards

**Notes:**
- InvalidValidator if caller not authorized

- ZeroAmount if no rewards to claim


```solidity
function claim(bytes calldata pubkey, address recipient) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pubkey`|`bytes`|Validator's public key|
|`recipient`|`address`|Address to receive the claimed rewards|


## Events
### Added
Emitted when validator is added to commission-eligible set


```solidity
event Added(bytes pubkey, address operator, uint256 amountCumulative);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pubkey`|`bytes`|Validator's public key|
|`operator`|`address`|Address authorized to claim rewards|
|`amountCumulative`|`uint256`|Starting point for commission stream|

### Removed
Emitted when validator is removed from commission-eligible set


```solidity
event Removed(bytes pubkey, address operator, uint256 amountCumulative);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pubkey`|`bytes`|Validator's public key|
|`operator`|`address`|Address previously authorized for claims|
|`amountCumulative`|`uint256`|Final point for commission stream|

### Purged
Emitted when validator is fully purged from registry


```solidity
event Purged(bytes pubkey, address validator);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pubkey`|`bytes`|Validator's public key|
|`validator`|`address`|Address being purged|

### Notified
Emitted when new commission rewards are added


```solidity
event Notified(uint256 amount, uint256 num);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|New rewards being distributed|
|`num`|`uint256`|Current number of eligible validators|

### Claimed
Emitted when validator claims their commission


```solidity
event Claimed(
    bytes pubkey, address validator, address recipient, uint256 amount
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pubkey`|`bytes`|Claiming validator's public key|
|`validator`|`address`|Address authorized for claims|
|`recipient`|`address`|Address receiving the commission|
|`amount`|`uint256`|Amount of commission claimed|

## Structs
### Snapshot
Reward accumulation checkpoints for validators

*Used to calculate claimable rewards between snapshots*


```solidity
struct Snapshot {
    uint256 amountCumulativeLast;
    uint256 amountCumulativeFinal;
}
```

