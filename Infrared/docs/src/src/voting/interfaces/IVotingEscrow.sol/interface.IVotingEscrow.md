# IVotingEscrow
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/voting/interfaces/IVotingEscrow.sol)

**Inherits:**
[IVotes](/src/voting/interfaces/IVotes.sol/interface.IVotes.md), IERC4906, IERC6372, IERC721Metadata


## Functions
### token

Address of token (VELO) used to create a veNFT


```solidity
function token() external view returns (address);
```

### distributor

Address of RewardsDistributor.sol


```solidity
function distributor() external view returns (address);
```

### voter

Address of Voter.sol


```solidity
function voter() external view returns (address);
```

### team

Address of Velodrome Team multisig


```solidity
function team() external view returns (address);
```

### artProxy

Address of art proxy used for on-chain art generation


```solidity
function artProxy() external view returns (address);
```

### allowedManager

*address which can create managed NFTs*


```solidity
function allowedManager() external view returns (address);
```

### tokenId

*Current count of token*


```solidity
function tokenId() external view returns (uint256);
```

### infrared

Address of Infrared contract


```solidity
function infrared() external view returns (IInfrared);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IInfrared`|IInfrared instance of contract address|


### escrowType

*Mapping of token id to escrow type
Takes advantage of the fact default value is EscrowType.NORMAL*


```solidity
function escrowType(uint256 tokenId) external view returns (EscrowType);
```

### idToManaged

*Mapping of token id to managed id*


```solidity
function idToManaged(uint256 tokenId)
    external
    view
    returns (uint256 managedTokenId);
```

### weights

*Mapping of user token id to managed token id to weight of token id*


```solidity
function weights(uint256 tokenId, uint256 managedTokenId)
    external
    view
    returns (uint256 weight);
```

### deactivated

*Mapping of managed id to deactivated state*


```solidity
function deactivated(uint256 tokenId) external view returns (bool inactive);
```

### createManagedLockFor

Create managed NFT (a permanent lock) for use within ecosystem.

*Throws if address already owns a managed NFT.*


```solidity
function createManagedLockFor(address _to)
    external
    returns (uint256 _mTokenId);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_mTokenId`|`uint256`|managed token id.|


### depositManaged

Delegates balance to managed nft
Note that NFTs deposited into a managed NFT will be re-locked
to the maximum lock time on withdrawal.
Permanent locks that are deposited will automatically unlock.

*Managed nft will remain max-locked as long as there is at least one
deposit or withdrawal per week.
Throws if deposit nft is managed.
Throws if recipient nft is not managed.
Throws if deposit nft is already locked.
Throws if not called by voter.*


