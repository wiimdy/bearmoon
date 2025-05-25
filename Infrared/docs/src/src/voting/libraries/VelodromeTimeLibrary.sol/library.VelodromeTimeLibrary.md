# VelodromeTimeLibrary
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/voting/libraries/VelodromeTimeLibrary.sol)


## State Variables
### WEEK

```solidity
uint256 internal constant WEEK = 7 days;
```


## Functions
### epochStart

Calculate the start of the current epoch based on the timestamp provided

*Epochs are aligned to weekly intervals, with each epoch starting at midnight UTC.*


```solidity
function epochStart(uint256 timestamp) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timestamp`|`uint256`|The current timestamp to align|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The start timestamp of the epoch week|


### epochNext

Calculate the start of the next epoch or end of the current epoch

*Returns the timestamp at the start of the next weekly epoch following the given timestamp.*


```solidity
function epochNext(uint256 timestamp) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timestamp`|`uint256`|The current timestamp|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The start timestamp of the next epoch|


### epochVoteStart

Determine the start of the voting window for the current epoch

*Voting windows start one hour into the weekly epoch.*


```solidity
function epochVoteStart(uint256 timestamp) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timestamp`|`uint256`|The timestamp to calculate from|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The start timestamp of the voting window within the epoch|


### epochVoteEnd

Calculate the end of the voting window within the current epoch

*Voting windows close one hour before the next epoch begins.*


```solidity
function epochVoteEnd(uint256 timestamp) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timestamp`|`uint256`|The timestamp to calculate from|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The end timestamp of the voting window within the epoch|


