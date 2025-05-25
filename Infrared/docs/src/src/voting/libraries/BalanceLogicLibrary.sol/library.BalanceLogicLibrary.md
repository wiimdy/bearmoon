# BalanceLogicLibrary
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/voting/libraries/BalanceLogicLibrary.sol)


## State Variables
### WEEK

```solidity
uint256 internal constant WEEK = 1 weeks;
```


## Functions
### getPastUserPointIndex

Binary search to get the user point index for a token id at or prior to a given timestamp

*If a user point does not exist prior to the timestamp, this will return 0.*


```solidity
function getPastUserPointIndex(
    mapping(uint256 => uint256) storage _userPointEpoch,
    mapping(uint256 => IVotingEscrow.UserPoint[1000000000]) storage
        _userPointHistory,
    uint256 _tokenId,
    uint256 _timestamp
) internal view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_userPointEpoch`|`mapping(uint256 => uint256)`|State of all user point epochs|
|`_userPointHistory`|`mapping(uint256 => IVotingEscrow.UserPoint[1000000000])`|State of all user point history|
|`_tokenId`|`uint256`|.|
|`_timestamp`|`uint256`|.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|User point index|


### getPastGlobalPointIndex

Binary search to get the global point index at or prior to a given timestamp

*If a checkpoint does not exist prior to the timestamp, this will return 0.*


```solidity
function getPastGlobalPointIndex(
    uint256 _epoch,
    mapping(uint256 => IVotingEscrow.GlobalPoint) storage _pointHistory,
    uint256 _timestamp
) internal view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_epoch`|`uint256`|Current global point epoch|
|`_pointHistory`|`mapping(uint256 => IVotingEscrow.GlobalPoint)`|State of all global point history|
|`_timestamp`|`uint256`|.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Global point index|


### balanceOfNFTAt

Get the current voting power for `_tokenId`

*Adheres to the ERC20 `balanceOf` interface for Aragon compatibility
Fetches last user point prior to a certain timestamp, then walks forward to timestamp.*


```solidity
function balanceOfNFTAt(
    mapping(uint256 => uint256) storage _userPointEpoch,
    mapping(uint256 => IVotingEscrow.UserPoint[1000000000]) storage
        _userPointHistory,
    uint256 _tokenId,
    uint256 _t
) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_userPointEpoch`|`mapping(uint256 => uint256)`|State of all user point epochs|
|`_userPointHistory`|`mapping(uint256 => IVotingEscrow.UserPoint[1000000000])`|State of all user point history|
|`_tokenId`|`uint256`|NFT for lock|
|`_t`|`uint256`|Epoch time to return voting power at|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|User voting power|


### supplyAt

Calculate total voting power at some point in the past


```solidity
function supplyAt(
    mapping(uint256 => int128) storage _slopeChanges,
    mapping(uint256 => IVotingEscrow.GlobalPoint) storage _pointHistory,
    uint256 _epoch,
    uint256 _t
) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_slopeChanges`|`mapping(uint256 => int128)`|State of all slopeChanges|
|`_pointHistory`|`mapping(uint256 => IVotingEscrow.GlobalPoint)`|State of all global point history|
|`_epoch`|`uint256`|The epoch to start search from|
|`_t`|`uint256`|Time to calculate the total voting power at|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total voting power at that time|