```solidity
function depositManaged(uint256 _tokenId, uint256 _mTokenId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|tokenId of NFT being deposited|
|`_mTokenId`|`uint256`|tokenId of managed NFT that will receive the deposit|


### withdrawManaged

Retrieves locked rewards and withdraws balance from managed nft.
Note that the NFT withdrawn is re-locked to the maximum lock time.

*Throws if NFT not locked.
Throws if not called by voter.*


```solidity
function withdrawManaged(uint256 _tokenId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|tokenId of NFT being deposited.|


### setAllowedManager

Permit one address to call createManagedLockFor() that is not Voter.governor()


```solidity
function setAllowedManager(address _allowedManager) external;
```

### setManagedState

Set Managed NFT state. Inactive NFTs cannot be deposited into.


```solidity
function setManagedState(uint256 _mTokenId, bool _state) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_mTokenId`|`uint256`|managed nft state to set|
|`_state`|`bool`|true => inactive, false => active|


### name


```solidity
function name() external view returns (string memory);
```

### symbol


```solidity
function symbol() external view returns (string memory);
```

### version


```solidity
function version() external view returns (string memory);
```

### decimals


```solidity
function decimals() external view returns (uint8);
```

### setTeam


```solidity
function setTeam(address _team) external;
```

### setArtProxy


```solidity
function setArtProxy(address _proxy) external;
```

### tokenURI

A distinct Uniform Resource Identifier (URI) for a given asset.

*Throws if `_tokenId` is not a valid NFT. URIs are defined in RFC
3986. The URI may point to a JSON file that conforms to the "ERC721
Metadata JSON Schema".*


```solidity
function tokenURI(uint256 tokenId) external view returns (string memory);
```

### ownerToNFTokenIdList

*Mapping from owner address to mapping of index to tokenId*


```solidity
function ownerToNFTokenIdList(address _owner, uint256 _index)
    external
    view
    returns (uint256 _tokenId);
```

### ownerOf

Find the owner of an NFT

*NFTs assigned to zero address are considered invalid, and queries
about them do throw.*


```solidity
function ownerOf(uint256 tokenId) external view returns (address owner);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|The address of the owner of the NFT|


### balanceOf

Count all NFTs assigned to an owner

*NFTs assigned to the zero address are considered invalid, and this
function throws for queries about the zero address.*


```solidity
function balanceOf(address owner) external view returns (uint256 balance);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`balance`|`uint256`|The number of NFTs owned by `_owner`, possibly zero|


### getApproved

Get the approved address for a single NFT

*Throws if `_tokenId` is not a valid NFT.*


```solidity
function getApproved(uint256 _tokenId)
    external
    view
    returns (address operator);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|The NFT to find the approved address for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`operator`|`address`|The approved address for this NFT, or the zero address if there is none|


### isApprovedForAll

Query if an address is an authorized operator for another address


```solidity
function isApprovedForAll(address owner, address operator)
    external
    view
    returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`||
|`operator`|`address`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if `_operator` is an approved operator for `_owner`, false otherwise|


### isApprovedOrOwner

Check whether spender is owner or an approved user for a given veNFT


```solidity
function isApprovedOrOwner(address _spender, uint256 _tokenId)
    external
    returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_spender`|`address`|.|
|`_tokenId`|`uint256`|.|


### approve

Change or reaffirm the approved address for an NFT

*The zero address indicates there is no approved address.
Throws unless `msg.sender` is the current NFT owner, or an authorized
operator of the current owner.*


```solidity
function approve(address to, uint256 tokenId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`||
|`tokenId`|`uint256`||


### setApprovalForAll

Enable or disable approval for a third party ("operator") to manage
all of `msg.sender`'s assets

*Emits the ApprovalForAll event. The contract MUST allow
multiple operators per owner.*


```solidity
function setApprovalForAll(address operator, bool approved) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`operator`|`address`||
|`approved`|`bool`||


### transferFrom

Transfer ownership of an NFT -- THE CALLER IS RESPONSIBLE
TO CONFIRM THAT `_to` IS CAPABLE OF RECEIVING NFTS OR ELSE
THEY MAY BE PERMANENTLY LOST

*Throws unless `msg.sender` is the current owner, an authorized
operator, or the approved address for this NFT. Throws if `_from` is
not the current owner. Throws if `_to` is the zero address. Throws if
`_tokenId` is not a valid NFT.*


```solidity
function transferFrom(address from, address to, uint256 tokenId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`||
|`to`|`address`||
|`tokenId`|`uint256`||


### safeTransferFrom

Transfers the ownership of an NFT from one address to another address

*Throws unless `msg.sender` is the current owner, an authorized
operator, or the approved address for this NFT. Throws if `_from` is
not the current owner. Throws if `_to` is the zero address. Throws if
`_tokenId` is not a valid NFT. When transfer is complete, this function
checks if `_to` is a smart contract (code size > 0). If so, it calls
`onERC721Received` on `_to` and throws if the return value is not
`bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`.*


```solidity
function safeTransferFrom(address from, address to, uint256 tokenId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`||
|`to`|`address`||
|`tokenId`|`uint256`||


### safeTransferFrom

Transfers the ownership of an NFT from one address to another address

*Throws unless `msg.sender` is the current owner, an authorized
operator, or the approved address for this NFT. Throws if `_from` is
not the current owner. Throws if `_to` is the zero address. Throws if
`_tokenId` is not a valid NFT. When transfer is complete, this function
checks if `_to` is a smart contract (code size > 0). If so, it calls
`onERC721Received` on `_to` and throws if the return value is not
`bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`.*


```solidity
function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId,
    bytes calldata data
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`||
|`to`|`address`||
|`tokenId`|`uint256`||
|`data`|`bytes`|Additional data with no specified format, sent in call to `_to`|


### supportsInterface

Query if a contract implements an interface

*Interface identification is specified in ERC-165. This function
uses less than 30,000 gas.*


```solidity
function supportsInterface(bytes4 _interfaceID) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_interfaceID`|`bytes4`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|`true` if the contract implements `interfaceID` and `interfaceID` is not 0xffffffff, `false` otherwise|


### epoch

Total count of epochs witnessed since contract creation


```solidity
function epoch() external view returns (uint256);
```

### supply

Total amount of token() deposited


```solidity
function supply() external view returns (uint256);
```

### permanentLockBalance

Aggregate permanent locked balances


```solidity
function permanentLockBalance() external view returns (uint256);
```

### userPointEpoch


```solidity
function userPointEpoch(uint256 _tokenId)
    external
    view
    returns (uint256 _epoch);
```

### slopeChanges

time -> signed slope change


```solidity
function slopeChanges(uint256 _timestamp) external view returns (int128);
```

### canSplit

account -> can split


```solidity
function canSplit(address _account) external view returns (bool);
```

### pointHistory

Global point history at a given index


```solidity
function pointHistory(uint256 _loc)
    external
    view
    returns (GlobalPoint memory);
```

### locked

Get the LockedBalance (amount, end) of a _tokenId


```solidity
function locked(uint256 _tokenId)
    external
    view
    returns (LockedBalance memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`LockedBalance`|LockedBalance of _tokenId|


### userPointHistory

User -> UserPoint[userEpoch]


```solidity
function userPointHistory(uint256 _tokenId, uint256 _loc)
    external
    view
    returns (UserPoint memory);
```

### checkpoint

Record global data to checkpoint


```solidity
function checkpoint() external;
```

### depositFor

Deposit `_value` tokens for `_tokenId` and add to the lock

*Anyone (even a smart contract) can deposit for someone else, but
cannot extend their locktime and deposit for a brand new user*


```solidity
function depositFor(uint256 _tokenId, uint256 _value) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|lock NFT|
|`_value`|`uint256`|Amount to add to user's lock|


### createLock

Deposit `_value` tokens for `msg.sender` and lock for `_lockDuration`


```solidity
function createLock(uint256 _value, uint256 _lockDuration)
    external
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_value`|`uint256`|Amount to deposit|
|`_lockDuration`|`uint256`|Number of seconds to lock tokens for (rounded down to nearest week)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|TokenId of created veNFT|


### createLockFor

Deposit `_value` tokens for `_to` and lock for `_lockDuration`


```solidity
function createLockFor(uint256 _value, uint256 _lockDuration, address _to)
    external
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_value`|`uint256`|Amount to deposit|
|`_lockDuration`|`uint256`|Number of seconds to lock tokens for (rounded down to nearest week)|
|`_to`|`address`|Address to deposit|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|TokenId of created veNFT|


### increaseAmount

Deposit `_value` additional tokens for `_tokenId` without modifying the unlock time


```solidity
function increaseAmount(uint256 _tokenId, uint256 _value) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`||
|`_value`|`uint256`|Amount of tokens to deposit and add to the lock|


### increaseUnlockTime

Extend the unlock time for `_tokenId`
Cannot extend lock time of permanent locks


```solidity
function increaseUnlockTime(uint256 _tokenId, uint256 _lockDuration) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`||
|`_lockDuration`|`uint256`|New number of seconds until tokens unlock|


### withdraw

Withdraw all tokens for `_tokenId`

*Only possible if the lock is both expired and not permanent
This will burn the veNFT. Any rebases or rewards that are unclaimed
will no longer be claimable. Claim all rebases and rewards prior to calling this.*


```solidity
function withdraw(uint256 _tokenId) external;
```

### merge

Merges `_from` into `_to`.

*Cannot merge `_from` locks that are permanent or have already voted this epoch.
Cannot merge `_to` locks that have already expired.
This will burn the veNFT. Any rebases or rewards that are unclaimed
will no longer be claimable. Claim all rebases and rewards prior to calling this.*


```solidity
function merge(uint256 _from, uint256 _to) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_from`|`uint256`|VeNFT to merge from.|
|`_to`|`uint256`|VeNFT to merge into.|


### split

Splits veNFT into two new veNFTS - one with oldLocked.amount - `_amount`, and the second with `_amount`

*This burns the tokenId of the target veNFT
Callable by approved or owner
If this is called by approved, approved will not have permissions to manipulate the newly created veNFTs
Returns the two new split veNFTs to owner
If `from` is permanent, will automatically dedelegate.
This will burn the veNFT. Any rebases or rewards that are unclaimed
will no longer be claimable. Claim all rebases and rewards prior to calling this.*


```solidity
function split(uint256 _from, uint256 _amount)
    external
    returns (uint256 _tokenId1, uint256 _tokenId2);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_from`|`uint256`|VeNFT to split.|
|`_amount`|`uint256`|Amount to split from veNFT.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId1`|`uint256`|Return tokenId of veNFT with oldLocked.amount - `_amount`.|
|`_tokenId2`|`uint256`|Return tokenId of veNFT with `_amount`.|


### toggleSplit

Toggle split for a specific address.

*Toggle split for address(0) to enable or disable for all.*


```solidity
function toggleSplit(address _account, bool _bool) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_account`|`address`|Address to toggle split permissions|
|`_bool`|`bool`|True to allow, false to disallow|


### lockPermanent

Permanently lock a veNFT. Voting power will be equal to
`LockedBalance.amount` with no decay. Required to delegate.

*Only callable by unlocked normal veNFTs.*


```solidity
function lockPermanent(uint256 _tokenId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|tokenId to lock.|


### unlockPermanent

Unlock a permanently locked veNFT. Voting power will decay.
Will automatically dedelegate if delegated.

*Only callable by permanently locked veNFTs.
Cannot unlock if already voted this epoch.*


```solidity
function unlockPermanent(uint256 _tokenId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|tokenId to unlock.|


### balanceOfNFT

Get the voting power for _tokenId at the current timestamp

*Returns 0 if called in the same block as a transfer.*


```solidity
function balanceOfNFT(uint256 _tokenId) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Voting power|


### balanceOfNFTAt

Get the voting power for _tokenId at a given timestamp


```solidity
function balanceOfNFTAt(uint256 _tokenId, uint256 _t)
    external
    view
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|.|
|`_t`|`uint256`|Timestamp to query voting power|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Voting power|


### totalSupply

Calculate total voting power at current timestamp


```solidity
function totalSupply() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total voting power at current timestamp|


### totalSupplyAt

Calculate total voting power at a given timestamp


```solidity
function totalSupplyAt(uint256 _t) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_t`|`uint256`|Timestamp to query total voting power|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total voting power at given timestamp|


### voted

See if a queried _tokenId has actively voted


```solidity
function voted(uint256 _tokenId) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if voted, else false|


### setVoterAndDistributor

Set the global state voter and distributor

*This is only called once, at setup*


```solidity
function setVoterAndDistributor(address _voter, address _distributor)
    external;
```

### voting

Set `voted` for _tokenId to true or false

*Only callable by voter*


```solidity
function voting(uint256 _tokenId, bool _voted) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|.|
|`_voted`|`bool`|.|


### numCheckpoints

The number of checkpoints for each tokenId


```solidity
function numCheckpoints(uint256 tokenId) external view returns (uint48);
```

### nonces

A record of states for signing / validating signatures


```solidity
function nonces(address account) external view returns (uint256);
```

### delegates

*Returns the delegate that `tokenId` has chosen. Can never be equal to the delegator's `tokenId`.
Returns 0 if not delegated.*


```solidity
function delegates(uint256 delegator) external view returns (uint256);
```

### checkpoints

A record of delegated token checkpoints for each account, by index


```solidity
function checkpoints(uint256 tokenId, uint48 index)
    external
    view
    returns (Checkpoint memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|.|
|`index`|`uint48`|.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Checkpoint`|Checkpoint|


### getPastVotes

*Returns the amount of votes that `tokenId` had at a specific moment in the past.
If the account passed in is not the owner, returns 0.*


```solidity
function getPastVotes(address account, uint256 tokenId, uint256 timestamp)
    external
    view
    returns (uint256);
```

### getPastTotalSupply

*Returns the total supply of votes available at a specific moment in the past. If the `clock()` is
configured to use block numbers, this will return the value the end of the corresponding block.
NOTE: This value is the sum of all available votes, which is not necessarily the sum of all delegated votes.
Votes that have not been delegated are still part of total supply, even though they would not participate in a
vote.*


```solidity
function getPastTotalSupply(uint256 timestamp)
    external
    view
    returns (uint256);
```

### delegate

*Delegates votes from the sender to `delegatee`.*


```solidity
function delegate(uint256 delegator, uint256 delegatee) external;
```

### delegateBySig

*Delegates votes from `delegator` to `delegatee`. Signer must own `delegator`.*


```solidity
function delegateBySig(
    uint256 delegator,
    uint256 delegatee,
    uint256 nonce,
    uint256 expiry,
    uint8 v,
    bytes32 r,
    bytes32 s
) external;
```

### clock

*Clock used for flagging checkpoints. Can be overridden to implement timestamp based checkpoints (and voting).*


```solidity
function clock() external view returns (uint48);
```

### CLOCK_MODE

*Description of the clock*


```solidity
function CLOCK_MODE() external view returns (string memory);
```

## Events
### Deposit

```solidity
event Deposit(
    address indexed provider,
    uint256 indexed tokenId,
    DepositType indexed depositType,
    uint256 value,
    uint256 locktime,
    uint256 ts
);
```

### Withdraw

```solidity
event Withdraw(
    address indexed provider, uint256 indexed tokenId, uint256 value, uint256 ts
);
```

### LockPermanent

```solidity
event LockPermanent(
    address indexed _owner,
    uint256 indexed _tokenId,
    uint256 amount,
    uint256 _ts
);
```

### UnlockPermanent

```solidity
event UnlockPermanent(
    address indexed _owner,
    uint256 indexed _tokenId,
    uint256 amount,
    uint256 _ts
);
```

### Supply

```solidity
event Supply(uint256 prevSupply, uint256 supply);
```

### Merge

```solidity
event Merge(
    address indexed _sender,
    uint256 indexed _from,
    uint256 indexed _to,
    uint256 _amountFrom,
    uint256 _amountTo,
    uint256 _amountFinal,
    uint256 _locktime,
    uint256 _ts
);
```

### Split

```solidity
event Split(
    uint256 indexed _from,
    uint256 indexed _tokenId1,
    uint256 indexed _tokenId2,
    address _sender,
    uint256 _splitAmount1,
    uint256 _splitAmount2,
    uint256 _locktime,
    uint256 _ts
);
```

### CreateManaged

```solidity
event CreateManaged(
    address indexed _to, uint256 indexed _mTokenId, address indexed _from
);
```

### DepositManaged

```solidity
event DepositManaged(
    address indexed _owner,
    uint256 indexed _tokenId,
    uint256 indexed _mTokenId,
    uint256 _weight,
    uint256 _ts
);
```

### WithdrawManaged

```solidity
event WithdrawManaged(
    address indexed _owner,
    uint256 indexed _tokenId,
    uint256 indexed _mTokenId,
    uint256 _weight,
    uint256 _ts
);
```

### SetAllowedManager

```solidity
event SetAllowedManager(address indexed _allowedManager);
```

## Errors
### AlreadyVoted

```solidity
error AlreadyVoted();
```

### AmountTooBig

```solidity
error AmountTooBig();
```

### ERC721ReceiverRejectedTokens

```solidity
error ERC721ReceiverRejectedTokens();
```

### ERC721TransferToNonERC721ReceiverImplementer

```solidity
error ERC721TransferToNonERC721ReceiverImplementer();
```

### InvalidNonce

```solidity
error InvalidNonce();
```

### InvalidSignature

```solidity
error InvalidSignature();
```

### InvalidSignatureS

```solidity
error InvalidSignatureS();
```

### InvalidManagedNFTId

```solidity
error InvalidManagedNFTId();
```

### LockDurationNotInFuture

```solidity
error LockDurationNotInFuture();
```

### LockDurationTooLong

```solidity
error LockDurationTooLong();
```

### LockExpired

```solidity
error LockExpired();
```

### LockNotExpired

```solidity
error LockNotExpired();
```

### NoLockFound

```solidity
error NoLockFound();
```

### NonExistentToken

```solidity
error NonExistentToken();
```

### NotApprovedOrOwner

```solidity
error NotApprovedOrOwner();
```

### NotDistributor

```solidity
error NotDistributor();
```

### NotEmergencyCouncilOrGovernor

```solidity
error NotEmergencyCouncilOrGovernor();
```

### NotGovernor

```solidity
error NotGovernor();
```

### NotGovernorOrManager

```solidity
error NotGovernorOrManager();
```

### NotManagedNFT

```solidity
error NotManagedNFT();
```

### NotManagedOrNormalNFT

```solidity
error NotManagedOrNormalNFT();
```

### NotLockedNFT

```solidity
error NotLockedNFT();
```

### NotNormalNFT

```solidity
error NotNormalNFT();
```

### NotPermanentLock

```solidity
error NotPermanentLock();
```

### NotOwner

```solidity
error NotOwner();
```

### NotTeam

```solidity
error NotTeam();
```

### NotVoter

```solidity
error NotVoter();
```

### OwnershipChange

```solidity
error OwnershipChange();
```

### PermanentLock

```solidity
error PermanentLock();
```

### SameAddress

```solidity
error SameAddress();
```

### SameNFT

```solidity
error SameNFT();
```

### SameState

```solidity
error SameState();
```

### SplitNoOwner

```solidity
error SplitNoOwner();
```

### SplitNotAllowed

```solidity
error SplitNotAllowed();
```

### SignatureExpired

```solidity
error SignatureExpired();
```

### TooManyTokenIDs

```solidity
error TooManyTokenIDs();
```

### ZeroAddress

```solidity
error ZeroAddress();
```

### ZeroAmount

```solidity
error ZeroAmount();
```

### ZeroBalance

```solidity
error ZeroBalance();
```

## Structs
### LockedBalance
Represents a locked token balance in the voting escrow system


```solidity
struct LockedBalance {
    int128 amount;
    uint256 end;
    bool isPermanent;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`int128`|The amount of tokens locked by the user|
|`end`|`uint256`|The expiration timestamp for the lock|
|`isPermanent`|`bool`|Flag indicating if the lock is permanent|

### UserPoint
Represents a snapshot of a user's voting power at a given point


```solidity
struct UserPoint {
    int128 bias;
    int128 slope;
    uint256 ts;
    uint256 blk;
    uint256 permanent;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`bias`|`int128`|Voting power, decaying over time|
|`slope`|`int128`|Rate of decay of voting power|
|`ts`|`uint256`|Timestamp of this snapshot|
|`blk`|`uint256`|Block number of this snapshot|
|`permanent`|`uint256`|Amount locked permanently without decay|

### GlobalPoint
Tracks cumulative voting power and its decay across all users


```solidity
struct GlobalPoint {
    int128 bias;
    int128 slope;
    uint256 ts;
    uint256 blk;
    uint256 permanentLockBalance;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`bias`|`int128`|Total voting power, decaying over time|
|`slope`|`int128`|Global decay rate of voting power|
|`ts`|`uint256`|Timestamp of this global checkpoint|
|`blk`|`uint256`|Block number of this global checkpoint|
|`permanentLockBalance`|`uint256`|Cumulative balance of permanently locked tokens|

### Checkpoint
Snapshot of delegated voting weights at a particular timestamp


```solidity
struct Checkpoint {
    uint256 fromTimestamp;
    address owner;
    uint256 delegatedBalance;
    uint256 delegatee;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`fromTimestamp`|`uint256`|Timestamp when the delegation was made|
|`owner`|`address`|Address of the NFT owner|
|`delegatedBalance`|`uint256`|Balance that has been delegated|
|`delegatee`|`uint256`|Address receiving the delegated voting power|

## Enums
### DepositType
Types of deposits supported in the voting escrow contract


```solidity
enum DepositType {
    DEPOSIT_FOR_TYPE,
    CREATE_LOCK_TYPE,
    INCREASE_LOCK_AMOUNT,
    INCREASE_UNLOCK_TIME
}
```

### EscrowType
Specifies the type of voting escrow NFT (veNFT)


```solidity
enum EscrowType {
    NORMAL,
    LOCKED,
    MANAGED
}
```

