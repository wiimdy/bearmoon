# BribeVotingReward
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/voting/rewards/BribeVotingReward.sol)

**Inherits:**
[VotingReward](/src/voting/rewards/VotingReward.sol/abstract.VotingReward.md)

Implementation of voting rewards for bribes based on user votes

*Final implementation of voting rewards specifically for bribe distribution*


## Functions
### constructor

Initializes bribe voting rewards


```solidity
constructor(address _voter, address[] memory _rewards)
    VotingReward(_voter, _rewards);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_voter`|`address`|Address of voter contract|
|`_rewards`|`address[]`|Initial array of reward token addresses|


### notifyRewardAmount

*Validates and whitelists reward tokens before processing*


```solidity
function notifyRewardAmount(address token, uint256 amount)
    external
    override
    nonReentrant;
```

