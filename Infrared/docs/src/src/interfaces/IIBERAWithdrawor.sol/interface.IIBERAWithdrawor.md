# IIBERAWithdrawor
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/interfaces/IIBERAWithdrawor.sol)


## Functions
### IBERA

The address of IBERA


```solidity
function IBERA() external view returns (address);
```

### requests

Outstanding requests for claims on previously burnt ibera


```solidity
function requests(uint256 nonce)
    external
    view
    returns (
        address receiver,
        uint96 timestamp,
        uint256 fee,
        uint256 amountSubmit,
        uint256 amountProcess
    );
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`nonce`|`uint256`|The nonce associated with the claim|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`receiver`|`address`|The address of the receiver of bera funds to be claimed|
|`timestamp`|`uint96`|The block.timestamp at which withdraw request was issued|
|`fee`|`uint256`|The fee escrow amount set aside for withdraw precompile request|
|`amountSubmit`|`uint256`|The amount of bera left to be submitted for withdraw request|
|`amountProcess`|`uint256`|The amount of bera left to be processed for withdraw request|


### fees

Amount of BERA internally set aside for withdraw precompile request fees


```solidity
function fees() external view returns (uint256);
```

### reserves

Amount of BERA internally set aside to process withdraw compile requests from funds received on successful requests


```solidity
function reserves() external view returns (uint256);
```

### rebalancing

Amount of BERA internally rebalancing amongst Infrared validators


```solidity
function rebalancing() external view returns (uint256);
```

### nonceRequest

The next nonce to issue withdraw request for


```solidity
function nonceRequest() external view returns (uint256);
```

### nonceSubmit

The next nonce to submit withdraw request for


```solidity
function nonceSubmit() external view returns (uint256);
```

### nonceProcess

The next nonce in queue to process claims for


```solidity
function nonceProcess() external view returns (uint256);
```

### queue

Queues a withdraw from IBERA for chain withdraw precompile escrowing minimum fees for request to withdraw precompile


```solidity
function queue(address receiver, uint256 amount)
    external
    payable
    returns (uint256 nonce);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`receiver`|`address`|The address to receive withdrawn funds|
|`amount`|`uint256`|The amount of funds to withdraw|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`nonce`|`uint256`|The nonce created when queueing the withdraw|


### execute

Executes a withdraw request to withdraw precompile

*Payable in case excess bera required to satisfy withdraw precompile fee*


```solidity
function execute(bytes calldata pubkey, uint256 amount) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pubkey`|`bytes`|The pubkey to withdraw validator funds from|
|`amount`|`uint256`|The amount of funds to withdraw from validator|


### process

Processes the funds received from withdraw precompile to next-to-process request receiver

*Reverts if balance has not increased by full amount of request for next-to-process request nonce*


```solidity
function process() external;
```

## Events
### Queue

```solidity
event Queue(address indexed receiver, uint256 nonce, uint256 amount);
```

### Execute

```solidity
event Execute(bytes pubkey, uint256 start, uint256 end, uint256 amount);
```

### Process

```solidity
event Process(address indexed receiver, uint256 nonce, uint256 amount);
```

## Errors
### Unauthorized

```solidity
error Unauthorized();
```

### InvalidFee

```solidity
error InvalidFee();
```

### InvalidAmount

```solidity
error InvalidAmount();
```

### InvalidReceiver

```solidity
error InvalidReceiver();
```

### InvalidReserves

```solidity
error InvalidReserves();
```

### CallFailed

```solidity
error CallFailed();
```

