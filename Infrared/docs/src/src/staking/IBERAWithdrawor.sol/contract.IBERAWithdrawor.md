# IBERAWithdrawor
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/staking/IBERAWithdrawor.sol)

**Inherits:**
[IIBERAWithdrawor](/src/interfaces/IIBERAWithdrawor.sol/interface.IIBERAWithdrawor.md)

**Author:**
bungabear69420

Withdrawor to withdraw BERA from CL for Infrared liquid staking token

*Assumes ETH returned via withdraw precompile credited to contract so receive unnecessary*


## State Variables
### WITHDRAW_REQUEST_TYPE

```solidity
uint8 public constant WITHDRAW_REQUEST_TYPE = 0x01;
```


### WITHDRAW_PRECOMPILE

```solidity
address public constant WITHDRAW_PRECOMPILE =
    0x00A3ca265EBcb825B45F985A16CEFB49958cE017;
```


### IBERA
The address of IBERA


```solidity
address public immutable IBERA;
```


### requests
Outstanding requests for claims on previously burnt ibera


```solidity
mapping(uint256 => Request) public requests;
```


### fees
Amount of BERA internally set aside for withdraw precompile request fees


```solidity
uint256 public fees;
```


### rebalancing
Amount of BERA internally rebalancing amongst Infrared validators


```solidity
uint256 public rebalancing;
```


### nonceRequest
The next nonce to issue withdraw request for


```solidity
uint256 public nonceRequest = 1;
```


### nonceSubmit
The next nonce to submit withdraw request for


```solidity
uint256 public nonceSubmit = 1;
```


### nonceProcess
The next nonce in queue to process claims for


```solidity
uint256 public nonceProcess = 1;
```


## Functions
### constructor


```solidity
constructor();
```

### _enoughtime

Checks whether enough time has passed beyond min delay


```solidity
function _enoughtime(uint96 then, uint96 current)
    private
    pure
    returns (bool has);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`then`|`uint96`|The block timestamp in past|
|`current`|`uint96`|The current block timestamp now|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`has`|`bool`|Whether time between then and now exceeds forced min delay|


### reserves

Amount of BERA internally set aside to process withdraw compile requests from funds received on successful requests


```solidity
function reserves() public view returns (uint256);
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

## Structs
### Request

```solidity
struct Request {
    address receiver;
    uint96 timestamp;
    uint256 fee;
    uint256 amountSubmit;
    uint256 amountProcess;
}
```

