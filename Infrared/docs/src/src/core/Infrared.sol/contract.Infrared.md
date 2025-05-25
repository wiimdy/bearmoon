# Infrared
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/core/Infrared.sol)

**Inherits:**
[InfraredUpgradeable](/src/core/InfraredUpgradeable.sol/abstract.InfraredUpgradeable.md), [IInfrared](/src/interfaces/IInfrared.sol/interface.IInfrared.md)

*A contract for managing the set of infrared validators, infrared vaults, and interacting with the rewards handler.*

*This contract is the main entry point for interacting with the Infrared protocol.*

*It is an immutable contract that interacts with the upgradable rewards handler and staking handler. These contracts are upgradable by governance (app + chain), main reason is that they could change with a chain upgrade.*


## State Variables
### whitelistedRewardTokens
Mapping of tokens that are whitelisted to be used as rewards or accepted as bribes

*serves as central source of truth for whitelisted reward tokens for all Infrared contracts*


```solidity
mapping(address => bool) public whitelistedRewardTokens;
```


### vaultRegistry
Mapping of staking token addresses to their corresponding InfraredVault

*Each staking token can only have one vault*


```solidity
mapping(address => IInfraredVault) public vaultRegistry;
```


### _infraredValidatorIds
Set of infrared validator IDs where an ID is keccak256(pubkey)

*Used to track active validators in the system*


```solidity
EnumerableSet.Bytes32Set internal _infraredValidatorIds;
```


### _infraredValidatorPubkeys
Mapping of validator IDs to their CL public keys

*Maps the keccak256 hash of a validator's pubkey to their actual pubkey*


```solidity
mapping(bytes32 id => bytes pub) internal _infraredValidatorPubkeys;
```


### _bgt
The BGT token contract reference

*Immutable IBerachainBGT instance of the BGT token*


```solidity
IBerachainBGT internal immutable _bgt;
```


### ibgt
The IBGT liquid staked token


```solidity
IIBGT public immutable ibgt;
```


### ired
The Infrared governance token


```solidity
IERC20Mintable public immutable ired;
```


### wibera
The wrapped Infrared bera token


```solidity
IERC20 public immutable wibera;
```


### rewardsFactory
The Berachain rewards vault factory address


```solidity
IBerachainRewardsVaultFactory public immutable rewardsFactory;
```


### chef
The Berachain chef contract for distributing validator rewards


```solidity
IBeraChef public immutable chef;
```


### wbera
Wrapped bera


```solidity
IWBERA public immutable wbera;
```


### honey
Honey ERC20 token


```solidity
IERC20 public immutable honey;
```


### collector
bribe collector contract


```solidity
IBribeCollector public collector;
```


### distributor
Infrared distributor for BGT rewards to validators


```solidity
IInfraredDistributor public distributor;
```


### voter
IRED voter


```solidity
IVoter public voter;
```


### rewardsDuration
The rewards duration

*Used as gloabl variabel to set the rewards duration for all new reward tokens on InfraredVaults*


```solidity
uint256 public rewardsDuration;
```


### iredMintRate
The mint amount of IRED rewards minted per IBGT


```solidity
uint256 public iredMintRate;
```


### ibgtVault
The IBGT vault


```solidity
IInfraredVault public ibgtVault;
```


### wiberaVault
The wrapped IBERA vault


```solidity
IInfraredVault public wiberaVault;
```


### protocolFeeAmounts
The unclaimed Infrared protocol fees of token accumulated by contract


```solidity
mapping(address => uint256) public protocolFeeAmounts;
```


### weights
Weights for various harvest function distributions


```solidity
mapping(uint256 => uint256) public weights;
```


### fees
Protocol fee rates to charge for various harvest function distributions


```solidity
mapping(uint256 => uint256) public fees;
```


### WEIGHT_UNIT
Weight units when partitioning reward amounts in hundredths of 1 bip

*Used as the denominator when calculating weighted distributions (1e6)*


```solidity
uint256 internal constant WEIGHT_UNIT = 1e6;
```


