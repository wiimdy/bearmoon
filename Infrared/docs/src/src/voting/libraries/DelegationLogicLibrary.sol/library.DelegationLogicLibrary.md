# DelegationLogicLibrary
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/voting/libraries/DelegationLogicLibrary.sol)


## Functions
### checkpointDelegator

Used by `_mint`, `_transferFrom`, `_burn` and `delegate`
to update delegator voting checkpoints.
Automatically dedelegates, then updates checkpoint.

*This function depends on `_locked` and must be called prior to token state changes.
If you wish to dedelegate only, use `_delegate(tokenId, 0)` instead.*


```solidity
function checkpointDelegator(
    mapping(uint256 => IVotingEscrow.LockedBalance) storage _locked,
    mapping(uint256 => uint48) storage _numCheckpoints,
    mapping(uint256 => mapping(uint48 => IVotingEscrow.Checkpoint)) storage
        _checkpoints,
    mapping(uint256 => uint256) storage _delegates,
    uint256 _delegator,
    uint256 _delegatee,
    address _owner
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_locked`|`mapping(uint256 => IVotingEscrow.LockedBalance)`|State of all locked balances|
|`_numCheckpoints`|`mapping(uint256 => uint48)`|State of all user checkpoint counts|
|`_checkpoints`|`mapping(uint256 => mapping(uint48 => IVotingEscrow.Checkpoint))`|State of all user checkpoints|
|`_delegates`|`mapping(uint256 => uint256)`|State of all user delegatees|
|`_delegator`|`uint256`|The delegator to update checkpoints for|
|`_delegatee`|`uint256`|The new delegatee for the delegator. Cannot be equal to `_delegator` (use 0 instead).|
|`_owner`|`address`|The new (or current) owner for the delegator|


### checkpointDelegatee

Update delegatee's `delegatedBalance` by `balance`.
Only updates if delegating to a new delegatee.

*If used with `balance` == `_locked[_tokenId].amount`, then this is the same as
delegating or dedelegating from `_tokenId`
If used with `balance` < `_locked[_tokenId].amount`, then this is used to adjust
`delegatedBalance` when a user's balance is modified (e.g. `increaseAmount`, `merge` etc).
If `delegatee` is 0 (i.e. user is not delegating), then do nothing.*


```solidity
function checkpointDelegatee(
    mapping(uint256 => uint48) storage _numCheckpoints,
    mapping(uint256 => mapping(uint48 => IVotingEscrow.Checkpoint)) storage
        _checkpoints,
    uint256 _delegatee,
    uint256 balance_,
    bool _increase
) public;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_numCheckpoints`|`mapping(uint256 => uint48)`|State of all user checkpoint counts|
|`_checkpoints`|`mapping(uint256 => mapping(uint48 => IVotingEscrow.Checkpoint))`|State of all user checkpoints|
|`_delegatee`|`uint256`|The delegatee's tokenId|
|`balance_`|`uint256`|The delta in balance change|
|`_increase`|`bool`|True if balance is increasing, false if decreasing|


### _isCheckpointInNewBlock


```solidity
function _isCheckpointInNewBlock(
    mapping(uint256 => uint48) storage _numCheckpoints,
    mapping(uint256 => mapping(uint48 => IVotingEscrow.Checkpoint)) storage
        _checkpoints,
    uint256 _tokenId
) internal view returns (bool);
```

### getPastVotesIndex

Binary search to get the voting checkpoint for a token id at or prior to a given timestamp.

*If a checkpoint does not exist prior to the timestamp, this will return 0.*


```solidity
function getPastVotesIndex(
    mapping(uint256 => uint48) storage _numCheckpoints,
    mapping(uint256 => mapping(uint48 => IVotingEscrow.Checkpoint)) storage
        _checkpoints,
    uint256 _tokenId,
    uint256 _timestamp
) internal view returns (uint48);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_numCheckpoints`|`mapping(uint256 => uint48)`|State of all user checkpoint counts|
|`_checkpoints`|`mapping(uint256 => mapping(uint48 => IVotingEscrow.Checkpoint))`|State of all user checkpoints|
|`_tokenId`|`uint256`|.|
|`_timestamp`|`uint256`|.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint48`|The index of the checkpoint.|


### getPastVotes

Retrieves historical voting balance for a token id at a given timestamp.

*If a checkpoint does not exist prior to the timestamp, this will return 0.
The user must also own the token at the time in order to receive a voting balance.*


```solidity
function getPastVotes(
    mapping(uint256 => uint48) storage _numCheckpoints,
    mapping(uint256 => mapping(uint48 => IVotingEscrow.Checkpoint)) storage
        _checkpoints,
    address _account,
    uint256 _tokenId,
    uint256 _timestamp
) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_numCheckpoints`|`mapping(uint256 => uint48)`|State of all user checkpoint counts|
|`_checkpoints`|`mapping(uint256 => mapping(uint48 => IVotingEscrow.Checkpoint))`|State of all user checkpoints|
|`_account`|`address`|.|
|`_tokenId`|`uint256`|.|
|`_timestamp`|`uint256`|.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total voting balance including delegations at a given timestamp.|


