# IBERA
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/staking/IBERA.sol)

**Inherits:**
ERC20, AccessControl, [IIBERA](/src/interfaces/IIBERA.sol/interface.IIBERA.md)

**Author:**
bungabear69420

Infrared liquid staking token for BERA

*Assumes BERA balances do *not* change at the CL*


## State Variables
### KEEPER_ROLE

```solidity
bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
```


### GOVERNANCE_ROLE

```solidity
bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
```


### infrared
Address of the Infrared operator contract


```solidity
address public immutable infrared;
```


### depositor
Address of the depositor that interacts with chain deposit precompile


```solidity
address public immutable depositor;
```


### withdrawor
Address of the withdrawor that interacts with chain withdraw precompile


```solidity
address public immutable withdrawor;
```


### claimor
Address of the claimor that receivers can claim withdrawn funds from


```solidity
address public immutable claimor;
```


### receivor
Address of the fee receivor contract that receives tx priority fees + MEV on EL


```solidity
address public immutable receivor;
```


### deposits
Deposits of BERA backing IBERA intended for use in CL by validators


```solidity
uint256 public deposits;
```


### stakes
Returns the amount of BERA staked in validator with given pubkey


```solidity
mapping(bytes => uint256) public stakes;
```


### feeProtocol
Fee taken by the protocol on yield from EL coinbase priority fees + MEV, represented as an integer denominator (1/x)%


```solidity
uint16 public feeProtocol;
```


### _initialized
Whether initial mint to address(this) has happened


```solidity
bool private _initialized;
```


## Functions
### constructor


```solidity
constructor(address _infrared) payable ERC20("Infrared BERA", "iBERA");
```

### _deposit


```solidity
function _deposit(uint256 value)
    private
    returns (uint256 nonce, uint256 amount, uint256 fee);
```

### _withdraw


```solidity
function _withdraw(address receiver, uint256 amount, uint256 fee)
    private
    returns (uint256 nonce);
```

### pending

Pending deposits yet to be forwarded to CL


```solidity
function pending() public view returns (uint256);
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
function keeper(address account) public view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether account is a keeper|


### governor

Returns whether given account is an IBERA governor


```solidity
function governor(address account) public view returns (bool);
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


```solidity
function compound() public;
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
    public
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


