# BribeCollector
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/core/BribeCollector.sol)

**Inherits:**
[InfraredUpgradeable](/src/core/InfraredUpgradeable.sol/abstract.InfraredUpgradeable.md), [IBribeCollector](/src/interfaces/IBribeCollector.sol/interface.IBribeCollector.md)

The Bribe Collector contract is responsible for collecting bribes from Berachain rewards vaults and
auctioning them for a Payout token which then is distributed among Infrared validators.

*This contract is forked from Berachain POL which is forked from Uniswap V3 Factory Owner contract.
https://github.com/uniswapfoundation/UniStaker/blob/main/src/V3FactoryOwner.sol*


## State Variables
### payoutToken
Token used for fee payments when claiming bribes


```solidity
address public payoutToken;
```


### payoutAmount
The amount of payout token that is required to claim POL bribes for all tokens

*This works as first come first serve basis. whoever pays this much amount of the payout amount first will
get the fees*


```solidity
uint256 public payoutAmount;
```


## Functions
### constructor


```solidity
constructor(address _infrared) InfraredUpgradeable(_infrared);
```

### initialize


```solidity
function initialize(address _admin, address _payoutToken, uint256 _payoutAmount)
    external
    initializer;
```

### setPayoutAmount

Update the payout amount to a new value. Must be called by governor


```solidity
function setPayoutAmount(uint256 _newPayoutAmount) external onlyGovernor;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newPayoutAmount`|`uint256`|The value that will be the new payout amount|


### claimFees

Claims accumulated bribes in exchange for payout token

*Caller must approve payoutAmount of payout token to this contract.*


```solidity
function claimFees(address _recipient, address[] calldata _feeTokens)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_recipient`|`address`||
|`_feeTokens`|`address[]`||


