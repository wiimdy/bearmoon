# IIBERAClaimor
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/interfaces/IIBERAClaimor.sol)


## Functions
### claims

Outstanding BERA claims for a receiver


```solidity
function claims(address receiver) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`receiver`|`address`|The address of the claims receiver|


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


## Events
### Queue

```solidity
event Queue(address indexed receiver, uint256 amount, uint256 claim);
```

### Sweep

```solidity
event Sweep(address indexed receiver, uint256 amount, uint256 claim);
```

