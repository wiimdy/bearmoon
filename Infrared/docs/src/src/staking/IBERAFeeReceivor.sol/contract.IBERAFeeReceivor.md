# IBERAFeeReceivor
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/staking/IBERAFeeReceivor.sol)

**Inherits:**
[IIBERAFeeReceivor](/src/interfaces/IIBERAFeeReceivor.sol/interface.IIBERAFeeReceivor.md)

**Author:**
bungabear69420

Fee receivor receives coinbase priority fees + MEV credited to contract on EL upon block validation

*CL validators should set fee_recipient to the address of this contract*


## State Variables
### IBERA
The address of IBERA


```solidity
address public immutable IBERA;
```


### protocolFees
Accumulated protocol fees in contract to be claimed by governor


```solidity
uint256 public protocolFees;
```


## Functions
### constructor


```solidity
constructor();
```

### distribution

Amount of BERA swept to IBERA and fees taken for protool on next call to sweep


```solidity
function distribution() public view returns (uint256 amount, uint256 fees);
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
function collect(address receiver) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`receiver`|`address`||


### receive


```solidity
receive() external payable;
```

