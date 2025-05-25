# IIBERADepositor
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/interfaces/IIBERADepositor.sol)


## Functions
### IBERA

The address of IBERA


```solidity
function IBERA() external view returns (address);
```

### slips

Outstanding slips for deposits on previously minted ibera


```solidity
function slips(uint256 nonce)
    external
    view
    returns (uint96 timestamp, uint256 fee, uint256 amount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`nonce`|`uint256`|The nonce associated with the slip|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`timestamp`|`uint96`|The block.timestamp at which deposit slip was issued|
|`fee`|`uint256`|The fee escrow amount set aside for deposit contract request|
|`amount`|`uint256`|The amount of bera left to be submitted for deposit slip|


### fees

Amount of BERA internally set aside for deposit contract request fees


```solidity
function fees() external view returns (uint256);
```

### reserves

Amount of BERA internally set aside to execute deposit contract requests


```solidity
function reserves() external view returns (uint256);
```

### nonceSlip

The next nonce to issue deposit slip for


```solidity
function nonceSlip() external view returns (uint256);
```

### nonceSubmit

The next nonce to submit deposit slip for


```solidity
function nonceSubmit() external view returns (uint256);
```

### queue

Queues a deposit from IBERA for chain deposit precompile escrowing msg.value in contract


```solidity
function queue(uint256 amount) external payable returns (uint256 nonce);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of funds to deposit|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`nonce`|`uint256`|The nonce created when queueing the deposit|


### execute

Executes a deposit to deposit precompile using escrowed funds


```solidity
function execute(
    bytes calldata pubkey,
    uint256 amount,
    bytes calldata signature
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pubkey`|`bytes`|The pubkey to deposit validator funds to|
|`amount`|`uint256`|The amount of funds to use from escrow to deposit to validator|
|`signature`|`bytes`|The signature used only on the first deposit|


## Events
### Queue

```solidity
event Queue(uint256 nonce, uint256 amount);
```

### Execute

```solidity
event Execute(bytes pubkey, uint256 start, uint256 end, uint256 amount);
```

## Errors
### Unauthorized

```solidity
error Unauthorized();
```

### InvalidValidator

```solidity
error InvalidValidator();
```

### InvalidAmount

```solidity
error InvalidAmount();
```

### InvalidFee

```solidity
error InvalidFee();
```