### FEE_UNIT
Protocol fee rate in hundredths of 1 bip

*Used as the denominator when calculating protocol fees (1e6)*


```solidity
uint256 internal constant FEE_UNIT = 1e6;
```


### RATE_UNIT
IRED mint rate in hundredths of 1 bip

*Used as the denominator when calculating IRED minting (1e6)*


```solidity
uint256 internal constant RATE_UNIT = 1e6;
```


### COMMISSION_MAX
Commission rate in units of 1 bip

*Maximum commission rate that can be set (1e3)*


```solidity
uint256 internal constant COMMISSION_MAX = 1e3;
```


## Functions
### onlyCollector

*Ensures that only the collector contract can call the function
Reverts if the caller is not the collector*


```solidity
modifier onlyCollector();
```

### constructor


```solidity
constructor(
    address _ibgt,
    address _rewardsFactory,
    address _chef,
    address _wbera,
    address _honey,
    address _ired,
    address _wibera
) InfraredUpgradeable(address(0));
```

### initialize


```solidity
function initialize(
    address _admin,
    address _collector,
    address _distributor,
    address _voter,
    uint256 _rewardsDuration
) external initializer;
```

### _registerVault

Registers a new vault


```solidity
function _registerVault(address _asset, address[] memory _rewardTokens)
    private
    returns (address _new);
```

### registerVault

Registers a new vault for a given asset and initializes it with reward tokens

*Infrared.sol must be admin over MINTER_ROLE on IBGT to grant minter role to deployed vault*


```solidity
function registerVault(address _asset, address[] memory _rewardTokens)
    external
    onlyKeeper
    whenInitialized
    returns (IInfraredVault);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_asset`|`address`|The address of the asset, such as a specific LP token|
|`_rewardTokens`|`address[]`|The addresses of reward tokens to initialize with the new vault|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IInfraredVault`|vault The address of the newly created InfraredVault contract|


### _updateWhiteListedRewardTokens

Updates whitelisted reward tokens


```solidity
function _updateWhiteListedRewardTokens(address _token, bool _whitelisted)
    private;
```

### updateWhiteListedRewardTokens

Updates the whitelist status of a reward token


```solidity
function updateWhiteListedRewardTokens(address _token, bool _whitelisted)
    external
    onlyGovernor
    whenInitialized;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_token`|`address`|The address of the token to whitelist or remove from whitelist|
|`_whitelisted`|`bool`|A boolean indicating if the token should be whitelisted|


### updateRewardsDuration

Sets the new duration for reward distributions in InfraredVaults


```solidity
function updateRewardsDuration(uint256 _rewardsDuration)
    external
    onlyGovernor
    whenInitialized;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_rewardsDuration`|`uint256`|The new reward duration period, in seconds|


### updateIredMintRate

Updates the IRED mint rate per unit of IBGT


```solidity
function updateIredMintRate(uint256 _iredMintRate)
    external
    onlyGovernor
    whenInitialized;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_iredMintRate`|`uint256`|The new IRED mint rate in units of 1e6 (hundredths of 1 bip)|


### pauseVault

Pauses staking functionality on a specific vault

*Only callable by governance, will revert if vault doesn't exist*


```solidity
function pauseVault(address _asset) external onlyGovernor whenInitialized;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_asset`|`address`|The address of the staking asset associated with the vault to pause|


### recoverERC20

Recovers ERC20 tokens sent accidentally to the contract


```solidity
function recoverERC20(address _to, address _token, uint256 _amount)
    external
    onlyGovernor
    whenInitialized;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_to`|`address`|The address to receive the recovered tokens|
|`_token`|`address`|The address of the token to recover|
|`_amount`|`uint256`|The amount of the token to recover|


### delegateBGT

Delegates BGT votes to `_delegatee` address.


```solidity
function delegateBGT(address _delegatee)
    external
    onlyGovernor
    whenInitialized;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_delegatee`|`address`| address The address to delegate votes to|


### updateWeight

Updates the weight for a weight type.


```solidity
function updateWeight(WeightType _t, uint256 _weight)
    external
    onlyGovernor
    whenInitialized;
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
function updateFee(FeeType _t, uint256 _fee)
    external
    onlyGovernor
    whenInitialized;
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
    external
    onlyGovernor
    whenInitialized;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_to`|`address`|    address The recipient of the fees|
|`_token`|`address`| address The token to claim fees in|
|`_amount`|`uint256`|uint256 The amount of accumulated fees to claim|


### chargedFeesOnRewards


```solidity
function chargedFeesOnRewards(
    uint256 _amt,
    uint256 _feeTotal,
    uint256 _feeProtocol
)
    public
    view
    returns (uint256 amtRecipient, uint256 amtVoter, uint256 amtProtocol);
