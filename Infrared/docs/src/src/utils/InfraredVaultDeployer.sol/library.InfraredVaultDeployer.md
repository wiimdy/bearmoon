# InfraredVaultDeployer
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/utils/InfraredVaultDeployer.sol)


## Functions
### deploy

Deploys a new `InfraredVault` or `IBGTVault` contract.

*If _stakingToken == IBGT, then deploys `IBGTVault`.*


```solidity
function deploy(
    address _stakingToken,
    address[] memory _rewardTokens,
    uint256 _rewardsDuration
) public returns (address _new);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_stakingToken`|`address`|address The address of the staking token.|
|`_rewardTokens`|`address[]`|The reward tokens for the vault.|
|`_rewardsDuration`|`uint256`|The duration of the rewards for the vault.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_new`|`address`|address The address of the new `InfraredVault` contract.|


