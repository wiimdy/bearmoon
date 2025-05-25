# IInfrared
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/interfaces/IInfrared.sol)

**Inherits:**
[IInfraredUpgradeable](/src/interfaces/IInfraredUpgradeable.sol/interface.IInfraredUpgradeable.md)


## Functions
### whitelistedRewardTokens

Checks if a token is a whitelisted reward token


```solidity
function whitelistedRewardTokens(address _token) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_token`|`address`|The address of the token to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool True if the token is whitelisted, false otherwise|


### vaultRegistry

Returns the infrared vault address for a given staking token


```solidity
function vaultRegistry(address _asset) external view returns (IInfraredVault);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_asset`|`address`|The address of the staking asset|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IInfraredVault`|IInfraredVault The vault associated with the asset|


### ibgt

The IBGT liquid staked token


```solidity
function ibgt() external view returns (IIBGT);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IIBGT`|IIBGT The IBGT token contract address|


### ired

The Infrared governance token


```solidity
function ired() external view returns (IERC20Mintable);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IERC20Mintable`|IERC20Mintable instance of the IRED token contract address|


### wibera

The wrapped Infrared bera token


```solidity
function wibera() external view returns (IERC20);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IERC20`|IERC20 instance of the wibera token contract address|


### rewardsFactory

The Berachain rewards vault factory address


```solidity
function rewardsFactory()
    external
    view
    returns (IBerachainRewardsVaultFactory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IBerachainRewardsVaultFactory`|IBerachainRewardsVaultFactory instance of the rewards factory contract address|


### chef

The Berachain chef contract for distributing validator rewards


```solidity
function chef() external view returns (IBeraChef);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IBeraChef`|IBeraChef instance of the BeraChef contract address|


### ibgtVault

The IBGT vault


```solidity
function ibgtVault() external view returns (IInfraredVault);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IInfraredVault`|IInfraredVault instance of the iBGT vault contract address|


### wiberaVault

The wrapped IBERA vault


```solidity
function wiberaVault() external view returns (IInfraredVault);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IInfraredVault`|IInfraredVault instance of the wibera vault contract address|


### protocolFeeAmounts

The unclaimed Infrared protocol fees of token accumulated by contract


```solidity
function protocolFeeAmounts(address token) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|address The token address for the accumulated fees|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 The amount of accumulated fees|


### weights

Weights for various harvest function distributions


```solidity
function weights(uint256 i) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`i`|`uint256`|The index of the weight|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 The weight value|


### fees

Protocol fee rates to charge for various harvest function distributions


```solidity
function fees(uint256 i) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`i`|`uint256`|The index of the fee rate|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 The fee rate|


### wbera

Wrapped bera


```solidity
function wbera() external view returns (IWBERA);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IWBERA`|IWBERA The wbera token contract address|


### honey

Honey ERC20 token


```solidity
function honey() external view returns (IERC20);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IERC20`|IERC20 The honey token contract address|


### collector

bribe collector contract


```solidity
function collector() external view returns (IBribeCollector);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IBribeCollector`|IBribeCollector The bribe collector contract address|


### distributor

Infrared distributor for BGT rewards to validators


```solidity
function distributor() external view returns (IInfraredDistributor);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IInfraredDistributor`|IInfraredDistributor instance of the distributor contract address|


### voter

IRED voter


```solidity
function voter() external view returns (IVoter);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IVoter`|IVoter instance of the voter contract address|


### rewardsDuration

The rewards duration

*Used as gloabl variabel to set the rewards duration for all new reward tokens on InfraredVaults*


```solidity
function rewardsDuration() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 The reward duration period, in seconds|


### iredMintRate

The mint amount of IRED rewards minted per IBGT


```solidity
function iredMintRate() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 The IRED mint rate|


### registerVault

Registers a new vault for a given asset and initializes it with reward tokens

*Infrared.sol must be admin over MINTER_ROLE on IBGT to grant minter role to deployed vault*


```solidity
function registerVault(address _asset, address[] memory _rewardTokens)
    external
    returns (IInfraredVault vault);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_asset`|`address`|The address of the asset, such as a specific LP token|
|`_rewardTokens`|`address[]`|The addresses of reward tokens to initialize with the new vault|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`IInfraredVault`|The address of the newly created InfraredVault contract|


### updateWhiteListedRewardTokens

Updates the whitelist status of a reward token


```solidity
function updateWhiteListedRewardTokens(address _token, bool _whitelisted)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_token`|`address`|The address of the token to whitelist or remove from whitelist|
|`_whitelisted`|`bool`|A boolean indicating if the token should be whitelisted|


### updateRewardsDuration

Sets the new duration for reward distributions in InfraredVaults


```solidity
function updateRewardsDuration(uint256 _rewardsDuration) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_rewardsDuration`|`uint256`|The new reward duration period, in seconds|


### updateIredMintRate

Updates the IRED mint rate per unit of IBGT


```solidity
function updateIredMintRate(uint256 _iredMintRate) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_iredMintRate`|`uint256`|The new IRED mint rate in units of 1e6 (hundredths of 1 bip)|


### pauseVault

Pauses staking functionality on a specific vault

*Only callable by governance, will revert if vault doesn't exist*


```solidity
function pauseVault(address _asset) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_asset`|`address`|The address of the staking asset associated with the vault to pause|


### recoverERC20

Recovers ERC20 tokens sent accidentally to the contract


```solidity
function recoverERC20(address _to, address _token, uint256 _amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_to`|`address`|The address to receive the recovered tokens|
|`_token`|`address`|The address of the token to recover|
|`_amount`|`uint256`|The amount of the token to recover|


### initialize

Initializes Infrared by whitelisting rewards tokens, granting admin access roles, and deploying the iBGT vault


```solidity
function initialize(
    address _admin,
    address _collector,
    address _distributor,
    address _voter,
    uint256 _rewardsDuration
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_admin`|`address`|The address of the admin|
|`_collector`|`address`|The address of the collector|
|`_distributor`|`address`|The address of the distributor|
|`_voter`|`address`|The address of the voter|
|`_rewardsDuration`|`uint256`|The reward duration period, in seconds|


### delegateBGT

Delegates BGT votes to `_delegatee` address.


```solidity
function delegateBGT(address _delegatee) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_delegatee`|`address`| address The address to delegate votes to|


### updateWeight

Updates the weight for a weight type.


```solidity
function updateWeight(WeightType _t, uint256 _weight) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_t`|`WeightType`|WeightType The weight type|
|`_weight`|`uint256`|uint256 The weight value|


### updateFee

Updates the fee rate charged on different harvest functions

*Fee rate in units of 1e6 or hundredths of 1 bip*


```solidity
function updateFee(FeeType _t, uint256 _fee) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_t`|`FeeType`|  FeeType The fee type|
|`_fee`|`uint256`|uint256 The fee rate to update to|


### claimProtocolFees

Claims accumulated protocol fees in contract


```solidity
function claimProtocolFees(address _to, address _token, uint256 _amount)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_to`|`address`|    address The recipient of the fees|
|`_token`|`address`| address The token to claim fees in|
|`_amount`|`uint256`|uint256 The amount of accumulated fees to claim|


### harvestBase

Claims all the BGT base and commission rewards minted to this contract for validators.


```solidity
function harvestBase() external;
```

### harvestVault

Claims all the BGT rewards for the vault associated with the given staking token.


```solidity
function harvestVault(address _asset) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_asset`|`address`|address The address of the staking asset that the vault is for.|


### harvestBribes

Claims all the bribes rewards in the contract forwarded from Berachain POL.


```solidity
function harvestBribes(address[] memory _tokens) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokens`|`address[]`|address[] memory The addresses of the tokens to harvest in the contract.|


### collectBribes

Collects bribes from bribe collector and distributes to wiBERA and iBGT Infrared vaults.

_token The payout token for the bribe collector.

_amount The amount of payout received from bribe collector.


```solidity
function collectBribes(address _token, uint256 _amount) external;
```

### harvestBoostRewards

Claims all the BGT staker rewards from boosting validators.

*Sends rewards to iBGT vault.*


```solidity
function harvestBoostRewards() external;
```

### addValidators

Adds validators to the set of `InfraredValidators`.


```solidity
function addValidators(Validator[] memory _validators) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_validators`|`Validator[]`|Validator[] memory The validators to add.|


### removeValidators

Removes validators from the set of `InfraredValidators`.


```solidity
function removeValidators(bytes[] memory _pubkeys) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pubkeys`|`bytes[]`|bytes[] memory The pubkeys of the validators to remove.|


### replaceValidator

Replaces a validator in the set of `InfraredValidators`.


```solidity
function replaceValidator(bytes calldata _current, bytes calldata _new)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_current`|`bytes`|bytes The pubkey of the validator to replace.|
|`_new`|`bytes`|    bytes The new validator pubkey.|


### queueBoosts

Queue `_amts` of tokens to `_validators` for boosts.


```solidity
function queueBoosts(bytes[] memory _pubkeys, uint128[] memory _amts)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pubkeys`|`bytes[]`|    bytes[] memory The pubkeys of the validators to queue boosts for.|
|`_amts`|`uint128[]`|       uint128[] memory The amount of BGT to boost with.|


### cancelBoosts

Removes `_amts` from previously queued boosts to `_validators`.

*`_pubkeys` need not be in the current validator set in case just removed but need to cancel.*


```solidity
function cancelBoosts(bytes[] memory _pubkeys, uint128[] memory _amts)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pubkeys`|`bytes[]`|    bytes[] memory The pubkeys of the validators to remove boosts for.|
|`_amts`|`uint128[]`|       uint128[] memory The amounts of BGT to remove from the queued boosts.|


### activateBoosts

Activates queued boosts for `_pubkeys`.


```solidity
function activateBoosts(bytes[] memory _pubkeys) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pubkeys`|`bytes[]`|  bytes[] memory The pubkeys of the validators to activate boosts for.|


### queueNewCuttingBoard

Queues a new cutting board on BeraChef for reward weight distribution for validator


```solidity
function queueNewCuttingBoard(
    bytes calldata _pubkey,
    uint64 _startBlock,
    IBeraChef.Weight[] calldata _weights
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pubkey`|`bytes`|            bytes                         The pubkey of the validator to queue the cutting board for|
|`_startBlock`|`uint64`|        uint64                        The start block for reward weightings|
|`_weights`|`IBeraChef.Weight[]`|           IBeraChef.Weight[] calldata   The weightings used when distributor calls chef to distribute validator rewards|


### infraredValidators

Gets the set of infrared validator pubkeys.


```solidity
function infraredValidators()
    external
    view
    returns (Validator[] memory validators);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`validators`|`Validator[]`|Validator[] memory The set of infrared validators.|


### numInfraredValidators

Gets the number of infrared validators in validator set.


```solidity
function numInfraredValidators() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|num uint256 The number of infrared validators in validator set.|


### isInfraredValidator

Checks if a validator is an infrared validator.


```solidity
function isInfraredValidator(bytes memory _pubkey)
    external
    view
    returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pubkey`|`bytes`|   bytes      The pubkey of the validator to check.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|_isValidator bool       Whether the validator is an infrared validator.|


### getBGTBalance

Gets the BGT balance for this contract


```solidity
function getBGTBalance() external view returns (uint256 bgtBalance);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`bgtBalance`|`uint256`|The BGT balance held by this address|


## Events
### NewVault
Emitted when a new vault is registered


```solidity
event NewVault(
    address _sender,
    address indexed _asset,
    address indexed _vault,
    address[] _rewardTokens
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sender`|`address`|The address that initiated the vault registration|
|`_asset`|`address`|The address of the asset for which the vault is registered|
|`_vault`|`address`|The address of the newly created vault|
|`_rewardTokens`|`address[]`|An array of addresses of the reward tokens for the new vault|

### IBGTDistributed
Emitted when IBGT tokens are supplied to distributor.


```solidity
event IBGTDistributed(address indexed _distributor, uint256 _ibgtAmt);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_distributor`|`address`|The address of the distributor receiving the IBGT tokens.|
|`_ibgtAmt`|`uint256`|The amount of IBGT tokens supplied to distributor.|

### IBGTSupplied
Emitted when IBGT tokens are supplied to a vault.


```solidity
event IBGTSupplied(address indexed _vault, uint256 _ibgtAmt, uint256 _iredAmt);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_vault`|`address`|The address of the vault receiving the IBGT and IRED tokens.|
|`_ibgtAmt`|`uint256`|The amount of IBGT tokens supplied to vault.|
|`_iredAmt`|`uint256`|The amount of IRED tokens supplied to vault as additional reward from protocol.|

### RewardSupplied
Emitted when rewards are supplied to a vault.


```solidity
event RewardSupplied(
    address indexed _vault, address indexed _token, uint256 _amt
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_vault`|`address`|The address of the vault receiving the reward.|
|`_token`|`address`|The address of the token being supplied as a reward.|
|`_amt`|`uint256`|The amount of the reward token supplied.|

### BribeSupplied
Emitted when rewards are supplied to a vault.


```solidity
event BribeSupplied(
    address indexed _recipient, address indexed _token, uint256 _amt
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_recipient`|`address`|The address receiving the bribe.|
|`_token`|`address`|The address of the token being supplied as a bribe reward.|
|`_amt`|`uint256`|The amount of the bribe reward token supplied.|

### Recovered
Emitted when tokens are recovered from the contract.


```solidity
event Recovered(address _sender, address indexed _token, uint256 _amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sender`|`address`|The address that initiated the recovery.|
|`_token`|`address`|The address of the token being recovered.|
|`_amount`|`uint256`|The amount of the token recovered.|

### RewardTokenNotSupported
Emitted when a reward token is marked as unsupported.


```solidity
event RewardTokenNotSupported(address _token);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_token`|`address`|The address of the reward token.|

### IBGTUpdated
Emitted when the IBGT token address is updated.


```solidity
event IBGTUpdated(address _sender, address _oldIbgt, address _newIbgt);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sender`|`address`|The address that initiated the update.|
|`_oldIbgt`|`address`|The previous address of the IBGT token.|
|`_newIbgt`|`address`|The new address of the IBGT token.|

### IBGTVaultUpdated
Emitted when the IBGT vault address is updated.


```solidity
event IBGTVaultUpdated(
    address _sender, address _oldIbgtVault, address _newIbgtVault
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sender`|`address`|The address that initiated the update.|
|`_oldIbgtVault`|`address`|The previous address of the IBGT vault.|
|`_newIbgtVault`|`address`|The new address of the IBGT vault.|

### WhiteListedRewardTokensUpdated
Emitted when reward tokens are whitelisted or unwhitelisted.


```solidity
event WhiteListedRewardTokensUpdated(
    address _sender,
    address indexed _token,
    bool _wasWhitelisted,
    bool _isWhitelisted
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sender`|`address`|The address that initiated the update.|
|`_token`|`address`|The address of the token being updated.|
|`_wasWhitelisted`|`bool`|The previous whitelist status of the token.|
|`_isWhitelisted`|`bool`|The new whitelist status of the token.|

### RewardsDurationUpdated
Emitted when the rewards duration is updated


```solidity
event RewardsDurationUpdated(
    address _sender, uint256 _oldDuration, uint256 _newDuration
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sender`|`address`|The address that initiated the update|
|`_oldDuration`|`uint256`|The previous rewards duration|
|`_newDuration`|`uint256`|The new rewards duration|

### IredMintRateUpdated
Emitted when the IRED mint rate per unit IBGT is updated.


```solidity
event IredMintRateUpdated(
    address _sender, uint256 _oldMintRate, uint256 _newMintRate
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sender`|`address`|The address that initiated the update.|
|`_oldMintRate`|`uint256`|The previous IRED mint rate.|
|`_newMintRate`|`uint256`|The new IRED mint rate.|

### WeightUpdated
Emitted when a weight is updated.


```solidity
event WeightUpdated(
    address _sender,
    WeightType _weightType,
    uint256 _oldWeight,
    uint256 _newWeight
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sender`|`address`|The address that initiated the update.|
|`_weightType`|`WeightType`|The weight type updated.|
|`_oldWeight`|`uint256`|The old value of the weight.|
|`_newWeight`|`uint256`|The new value of the weight.|

### FeeUpdated
Emitted when protocol fee rate is updated.


```solidity
event FeeUpdated(
    address _sender, FeeType _feeType, uint256 _oldFeeRate, uint256 _newFeeRate
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sender`|`address`|The address that initiated the update.|
|`_feeType`|`FeeType`|The fee type updated.|
|`_oldFeeRate`|`uint256`|The old protocol fee rate.|
|`_newFeeRate`|`uint256`|The new protocol fee rate.|

### ProtocolFeesClaimed
Emitted when protocol fees claimed.


```solidity
event ProtocolFeesClaimed(
    address _sender, address _to, address _token, uint256 _amount
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sender`|`address`|The address that initiated the claim.|
|`_to`|`address`|The address to send protocol fees to.|
|`_token`|`address`|The address of the token protocol fees in.|
|`_amount`|`uint256`|The amount of protocol fees claimed.|

### BaseHarvested
Emitted when base + commission rewards are harvested.


```solidity
event BaseHarvested(address _sender, uint256 _bgtAmt);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sender`|`address`|The address that initiated the harvest.|
|`_bgtAmt`|`uint256`|The amount of BGT harvested.|

### VaultHarvested
Emitted when a vault harvests its rewards.


```solidity
event VaultHarvested(
    address _sender,
    address indexed _asset,
    address indexed _vault,
    uint256 _bgtAmt
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sender`|`address`|The address that initiated the harvest.|
|`_asset`|`address`|The asset associated with the vault being harvested.|
|`_vault`|`address`|The address of the vault being harvested.|
|`_bgtAmt`|`uint256`|The amount of BGT harvested.|

### BribesCollected
Emitted when bribes are harvested then collected by collector.


```solidity
event BribesCollected(
    address _sender,
    address _token,
    uint256 _amtWiberaVault,
    uint256 _amtIbgtVault
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sender`|`address`|The address that initiated the bribe collection.|
|`_token`|`address`|The payout token from bribe collection.|
|`_amtWiberaVault`|`uint256`|The amount of collected bribe sent to the wrapped iBERA vault.|
|`_amtIbgtVault`|`uint256`|The amount of collected bribe sent to the iBGT vault.|

### ValidatorHarvested
Emitted when a validator harvests its rewards.


```solidity
event ValidatorHarvested(
    address _sender,
    bytes indexed _validator,
    DataTypes.Token[] _rewards,
    uint256 _bgtAmt
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sender`|`address`|The address that initiated the harvest.|
|`_validator`|`bytes`|The public key of the validator.|
|`_rewards`|`DataTypes.Token[]`|An array of tokens and amounts harvested.|
|`_bgtAmt`|`uint256`|The amount of BGT included in the rewards.|

### ValidatorsAdded
Emitted when validators are added.


```solidity
event ValidatorsAdded(address _sender, Validator[] _validators);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sender`|`address`|The address that initiated the addition.|
|`_validators`|`Validator[]`|An array of validators that were added.|

### ValidatorsRemoved
Emitted when validators are removed from validator set.


```solidity
event ValidatorsRemoved(address _sender, bytes[] _pubkeys);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sender`|`address`|The address that initiated the removal.|
|`_pubkeys`|`bytes[]`|An array of validators' pubkeys that were removed.|

### ValidatorReplaced
Emitted when a validator is replaced with a new validator.


```solidity
event ValidatorReplaced(address _sender, bytes _current, bytes _new);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sender`|`address`|The address that initiated the replacement.|
|`_current`|`bytes`|The pubkey of the current validator being replaced.|
|`_new`|`bytes`|The pubkey of the new validator.|

### ValidatorCommissionUpdated
Emitted when a validator commission rate is updated.


```solidity
event ValidatorCommissionUpdated(
    address _sender, bytes _pubkey, uint256 _current, uint256 _new
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sender`|`address`|The address that initated the update.|
|`_pubkey`|`bytes`|The pubkey of the validator whose commission rate is being updated.|
|`_current`|`uint256`|The current commission rate being updated.|
|`_new`|`uint256`|The new commission rate being updated to.|

### QueuedBoosts
Emitted when BGT tokens are queued for boosts to validators.


```solidity
event QueuedBoosts(address _sender, bytes[] _pubkeys, uint128[] _amts);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sender`|`address`|The address that initiated the boost.|
|`_pubkeys`|`bytes[]`|The addresses of the validators to which tokens are queued for boosts.|
|`_amts`|`uint128[]`|The amounts of tokens that were queued.|

### CancelledBoosts
Emitted when existing queued boosts to validators are cancelled.


```solidity
event CancelledBoosts(address _sender, bytes[] _pubkeys, uint128[] _amts);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sender`|`address`|The address that initiated the cancellation.|
|`_pubkeys`|`bytes[]`|The pubkeys of the validators to which tokens were queued for boosts.|
|`_amts`|`uint128[]`|The amounts of tokens to remove from boosts.|

### ActivatedBoosts
Emitted when an existing boost to a validator is activated.


```solidity
event ActivatedBoosts(address _sender, bytes[] _pubkeys);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sender`|`address`|The address that initiated the activation.|
|`_pubkeys`|`bytes[]`|The addresses of the validators which were boosted.|

### DroppedBoosts
Emitted when boost is removed from a validator.


```solidity
event DroppedBoosts(address _sender, bytes[] _pubkeys, uint128[] _amts);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sender`|`address`|The address that initiated the cancellation.|
|`_pubkeys`|`bytes[]`|The addresses of the validators to which tokens were queued for boosts.|
|`_amts`|`uint128[]`|The amounts of tokens to remove from boosts.|

### Undelegated
Emitted when tokens are undelegated from a validator.


```solidity
event Undelegated(address _sender, bytes _pubkey, uint256 _amt);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sender`|`address`|The address that initiated the undelegation.|
|`_pubkey`|`bytes`|The pubkey of the validator from which tokens are undelegated.|
|`_amt`|`uint256`|The amount of tokens that were undelegated.|

### Redelegated
Emitted when tokens are redelegated from one validator to another.


```solidity
event Redelegated(address _sender, bytes _from, bytes _to, uint256 _amt);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sender`|`address`|The address that initiated the redelegation.|
|`_from`|`bytes`|The public key of the validator from which tokens are redelegated.|
|`_to`|`bytes`|The public key of the validator to which tokens are redelegated.|
|`_amt`|`uint256`|The amount of tokens that were redelegated.|

## Structs
### Validator
Validator information for validator set


```solidity
struct Validator {
    bytes pubkey;
    address addr;
    uint256 commission;
}
```

## Enums
### WeightType
Weight type enum for determining how much to weight reward distribution amongst recipients


```solidity
enum WeightType {
    CollectBribesIBERA
}
```

### FeeType
Fee type enum for determining rates to charge on reward distribution.


```solidity
enum FeeType {
    HarvestBaseFeeRate,
    HarvestBaseProtocolRate,
    HarvestVaultFeeRate,
    HarvestVaultProtocolRate,
    HarvestBribesFeeRate,
    HarvestBribesProtocolRate,
    HarvestBoostFeeRate,
    HarvestBoostProtocolRate
}
```

