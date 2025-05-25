# IBERADepositor
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/staking/IBERADepositor.sol)

**Inherits:**
[IIBERADepositor](/src/interfaces/IIBERADepositor.sol/interface.IIBERADepositor.md)

**Author:**
bungabear69420

Depositor to deposit BERA to CL for Infrared liquid staking token


## State Variables
### ETH1_ADDRESS_WITHDRAWAL_PREFIX

```solidity
uint8 public constant ETH1_ADDRESS_WITHDRAWAL_PREFIX = 0x01;
```


### DEPOSIT_CONTRACT

```solidity
address public constant DEPOSIT_CONTRACT =
    0x00000000219ab540356cBB839Cbe05303d7705Fa;
```


### IBERA
The address of IBERA


```solidity
address public immutable IBERA;
```


### slips
Outstanding slips for deposits on previously minted ibera


```solidity
mapping(uint256 => Slip) public slips;
```


### fees
Amount of BERA internally set aside for deposit contract request fees


```solidity
uint256 public fees;
```


### nonceSlip
The next nonce to issue deposit slip for


```solidity
uint256 public nonceSlip = 1;
```


### nonceSubmit
The next nonce to submit deposit slip for


```solidity
uint256 public nonceSubmit = 1;
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

Amount of BERA internally set aside to execute deposit contract requests


```solidity
function reserves() public view returns (uint256);
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


## Structs
### Slip

```solidity
struct Slip {
    uint96 timestamp;
    uint256 fee;
    uint256 amount;
}
```

