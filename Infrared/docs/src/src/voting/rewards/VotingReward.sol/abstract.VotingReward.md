# VotingReward
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/voting/rewards/VotingReward.sol)

**Inherits:**
[Reward](/src/voting/rewards/Reward.sol/abstract.Reward.md)

Base contract for rewards distributed based on voting power

*Extends Reward with voting-specific reward logic*


## Functions
### constructor

Configures voting rewards with initial reward tokens


```solidity
constructor(address _voter, address[] memory _rewards) Reward(_voter);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_voter`|`address`|Address of voter contract|
|`_rewards`|`address[]`|Initial array of reward token addresses|


### getReward

*Validates caller is token owner or voter before processing claim*


```solidity
function getReward(uint256 tokenId, address[] memory tokens)
    external
    override
    nonReentrant;
```

### notifyRewardAmount


```solidity
function notifyRewardAmount(address token, uint256 amount)
    external
    virtual
    override;
```

