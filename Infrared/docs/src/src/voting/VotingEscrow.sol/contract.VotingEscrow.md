# VotingEscrow
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/voting/VotingEscrow.sol)

**Inherits:**
[IVotingEscrow](/src/voting/interfaces/IVotingEscrow.sol/interface.IVotingEscrow.md), ReentrancyGuard

**Authors:**
Modified from Solidly (https://github.com/solidlyexchange/solidly/blob/master/contracts/ve.sol), Modified from Curve (https://github.com/curvefi/curve-dao-contracts/blob/master/contracts/VotingEscrow.vy), Modified from velodrome.finance (https://github.com/velodrome-finance/contracts/blob/main/contracts/VotingEscrow.sol), Infrared, @NoFront

veNFT implementation that escrows ERC-20 tokens in the form of an ERC-721 NFT

Votes have a weight depending on time, so that users are committed to the future of (whatever they are voting for)

*Vote weight decays linearly over time. Lock time cannot be more than `MAXTIME` (4 years).*


## State Variables
### keeper

```solidity
address public immutable keeper;
```


### token
Address of token (VELO) used to create a veNFT


```solidity
address public immutable token;
```


### distributor
Address of RewardsDistributor.sol


```solidity
address public distributor;
```


### voter
Address of Voter.sol


```solidity
address public voter;
```


### team
Address of Velodrome Team multisig


```solidity
address public team;
```


### artProxy
Address of art proxy used for on-chain art generation


```solidity
address public artProxy;
```


### allowedManager
*address which can create managed NFTs*


```solidity
address public allowedManager;
```


### _pointHistory

```solidity
mapping(uint256 => GlobalPoint) internal _pointHistory;
```


### supportedInterfaces
*Mapping of interface id to bool about whether or not it's supported*


```solidity
mapping(bytes4 => bool) internal supportedInterfaces;
```


### ERC165_INTERFACE_ID
*ERC165 interface ID of ERC165*


```solidity
bytes4 internal constant ERC165_INTERFACE_ID = 0x01ffc9a7;
```


### ERC721_INTERFACE_ID
*ERC165 interface ID of ERC721*


```solidity
bytes4 internal constant ERC721_INTERFACE_ID = 0x80ac58cd;
```


### ERC721_METADATA_INTERFACE_ID
*ERC165 interface ID of ERC721Metadata*


```solidity
bytes4 internal constant ERC721_METADATA_INTERFACE_ID = 0x5b5e139f;
```


### ERC4906_INTERFACE_ID
*ERC165 interface ID of ERC4906*


```solidity
bytes4 internal constant ERC4906_INTERFACE_ID = 0x49064906;
```


### ERC6372_INTERFACE_ID
*ERC165 interface ID of ERC6372*


```solidity
bytes4 internal constant ERC6372_INTERFACE_ID = 0xda287a1d;
```


### tokenId
*Current count of token*


```solidity
uint256 public tokenId;
```


### infrared
Address of Infrared contract


```solidity
IInfrared public infrared;
```


### escrowType
*Mapping of token id to escrow type
Takes advantage of the fact default value is EscrowType.NORMAL*


```solidity
mapping(uint256 => EscrowType) public escrowType;
```


### idToManaged
*Mapping of token id to managed id*


```solidity
mapping(uint256 => uint256) public idToManaged;
```


### weights
*Mapping of user token id to managed token id to weight of token id*


```solidity
mapping(uint256 => mapping(uint256 => uint256)) public weights;
```


### deactivated
*Mapping of managed id to deactivated state*


```solidity
mapping(uint256 => bool) public deactivated;
```


### name

```solidity
string public constant name = "veNFT";
```


### symbol

```solidity
string public constant symbol = "veNFT";
```


### version

```solidity
string public constant version = "2.0.0";
```


### decimals

```solidity
uint8 public constant decimals = 18;
```


### idToOwner
*Mapping from NFT ID to the address that owns it.*


```solidity
mapping(uint256 => address) internal idToOwner;
```


### ownerToNFTokenCount
*Mapping from owner address to count of his tokens.*


```solidity
mapping(address => uint256) internal ownerToNFTokenCount;
```


### idToApprovals
*Mapping from NFT ID to approved address.*


```solidity
mapping(uint256 => address) internal idToApprovals;
```


### ownerToOperators
*Mapping from owner address to mapping of operator addresses.*


```solidity
mapping(address => mapping(address => bool)) internal ownerToOperators;
```


### ownershipChange

```solidity
mapping(uint256 => uint256) internal ownershipChange;
```


### ownerToNFTokenIdList
*Mapping from owner address to mapping of index to tokenId*


```solidity
mapping(address => mapping(uint256 => uint256)) public ownerToNFTokenIdList;
```


### tokenToOwnerIndex
*Mapping from NFT ID to index of owner*


```solidity
mapping(uint256 => uint256) internal tokenToOwnerIndex;
```


### WEEK

```solidity
uint256 internal constant WEEK = 1 weeks;
```


### MAXTIME

```solidity
uint256 internal constant MAXTIME = 4 * 365 * 86400;
```


### iMAXTIME

```solidity
int128 internal constant iMAXTIME = 4 * 365 * 86400;
```


### MULTIPLIER

```solidity
uint256 internal constant MULTIPLIER = 1 ether;
```


### epoch
Total count of epochs witnessed since contract creation


```solidity
uint256 public epoch;
```


### supply
Total amount of token() deposited


```solidity
uint256 public supply;
```


### _locked

```solidity
mapping(uint256 => LockedBalance) internal _locked;
```


### _userPointHistory

```solidity
mapping(uint256 => UserPoint[1000000000]) internal _userPointHistory;
```


### userPointEpoch

```solidity
mapping(uint256 => uint256) public userPointEpoch;
```


### slopeChanges
time -> signed slope change


```solidity
mapping(uint256 => int128) public slopeChanges;
```


### canSplit
account -> can split


```solidity
mapping(address => bool) public canSplit;
```


### permanentLockBalance
Aggregate permanent locked balances


```solidity
uint256 public permanentLockBalance;
```


### voted
See if a queried _tokenId has actively voted


```solidity
mapping(uint256 => bool) public voted;
```


### DOMAIN_TYPEHASH
The EIP-712 typehash for the contract's domain


```solidity
bytes32 public constant DOMAIN_TYPEHASH = keccak256(
    "EIP712Domain(string name,uint256 chainId,address verifyingContract)"
);
```


### DELEGATION_TYPEHASH
The EIP-712 typehash for the delegation struct used by the contract


```solidity
bytes32 public constant DELEGATION_TYPEHASH = keccak256(
    "Delegation(uint256 delegator,uint256 delegatee,uint256 nonce,uint256 expiry)"
);
```


### _delegates
A record of each accounts delegate


```solidity
mapping(uint256 => uint256) private _delegates;
```


### _checkpoints
A record of delegated token checkpoints for each tokenId, by index


```solidity
mapping(uint256 => mapping(uint48 => Checkpoint)) private _checkpoints;
```


### numCheckpoints
The number of checkpoints for each tokenId


```solidity
mapping(uint256 => uint48) public numCheckpoints;
```


### nonces
A record of states for signing / validating signatures


```solidity
mapping(address => uint256) public nonces;
```


## Functions
### constructor

Initializes VotingEscrow contract


```solidity
constructor(address _keeper, address _token, address _voter, address _infrared);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_keeper`|`address`|Address of keeper contract|
|`_token`|`address`|Address of token (VELO) used to create a veNFT|
|`_voter`|`address`|Address of Voter contract|
|`_infrared`|`address`|Address of Infrared contract|


### createManagedLockFor

Create managed NFT (a permanent lock) for use within ecosystem.

*Throws if address already owns a managed NFT.*


```solidity
function createManagedLockFor(address _to)
    external
    nonReentrant
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
function depositManaged(uint256 _tokenId, uint256 _mTokenId)
    external
    nonReentrant;
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
function withdrawManaged(uint256 _tokenId) external nonReentrant;
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


### setTeam


```solidity
function setTeam(address _team) external;
```

### setArtProxy


```solidity
function setArtProxy(address _proxy) external;
```

### tokenURI


```solidity
function tokenURI(uint256 _tokenId) external view returns (string memory);
```

### _ownerOf


```solidity
function _ownerOf(uint256 _tokenId) internal view returns (address);
```

### ownerOf


```solidity
function ownerOf(uint256 _tokenId) external view returns (address);
```

### balanceOf


```solidity
function balanceOf(address _owner) external view returns (uint256);
```

### getApproved


```solidity
function getApproved(uint256 _tokenId) external view returns (address);
```

### isApprovedForAll


```solidity
function isApprovedForAll(address _owner, address _operator)
    external
    view
    returns (bool);
```

### isApprovedOrOwner

Check whether spender is owner or an approved user for a given veNFT


```solidity
function isApprovedOrOwner(address _spender, uint256 _tokenId)
    external
    view
    returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_spender`|`address`|.|
|`_tokenId`|`uint256`|.|


### _isApprovedOrOwner


```solidity
function _isApprovedOrOwner(address _spender, uint256 _tokenId)
    internal
    view
    returns (bool);
```

### approve


```solidity
function approve(address _approved, uint256 _tokenId) external;
```

### setApprovalForAll


```solidity
function setApprovalForAll(address _operator, bool _approved) external;
```

### _transferFrom


```solidity
function _transferFrom(
    address _from,
    address _to,
    uint256 _tokenId,
    address _sender
) internal;
```

### transferFrom


```solidity
function transferFrom(address _from, address _to, uint256 _tokenId) external;
```

### safeTransferFrom


```solidity
function safeTransferFrom(address _from, address _to, uint256 _tokenId)
    external;
```

### _isContract


```solidity
function _isContract(address account) internal view returns (bool);
```

### safeTransferFrom


```solidity
function safeTransferFrom(
    address _from,
    address _to,
    uint256 _tokenId,
    bytes memory _data
) public;
```

### supportsInterface


```solidity
function supportsInterface(bytes4 _interfaceID) external view returns (bool);
```

### _addTokenToOwnerList

*Add a NFT to an index mapping to a given address*


```solidity
function _addTokenToOwnerList(address _to, uint256 _tokenId) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_to`|`address`|address of the receiver|
|`_tokenId`|`uint256`|uint ID Of the token to be added|


### _addTokenTo

*Add a NFT to a given address
Throws if `_tokenId` is owned by someone.*


```solidity
function _addTokenTo(address _to, uint256 _tokenId) internal;
```

### _mint

*Function to mint tokens
Throws if `_to` is zero address.
Throws if `_tokenId` is owned by someone.*


```solidity
function _mint(address _to, uint256 _tokenId) internal returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_to`|`address`|The address that will receive the minted tokens.|
|`_tokenId`|`uint256`|The token id to mint.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|A boolean that indicates if the operation was successful.|


### _removeTokenFromOwnerList

*Remove a NFT from an index mapping to a given address*


```solidity
function _removeTokenFromOwnerList(address _from, uint256 _tokenId) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_from`|`address`|address of the sender|
|`_tokenId`|`uint256`|uint ID Of the token to be removed|


### _removeTokenFrom

*Remove a NFT from a given address
Throws if `_from` is not the current owner.*


```solidity
function _removeTokenFrom(address _from, uint256 _tokenId) internal;
```

### _burn

*Must be called prior to updating `LockedBalance`*


```solidity
function _burn(uint256 _tokenId) internal;
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

### pointHistory

Global point history at a given index


```solidity
function pointHistory(uint256 _loc)
    external
    view
    returns (GlobalPoint memory);
```

### _checkpoint

Record global and per-user data to checkpoints. Used by VotingEscrow system.


```solidity
function _checkpoint(
    uint256 _tokenId,
    LockedBalance memory _oldLocked,
    LockedBalance memory _newLocked
) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|NFT token ID. No user checkpoint if 0|
|`_oldLocked`|`LockedBalance`|Pevious locked amount / end lock time for the user|
|`_newLocked`|`LockedBalance`|New locked amount / end lock time for the user|


### _depositFor

Deposit and lock tokens for a user


```solidity
function _depositFor(
    uint256 _tokenId,
    uint256 _value,
    uint256 _unlockTime,
    LockedBalance memory _oldLocked,
    DepositType _depositType
) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|NFT that holds lock|
|`_value`|`uint256`|Amount to deposit|
|`_unlockTime`|`uint256`|New time when to unlock the tokens, or 0 if unchanged|
|`_oldLocked`|`LockedBalance`|Previous locked amount / timestamp|
|`_depositType`|`DepositType`|The type of deposit|


### checkpoint

Record global data to checkpoint


```solidity
function checkpoint() external nonReentrant;
```

### depositFor

Deposit `_value` tokens for `_tokenId` and add to the lock

*Anyone (even a smart contract) can deposit for someone else, but
cannot extend their locktime and deposit for a brand new user*


```solidity
function depositFor(uint256 _tokenId, uint256 _value) external nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|lock NFT|
|`_value`|`uint256`|Amount to add to user's lock|


### _createLock

*Deposit `_value` tokens for `_to` and lock for `_lockDuration`*


```solidity
function _createLock(uint256 _value, uint256 _lockDuration, address _to)
    internal
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_value`|`uint256`|Amount to deposit|
|`_lockDuration`|`uint256`|Number of seconds to lock tokens for (rounded down to nearest week)|
|`_to`|`address`|Address to deposit|


### createLock

Deposit `_value` tokens for `msg.sender` and lock for `_lockDuration`


```solidity
function createLock(uint256 _value, uint256 _lockDuration)
    external
    nonReentrant
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
    nonReentrant
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


### _increaseAmountFor


```solidity
function _increaseAmountFor(
    uint256 _tokenId,
    uint256 _value,
    DepositType _depositType
) internal;
```

### increaseAmount

Deposit `_value` additional tokens for `_tokenId` without modifying the unlock time


```solidity
function increaseAmount(uint256 _tokenId, uint256 _value)
    external
    nonReentrant;
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
function increaseUnlockTime(uint256 _tokenId, uint256 _lockDuration)
    external
    nonReentrant;
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
function withdraw(uint256 _tokenId) external nonReentrant;
```

### merge

Merges `_from` into `_to`.

*Cannot merge `_from` locks that are permanent or have already voted this epoch.
Cannot merge `_to` locks that have already expired.
This will burn the veNFT. Any rebases or rewards that are unclaimed
will no longer be claimable. Claim all rebases and rewards prior to calling this.*


```solidity
function merge(uint256 _from, uint256 _to) external nonReentrant;
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
    nonReentrant
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


### _createSplitNFT


```solidity
function _createSplitNFT(address _to, LockedBalance memory _newLocked)
    private
    returns (uint256 _tokenId);
```

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


### _balanceOfNFTAt


```solidity
function _balanceOfNFTAt(uint256 _tokenId, uint256 _t)
    internal
    view
    returns (uint256);
```

### _supplyAt


```solidity
function _supplyAt(uint256 _timestamp) internal view returns (uint256);
```

### balanceOfNFT

Get the voting power for _tokenId at the current timestamp

*Returns 0 if called in the same block as a transfer.*


```solidity
function balanceOfNFT(uint256 _tokenId) public view returns (uint256);
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
function totalSupplyAt(uint256 _timestamp) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_timestamp`|`uint256`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total voting power at given timestamp|


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


### delegates


```solidity
function delegates(uint256 delegator) external view returns (uint256);
```

### checkpoints

A record of delegated token checkpoints for each account, by index


```solidity
function checkpoints(uint256 _tokenId, uint48 _index)
    external
    view
    returns (Checkpoint memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`||
|`_index`|`uint48`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Checkpoint`|Checkpoint|


### getPastVotes


```solidity
function getPastVotes(address _account, uint256 _tokenId, uint256 _timestamp)
    external
    view
    returns (uint256);
```

### getPastTotalSupply


```solidity
function getPastTotalSupply(uint256 _timestamp)
    external
    view
    returns (uint256);
```

### _checkpointDelegator


```solidity
function _checkpointDelegator(
    uint256 _delegator,
    uint256 _delegatee,
    address _owner
) internal;
```

### _checkpointDelegatee


```solidity
function _checkpointDelegatee(
    uint256 _delegatee,
    uint256 balance_,
    bool _increase
) internal;
```

### _delegate

Record user delegation checkpoints. Used by voting system.

*Skips delegation if already delegated to `delegatee`.*


```solidity
function _delegate(uint256 _delegator, uint256 _delegatee) internal;
```

### delegate


```solidity
function delegate(uint256 delegator, uint256 delegatee) external;
```

### delegateBySig


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


```solidity
function clock() external view returns (uint48);
```

### CLOCK_MODE


```solidity
function CLOCK_MODE() external pure returns (string memory);
```

