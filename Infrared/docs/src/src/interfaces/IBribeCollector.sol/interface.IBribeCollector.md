# IBribeCollector
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/interfaces/IBribeCollector.sol)

**Inherits:**
IPOLErrors


## Functions
### payoutToken

Token used for fee payments when claiming bribes


```solidity
function payoutToken() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Address of the payout token|


### payoutAmount

The amount of payout token that is required to claim POL bribes for all tokens

*This works as first come first serve basis. whoever pays this much amount of the payout amount first will
get the fees*


```solidity
function payoutAmount() external view returns (uint256);
```

### setPayoutAmount

Update the payout amount to a new value. Must be called by governor


```solidity
function setPayoutAmount(uint256 _newPayoutAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newPayoutAmount`|`uint256`|The value that will be the new payout amount|


### claimFees

Claims accumulated bribes in exchange for payout token

*Caller must approve payoutAmount of payout token to this contract.*


```solidity
function claimFees(address recipient, address[] calldata feeTokens) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The Address to receive claimed tokens|
|`feeTokens`|`address[]`|Array of token addresses to claim|


## Events
### PayoutAmountSet
Emitted when the payout amount is updated by the governor


```solidity
event PayoutAmountSet(
    uint256 indexed oldPayoutAmount, uint256 indexed newPayoutAmount
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldPayoutAmount`|`uint256`|Previous payout amount|
|`newPayoutAmount`|`uint256`|New payout amount set|

### FeesClaimed
Emitted when the fees are claimed


```solidity
event FeesClaimed(
    address indexed caller,
    address indexed recipient,
    address indexed feeToken,
    uint256 amount
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`caller`|`address`|Caller of the `claimFees` function|
|`recipient`|`address`|The address to which collected POL bribes will be transferred|
|`feeToken`|`address`|The address of the fee token to collect|
|`amount`|`uint256`|The amount of fee token to transfer|

