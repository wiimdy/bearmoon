# IBERAClaimor
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/staking/IBERAClaimor.sol)

**Inherits:**
[IIBERAClaimor](/src/interfaces/IIBERAClaimor.sol/interface.IIBERAClaimor.md)

**Author:**
bungabear69420

Claimor to claim BERA withdrawn from CL for Infrared liquid staking token

*Separate contract so withdrawor process has trusted contract to forward funds to so no issue with naked bera transfer and receive function*


## State Variables
### claims
Outstanding BERA claims for a receiver


```solidity
mapping(address => uint256) public claims;
```


## Functions
### queue

Queues a new BERA claim for a receiver


```solidity
function queue(address receiver) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`receiver`|`address`|The address of the claims receiver|


### sweep

Sweeps oustanding BERA claims for a receiver to their address


```solidity
function sweep(address receiver) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`receiver`|`address`|The address of the claims receiver|