```

### _distributeFeesOnRewards


```solidity
function _distributeFeesOnRewards(
    address _token,
    uint256 _amtVoter,
    uint256 _amtProtocol
) internal;
```

### harvestBase

Claims all the BGT base and commission rewards minted to this contract for validators.


```solidity
function harvestBase() external whenInitialized;
```

### harvestVault

Claims all the BGT rewards for the vault associated with the given staking token.


```solidity
function harvestVault(address _asset) external whenInitialized;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_asset`|`address`|address The address of the staking asset that the vault is for.|


### harvestBribes

Claims all the bribes rewards in the contract forwarded from Berachain POL.


```solidity
function harvestBribes(address[] memory _tokens) external whenInitialized;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokens`|`address[]`|address[] memory The addresses of the tokens to harvest in the contract.|


### collectBribes

Collects bribes from bribe collector and distributes to wiBERA and iBGT Infrared vaults.


```solidity
function collectBribes(address _token, uint256 _amount)
    external
    onlyCollector
    whenInitialized;
```

### harvestBoostRewards

Claims all the BGT staker rewards from boosting validators.

*Sends rewards to iBGT vault.*


```solidity
function harvestBoostRewards() external whenInitialized;
```

### _handleTokenRewardsForVault

Handles non-IBGT token rewards to the vault.


```solidity
function _handleTokenRewardsForVault(
    IInfraredVault _vault,
    address _token,
    uint256 _amount,
    uint256 _feeTotal,
    uint256 _feeProtocol
) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_vault`|`IInfraredVault`|      IInfraredVault   The address of the vault.|
|`_token`|`address`|      address          The reward token.|
|`_amount`|`uint256`|     uint256          The amount of reward token to send to vault.|
|`_feeTotal`|`uint256`|   uint256          The rate to charge for total fees on `_amount`.|
|`_feeProtocol`|`uint256`|uint256          The rate to charge for protocol treasury on total fees.|


### _handleTokenBribesForReceiver

Handles non-IBGT token bribe rewards to a non-vault receiver address.

*Does *not* take protocol fee on bribe coin, as taken on bribe collector payout token in eventual callback.*


```solidity
function _handleTokenBribesForReceiver(
    address _recipient,
    address _token,
    uint256 _amount
) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_recipient`|`address`|address  The address of the recipient.|
|`_token`|`address`|    address  The address of the token to forward to recipient.|
|`_amount`|`uint256`||


### _handleBGTRewardsForVault

Handles BGT token rewards, minting IBGT and supplying to the vault.


```solidity
function _handleBGTRewardsForVault(
    IInfraredVault _vault,
    uint256 _bgtAmt,
    uint256 _feeTotal,
    uint256 _feeProtocol
) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_vault`|`IInfraredVault`|      address         The address of the vault.|
|`_bgtAmt`|`uint256`|     uint256         The BGT reward amount.|
|`_feeTotal`|`uint256`|   uint256         The rate to charge for total fees on iBGT `_bgtAmt`.|
|`_feeProtocol`|`uint256`|uint256         The rate to charge for protocol treasury on total iBGT fees.|


### _handleBGTRewardsForDistributor

Handles BGT base rewards supplied to validator distributor.


```solidity
function _handleBGTRewardsForDistributor(
    uint256 _bgtAmt,
    uint256 _feeTotal,
    uint256 _feeProtocol
) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bgtAmt`|`uint256`|     uint256         The BGT reward amount.|
|`_feeTotal`|`uint256`|   uint256         The rate to charge for total fees on `_bgtAmt`.|
|`_feeProtocol`|`uint256`|uint256         The rate to charge for protocol treasury on total fees.|


### _getValidatorId

Gets the validator ID for associated CL pubkey


```solidity
function _getValidatorId(bytes memory pubkey) internal pure returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pubkey`|`bytes`|The CL pubkey of validator|


### _addValidatorToSet

Adds validator pubkey to validator set

*Reverts if already exists in set*


```solidity
function _addValidatorToSet(bytes memory pubkey) private;
```

### _removeValidatorFromSet

Removes validator pubkey from validator set

*Reverts if does not already exist in set*


```solidity
function _removeValidatorFromSet(bytes memory pubkey) private;
```

### addValidators

Adds validators to the set of `InfraredValidators`.


```solidity
function addValidators(Validator[] memory _validators)
    external
    onlyGovernor
    whenInitialized;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_validators`|`Validator[]`|Validator[] memory The validators to add.|


### removeValidators

Removes validators from the set of `InfraredValidators`.


```solidity
function removeValidators(bytes[] memory _pubkeys)
    external
    onlyGovernor
    whenInitialized;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pubkeys`|`bytes[]`|bytes[] memory The pubkeys of the validators to remove.|


### replaceValidator

Replaces a validator in the set of `InfraredValidators`.


```solidity
function replaceValidator(bytes calldata _current, bytes calldata _new)
    external
    onlyGovernor
    whenInitialized;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_current`|`bytes`|bytes The pubkey of the validator to replace.|
|`_new`|`bytes`|    bytes The new validator pubkey.|


### _getValidatorCommission

Gets the current validator commission rate by calling BGT.


```solidity
function _getValidatorCommission(bytes memory _pubkey)
    internal
    view
    returns (uint256 rate);
