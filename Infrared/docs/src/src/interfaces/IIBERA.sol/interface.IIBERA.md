# IIBERA
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/interfaces/IIBERA.sol)

**Inherits:**
IERC20, IAccessControl


## Functions
### infrared

Address of the Infrared operator contract


```solidity
function infrared() external view returns (address);
```

### depositor

Address of the depositor that interacts with chain deposit precompile


```solidity
function depositor() external view returns (address);
```

### withdrawor

Address of the withdrawor that interacts with chain withdraw precompile


```solidity
function withdrawor() external view returns (address);
```

### claimor

Address of the claimor that receivers can claim withdrawn funds from


```solidity
function claimor() external view returns (address);
```

### receivor

Address of the fee receivor contract that receives tx priority fees + MEV on EL


```solidity
function receivor() external view returns (address);
```

### deposits

Deposits of BERA backing IBERA intended for use in CL by validators


```solidity
function deposits() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of BERA for deposits to CL|


### stakes

Returns the amount of BERA staked in validator with given pubkey


```solidity
function stakes(bytes calldata pubkey) external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of BERA staked in validator|


### feeProtocol

Fee taken by the protocol on yield from EL coinbase priority fees + MEV, represented as an integer denominator (1/x)%


```solidity
function feeProtocol() external view returns (uint16);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint16`|The fee taken by protocol|


### pending

Pending deposits yet to be forwarded to CL


```solidity
function pending() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of BERA yet to be deposited to CL|


### confirmed

Confirmed deposits sent to CL


```solidity
function confirmed() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of BERA confirmed to be deposited to CL|


### keeper

Returns whether given account is an IBERA keeper


```solidity
function keeper(address account) external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether account is a keeper|


### governor

Returns whether given account is an IBERA governor


```solidity
function governor(address account) external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether account is a governor|


### validator

Returns whether given pubkey is in Infrared validator set


```solidity
function validator(bytes calldata pubkey) external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether pubkey in Infrared validator set|


### initialize

Initializes IBERA to allow for future mints and burns

*Must be called before IBERA can offer deposits and withdraws*


```solidity
function initialize() external payable;
```

### compound

Compounds accumulated EL yield in fee receivor into deposits

*Called internally at bof whenever IBERA minted or burned*

*Only sweeps if amount transferred from fee receivor would exceed min deposit thresholds*


```solidity
function compound() external;
```

### sweep

Sweeps received funds in `msg.value` as yield into deposits

*Fee receivor must call this function in its sweep function for autocompounding*


```solidity
function sweep() external payable;
```

### mint

Mints ibera shares to receiver for bera paid in by sender


```solidity
function mint(address receiver)
    external
    payable
    returns (uint256 nonce, uint256 shares);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`receiver`|`address`|Address of the receiver of ibera|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`nonce`|`uint256`|The nonce issued to identify the credited bera funds for deposit|
|`shares`|`uint256`|The amount of shares of ibera minted|


### burn

Burns ibera shares from sender for bera to ultimately be transferred to receiver on subsequent call to claim

*Sender must pay withdraw precompile fee upfront*


```solidity
function burn(address receiver, uint256 shares)
    external
    payable
    returns (uint256 nonce, uint256 amount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`receiver`|`address`|Address of the receiver of future bera|
|`shares`|`uint256`|The amount of shares of ibera burned|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`nonce`|`uint256`|The nonce issued to identify the owed bera funds for claim|
|`amount`|`uint256`|The amount of bera funds that will be available for claim|


### register

Registers update to BERA staked in validator with given pubkey at CL

*Reverts if not called by depositor or withdrawor*


```solidity
function register(bytes calldata pubkey, int256 delta) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pubkey`|`bytes`|The pubkey of the validator to update BERA stake for at CL|
|`delta`|`int256`|The change in the amount of BERA staked/unstaked (+/-) at CL|


### setFeeProtocol

Sets the fee protocol taken on yield from EL coinbase priority fees + MEV


```solidity
function setFeeProtocol(uint16 to) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`uint16`|The new fee protocol represented as an integer denominator (1/x)%|


## Events
### Mint

```solidity
event Mint(
    address indexed receiver,
    uint256 nonce,
    uint256 amount,
    uint256 shares,
    uint256 fee
);
```

### Burn

```solidity
event Burn(
    address indexed receiver,
    uint256 nonce,
    uint256 amount,
    uint256 shares,
    uint256 fee
);
```

### Sweep

```solidity
event Sweep(uint256 amount);
```

### Register

```solidity
event Register(bytes pubkey, int256 delta, uint256 stake);
```

### SetFeeProtocol

```solidity
event SetFeeProtocol(uint16 from, uint16 to);
```

## Errors
### Unauthorized

```solidity
error Unauthorized();
```

### NotInitialized

```solidity
error NotInitialized();
```

### InvalidShares

```solidity
error InvalidShares();
```

### InvalidAmount

```solidity
error InvalidAmount();
```

