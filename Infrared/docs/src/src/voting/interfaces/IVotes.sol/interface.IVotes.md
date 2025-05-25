# IVotes
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/voting/interfaces/IVotes.sol)

Modified IVotes interface for tokenId based voting


## Functions
### getPastVotes

*Returns the amount of votes that `tokenId` had at a specific moment in the past.
If the account passed in is not the owner, returns 0.*


```solidity
function getPastVotes(address account, uint256 tokenId, uint256 timepoint)
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
function getPastTotalSupply(uint256 timepoint)
    external
    view
    returns (uint256);
```

### delegates

*Returns the delegate that `tokenId` has chosen. Can never be equal to the delegator's `tokenId`.
Returns 0 if not delegated.*


```solidity
function delegates(uint256 tokenId) external view returns (uint256);
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

## Events
### DelegateChanged
*Emitted when an account changes their delegate.*


```solidity
event DelegateChanged(
    address indexed delegator,
    uint256 indexed fromDelegate,
    uint256 indexed toDelegate
);
```

### DelegateVotesChanged
*Emitted when a token transfer or delegate change results in changes to a delegate's number of votes.*


```solidity
event DelegateVotesChanged(
    address indexed delegate, uint256 previousBalance, uint256 newBalance
);
```