```

### _getValidatorAddress

Gets the validator address for claiming on distributor associated with pubkey


```solidity
function _getValidatorAddress(bytes memory _pubkey)
    internal
    view
    returns (address);
```

### queueNewCuttingBoard

Queues a new cutting board on BeraChef for reward weight distribution for validator


```solidity
function queueNewCuttingBoard(
    bytes calldata _pubkey,
    uint64 _startBlock,
    IBeraChef.Weight[] calldata _weights
) external onlyKeeper;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pubkey`|`bytes`|            bytes                         The pubkey of the validator to queue the cutting board for|
|`_startBlock`|`uint64`|        uint64                        The start block for reward weightings|
|`_weights`|`IBeraChef.Weight[]`|           IBeraChef.Weight[] calldata   The weightings used when distributor calls chef to distribute validator rewards|


### queueBoosts

Queue `_amts` of tokens to `_validators` for boosts.


```solidity
function queueBoosts(bytes[] memory _pubkeys, uint128[] memory _amts)
    external
    onlyKeeper
    whenInitialized;
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
    external
    onlyKeeper
    whenInitialized;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pubkeys`|`bytes[]`|    bytes[] memory The pubkeys of the validators to remove boosts for.|
|`_amts`|`uint128[]`|       uint128[] memory The amounts of BGT to remove from the queued boosts.|


### activateBoosts

Activates queued boosts for `_pubkeys`.


```solidity
function activateBoosts(bytes[] memory _pubkeys) external whenInitialized;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pubkeys`|`bytes[]`|  bytes[] memory The pubkeys of the validators to activate boosts for.|


### infraredValidators

Gets the set of infrared validator pubkeys.


```solidity
function infraredValidators()
    public
    view
    virtual
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
function isInfraredValidator(bytes memory _validator)
    public
    view
    returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_validator`|`bytes`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|_isValidator bool       Whether the validator is an infrared validator.|


### getBGTBalance

Gets the BGT balance for this contract


```solidity
function getBGTBalance() public view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|bgtBalance The BGT balance held by this address|


