# IIBERAFeeReceivor
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/interfaces/IIBERAFeeReceivor.sol)


## Functions
### IBERA

The address of IBERA


```solidity
function IBERA() external view returns (address);
```

### protocolFees

Accumulated protocol fees in contract to be claimed by governor


```solidity
function protocolFees() external view returns (uint256);
```

### distribution

Amount of BERA swept to IBERA and fees taken for protool on next call to sweep


```solidity
function distribution() external view returns (uint256 amount, uint256 fees);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|THe amount of BERA forwarded to IBERA on next sweep|
|`fees`|`uint256`|The protocol fees taken on next sweep|


### sweep

Sweeps accumulated coinbase priority fees + MEV to IBERA to autocompound principal


```solidity
function sweep() external returns (uint256 amount, uint256 fees);
```

### collect

Collects accumulated protocol fees

*Reverts if msg.sender not IBERA governor*


```solidity
function collect(address recipient) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|Address to send protocol fees to|


## Events
### Sweep

```solidity
event Sweep(address indexed receiver, uint256 amount, uint256 fees);
```

### Collect

```solidity
event Collect(address indexed receiver, uint256 amount);
```

## Errors
### Unauthorized

```solidity
error Unauthorized();
```

### InvalidAmount

```solidity
error InvalidAmount();
```

