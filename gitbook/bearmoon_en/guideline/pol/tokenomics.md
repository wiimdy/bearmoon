---
icon: coins
---

# PoL Security Guidelines: Tokenomics

<table><thead><tr><th width="595.53515625">Threat</th><th align="center">Impact</th></tr></thead><tbody><tr><td><a data-mention href="tokenomics.md#id-1-bgt">#1 Liquidity crisis due to native token shortage during BGT redemption</a></td><td align="center"><code>High</code></td></tr><tr><td><a data-mention href="tokenomics.md#id-2-bgt">#2 Operators collude to concentrate BGT rewards in a specific reward vault, leading to liquidity concentration and depletion of other protocols' liquidity</a></td><td align="center"><code>Medium</code></td></tr><tr><td><a data-mention href="tokenomics.md#id-3-lsd-boost-bgt">#3 Profit-taking by repeatedly creating new vaults after LSD protocol's BGT boost ends</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="tokenomics.md#id-4">#4 BGT Inflation Manipulation</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="tokenomics.md#id-5-apr">#5 Inaccurate APR calculation and display</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="tokenomics.md#id-6-claimfees">#6 Unclaimed rewards (`claimFees`) are not properly burned</a></td><td align="center"><code>Low</code></td></tr></tbody></table>

### <a href="#id-1-bgt" id="id-1-bgt"></a>Threat 1: Liquidity crisis due to native token shortage during BGT redemption

If the target contract has an insufficient amount of native tokens during BGT redemption, some users will not be able to receive their rewards, and their reward claim transactions will be reverted, leading to a liquidity crisis.

#### Impact

`High`

If the redemptions of many users fail due to a shortage of native tokens, it can directly lead to a loss of trust, a large-scale capital outflow, and a system-wide liquidity crisis. Therefore, it is rated `High`.

#### Guideline

> - **Validation during BGT redemption:**
>   - Check contract balance:
>     - Use `safeTransferETH` in the `redeem` function to revert if the balance is insufficient when transferring BERA.
>   - Verify redemption request amount:
>     - Use the `checkUnboostedBalance` function to verify that the user's redemption request amount is less than or equal to the unboosted BGT amount.
> - **Ensure sufficient native token holdings in the contract:**
>   - Guarantee finality after redemption:
>     - After the redemption process is completed, use `_invariantCheck` to compare the current total BGT supply with the amount of native tokens held to verify that a sufficient amount of native tokens is held.
>   - BERA issuance settings in the chain spec:
>     ```toml
>     # Deneb1 value changes
>     # Issue 5.75 BERA per block to the BGT token contract address
>     evm-inflation-address-deneb-one = "0x656b95E550C07a9ffe548bd4085c72418Ceb1dba"
>     evm-inflation-per-block-deneb-one = 5_750_000_000
>     ```
>   - **Manage excess token holdings and maintain an appropriate buffer:**
>     - When calculating the expected BGT issuance, calculate an accurate expected amount considering factors such as the block buffer size and BGT issuance per block.
>       - Calculate the maximum BGT that can be issued per block by inputting 100% for `boostPower` in the `computeReward` function of `BlockRewardController`.
>       - Set `HISTORY_BUFFER_LENGTH` to 8191 in accordance with EIP-4788.
>       - Calculate the potential BGT issuance with the above two values, then add it to the current BGT issuance to calculate `outstandingRequiredAmount`.
>       - If the native token balance exceeds the `outstandingRequiredAmount` value, burn the excess amount to the zero address through the `burnExceedingReserves` function.

#### Best Practice

[`BGT.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/pol/BGT.sol#L369)

{% code overflow="wrap" %}

```solidity
/// @inheritdoc IBGT
function redeem(
    address receiver,
    uint256 amount
)
    external
    invariantCheck
    checkUnboostedBalance(msg.sender, amount)
{
    /// Burn the BGT token from the msg.sender account and reduce the total supply.
    super._burn(msg.sender, amount);
    /// Transfer the Native token to the receiver.
    SafeTransferLib.safeTransferETH(receiver, amount);
    emit Redeem(msg.sender, receiver, amount);
}


function _checkUnboostedBalance(address sender, uint256 amount) private view {
    if (unboostedBalanceOf(sender) < amount) NotEnoughBalance.selector.revertWith();
}


function unboostedBalanceOf(address account) public view returns (uint256) {
    UserBoost storage userBoost = userBoosts[account];
    (uint128 boost, uint128 _queuedBoost) = (userBoost.boost, userBoost.queuedBoost);
    return balanceOf(account) - boost - _queuedBoost;
}

/// @inheritdoc IBGT
function burnExceedingReserves() external {
    IBlockRewardController br = IBlockRewardController(_blockRewardController);
    uint256 potentialMintableBGT = HISTORY_BUFFER_LENGTH * br.getMaxBGTPerBlock();
    uint256 currentReservesAmount = address(this).balance;
    uint256 outstandingRequiredAmount = totalSupply() + potentialMintableBGT;
    if (currentReservesAmount <= outstandingRequiredAmount) return;

    uint256 excessAmountToBurn = currentReservesAmount - outstandingRequiredAmount;
    SafeTransferLib.safeTransferETH(address(0), excessAmountToBurn);

    emit ExceedingReservesBurnt(msg.sender, excessAmountToBurn);
}

// Verify contract state consistency
modifier invariantCheck() {
    _;

    _invariantCheck();
}

function _invariantCheck() private view {
    if (address(this).balance < totalSupply()) InvariantCheckFailed.selector.revertWith();
}
```

{% endcode %}

[`BlockRewardController.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/pol/rewards/BlockRewardController.sol#L167-L210)

{% code overflow="wrap" %}

```solidity
/// @inheritdoc IBlockRewardController
function computeReward(
    uint256 boostPower,
    uint256 _rewardRate,
    uint256 _boostMultiplier,
    int256 _rewardConvexity
)
    public
    pure
    returns (uint256 reward)
{
    // On conv == 0, mathematical result should be max reward even for boost == 0 (0^0 = 1)
    // but since BlockRewardController enforces conv > 0, we're not adding code for conv == 0 case
    if (boostPower > 0) {
        // Compute intermediate parameters for the reward formula
        uint256 one = FixedPointMathLib.WAD;

        if (boostPower == one) {
            // avoid approx errors in the following code
            reward = FixedPointMathLib.mulWad(_rewardRate, _boostMultiplier);
        } else {
            // boost^conv ∈ (0, 1]
            uint256 tmp_0 = uint256(FixedPointMathLib.powWad(int256(boostPower), _rewardConvexity));
            // 1 + mul * boost^conv ∈ [1, 1 + mul]
            uint256 tmp_1 = one + FixedPointMathLib.mulWad(_boostMultiplier, tmp_0);
            // 1 - 1 / (1 + mul * boost^conv) ∈ [0, mul / (1 + mul)]
            uint256 tmp_2 = one - FixedPointMathLib.divWad(one, tmp_1);

            // @dev Due to splitting fixed point ops, [mul / (1 + mul)] * (1 + mul) may be slightly > mul
            uint256 coeff = FixedPointMathLib.mulWad(tmp_2, one + _boostMultiplier);
            if (coeff > _boostMultiplier) coeff = _boostMultiplier;

            reward = FixedPointMathLib.mulWad(_rewardRate, coeff);
        }
    }
}
// Amount of BGT issued when boostpower = 100%
/// @inheritdoc IBlockRewardController
function getMaxBGTPerBlock() public view returns (uint256 amount) {
    amount = computeReward(FixedPointMathLib.WAD, rewardRate, boostMultiplier, rewardConvexity);
    if (amount < minBoostedRewardRate) {
        amount = minBoostedRewardRate;
    }
    amount += baseRate;
}


```

{% endcode %}

---

### <a href="#id-2-bgt" id="id-2-bgt"></a>Threat 2: Operators collude to concentrate BGT rewards in a specific **reward vault**, leading to liquidity concentration and depletion of other protocols' liquidity

If operators collude to direct BGT rewards to a specific reward vault, the liquidity of some reward vaults will be depleted, and the liquidity of other protocols will also decrease.

#### Impact

`Medium`

If liquidity is concentrated in some vaults, it can lead to market distortion and service imbalances due to the depletion of liquidity in other vaults and protocols. However, since it does not directly lead to an immediate system-wide paralysis or catastrophic loss, it is rated `Medium`.

#### Guideline

> - **Force rewards to be distributed to multiple reward vaults to prevent concentration in a single vault.**
>   - Manage all created reward vault addresses (receivers) through the `Weight` struct.
>   - To receive rewards, a reward vault address (receiver) must be [registered in the whitelist through governance](../../reference.md#undefined-5).
>     - Simply being created in the `Weight` struct does not mean it can be allocated rewards.
> - **Prevent an operator from concentrating rewards in a single vault through multiple transactions.**
>
>   ```solidity
>   /// @notice The delay in blocks before a new reward allocation can go into effect.
>   uint64 public rewardAllocationBlockDelay;
>   // Currently set to 2000 blocks (approx. 4000 seconds)
>
>   // function queueNewRewardAllocation
>   if (startBlock <= block.number + rewardAllocationBlockDelay) {
>       InvalidStartBlock.selector.revertWith();
>   }
>   // function _validateWeights
>   if (totalWeight != ONE_HUNDRED_PERCENT) {
>           InvalidRewardAllocationWeights.selector.revertWith();
>       }
>   ```
>
>   - Introduce a delay (approx. 2000 blocks) for reward allocation so that it is not reflected immediately. Also, by requiring each allocation to distribute 100% of the total rewards, it prevents the distribution of rewards in parts through multiple transactions.
>
> - **If a single operator operates multiple validators, prevent them from concentrating the rewards of multiple validators in a specific vault.**
>   - **`queueNewRewardAllocation`**: Check the operator's total allocation limit.
>   - **`activateReadyQueuedRewardAllocation`**: Reflect the actual allocation and update the cumulative value.
>   - **`lastActiveWeights`**: Track the last activated `RewardAllocation` for each validator.
>   - **`operatorVaultAllocations`**: Track the total allocation ratio for each vault by operator.
>   - For detailed implementation, refer to the [Custom Code](tokenomics.md#undefined-4) below.
> - [**Prevent a situation where multiple operators collude to concentrate rewards in a specific vault.**](../../reference.md#weight)
>   - If the total allocation of all operators to a specific vault exceeds a certain limit, introduce a function to temporarily suspend reward allocation to that vault (= the vault cannot be selected in `RewardAllocation`).
>   - Track the total allocation sum for each vault.
>   - If the limit is exceeded, the vault cannot be included in `RewardAllocation` (queuing itself will revert).
>   - Allocation can be resumed once it falls below the limit.
>   - For detailed implementation, refer to the [Custom Code](tokenomics.md#undefined-5) below.

#### Best Practice

[`BeraChef.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/pol/rewards/BeraChef.sol#L392-L394)

{% code overflow="wrap" %}

```solidity
/// @notice Mapping of receiver address to whether they are white-listed or not.
mapping(address receiver => bool) public isWhitelistedVault;

/// @dev Represents 100%. Chosen to be less granular.
uint96 internal constant ONE_HUNDRED_PERCENT = 1e4;
/// @notice The maximum weight a vault can assume in the reward allocation
uint96 public maxWeightPerVault;
// Currently set to 3000!!

// The RewardAllocation struct is composed of multiple Weights.
struct Weight {
    address receiver;           // RewardVault address
    uint96 percentageNumerator; // Reward percentage for the vault
}

/// @inheritdoc IBeraChef
function queueNewRewardAllocation(
    bytes calldata valPubkey,
    uint64 startBlock,
    Weight[] calldata weights
)
    external
    onlyOperator(valPubkey)
{
    // adds a delay before a new reward allocation can go into effect
    if (startBlock <= block.number + rewardAllocationBlockDelay) {
        InvalidStartBlock.selector.revertWith();
    }

    RewardAllocation storage qra = queuedRewardAllocations[valPubkey];

    // do not allow to queue a new reward allocation if there is already one queued
    if (qra.startBlock > 0) {
        RewardAllocationAlreadyQueued.selector.revertWith();
    }

    // validate if the weights are valid.
    _validateWeights(valPubkey, weights);

    // queue the new reward allocation
    qra.startBlock = startBlock;
    Weight[] storage storageWeights = qra.weights;
    for (uint256 i; i < weights.length;) {
        storageWeights.push(weights[i]);
        unchecked {
            ++i;
        }
    }
    emit QueueRewardAllocation(valPubkey, startBlock, weights);
}

function _validateWeights(bytes memory valPubkey, Weight[] calldata weights) internal {
    if (weights.length > maxNumWeightsPerRewardAllocation) {
        TooManyWeights.selector.revertWith();
    }
    _checkForDuplicateReceivers(valPubkey, weights);

    uint96 totalWeight;
    for (uint256 i; i < weights.length;) {
        Weight calldata weight = weights[i];

        if (weight.percentageNumerator == 0 || weight.percentageNumerator > maxWeightPerVault) {
            InvalidWeight.selector.revertWith();
        }

        // Original: Whitelist check
        if (!isWhitelistedVault[weight.receiver]) {
            NotWhitelistedVault.selector.revertWith();
        }

        // Incentive threshold check: all incentive token balances must be above the threshold
        address vault = weight.receiver;
        bool isSufficient = RewardVault(vault).getCurrentIncentiveBalance();
        if (!isSufficient) {
            // Vaults with insufficient incentives cannot be included in the reward allocation
            InvalidWeight.selector.revertWith();
        }

        totalWeight += weight.percentageNumerator;
        unchecked { ++i; }
    }
    if (totalWeight != ONE_HUNDRED_PERCENT) {
        InvalidRewardAllocationWeights.selector.revertWith();
    }
}

function _checkForDuplicateReceivers(bytes memory valPubkey, Weight[] calldata weights) internal {
    // use pubkey as identifier for the slot
    bytes32 slotIdentifier = keccak256(valPubkey);

    for (uint256 i; i < weights.length;) {
        address receiver = weights[i].receiver;
        bool duplicate;

        assembly ("memory-safe") {
            // Get free memory pointer
            let memPtr := mload(0x40)
            // Store receiver address at the first 32 bytes position
            mstore(memPtr, receiver)
            // Store slot identifier at the next 32 bytes position
            mstore(add(memPtr, 0x20), slotIdentifier)
            // Calculate storage key
            let storageKey := keccak256(memPtr, 0x40)
            // Check if receiver is already seen
            duplicate := tload(storageKey)
            if iszero(duplicate) { tstore(storageKey, 1) }
        }
        if (duplicate) {
            DuplicateReceiver.selector.revertWith(receiver);
        }
        unchecked {
            ++i;
        }
    }
}
```

{% endcode %}

`Custom Code`

<details>

<summary>Preventing a single operator running multiple validators from concentrating rewards in a specific vault</summary>

{% code overflow="wrap" %}

```solidity
// Total allocation ratio (cumulative) per operator, per vault
mapping(address operator => mapping(address vault => uint96 totalAllocated)) public operatorVaultAllocations;

// Stores the last activated RewardAllocation weights per validator (pubkey)
mapping(bytes valPubkey => Weight[]) internal lastActiveWeights;

function _validateOperatorTotalAllocation(
    address operator,
    Weight[] calldata newWeights,
    Weight[] storage oldWeights,
    uint96 maxTotalPerVault
) internal view {
    // Temporary mapping: vault-wise cumulative sum
    mapping(address => uint96) memory tempTotal;

    // Copy existing operatorVaultAllocations
    // (oldWeights is the previous allocation for this validator, newWeights is the new allocation to be queued)
    // Subtract oldWeights from the existing allocation and add newWeights

    // 1. Copy existing operatorVaultAllocations
    for (uint i = 0; i < newWeights.length; i++) {
        address vault = newWeights[i].receiver;
        tempTotal[vault] = operatorVaultAllocations[operator][vault];
    }
    for (uint i = 0; i < oldWeights.length; i++) {
        address vault = oldWeights[i].receiver;
        tempTotal[vault] = operatorVaultAllocations[operator][vault];
    }

    // 2. Subtract oldWeights
    for (uint i = 0; i < oldWeights.length; i++) {
        address vault = oldWeights[i].receiver;
        tempTotal[vault] -= oldWeights[i].percentageNumerator;
    }

    // 3. Add newWeights and check limit
    for (uint i = 0; i < newWeights.length; i++) {
        address vault = newWeights[i].receiver;
        tempTotal[vault] += newWeights[i].percentageNumerator;
        require(
            tempTotal[vault] <= maxTotalPerVault,
            "Too much allocation to one vault for this operator"
        );
    }
}

function _updateOperatorVaultAllocations(
    address operator,
    Weight[] storage oldWeights,
    Weight[] calldata newWeights
) internal {
    // Subtract oldWeights
    for (uint i = 0; i < oldWeights.length; i++) {
        address vault = oldWeights[i].receiver;
        operatorVaultAllocations[operator][vault] -= oldWeights[i].percentageNumerator;
    }
    // Add newWeights
    for (uint i = 0; i < newWeights.length; i++) {
        address vault = newWeights[i].receiver;
        operatorVaultAllocations[operator][vault] += newWeights[i].percentageNumerator;
    }
}

function queueNewRewardAllocation(
    bytes calldata valPubkey,
    uint64 startBlock,
    Weight[] calldata weights
) external onlyOperator(valPubkey) {
    // ... existing validation ...

    // 1. Extract operator address
    address operator = beaconDepositContract.getOperator(valPubkey);

    // 2. Previous activated RewardAllocation weights for this validator
    Weight[] storage oldWeights = lastActiveWeights[valPubkey];

    // 3. Check total allocation limit (e.g., 70% = 7000)
    _validateOperatorTotalAllocation(operator, weights, oldWeights, 7000);

    // ... existing queuing logic ...
}

function activateReadyQueuedRewardAllocation(bytes calldata valPubkey) external onlyDistributor {
    if (!isQueuedRewardAllocationReady(valPubkey, block.number)) return;
    RewardAllocation storage qra = queuedRewardAllocations[valPubkey];
    uint64 startBlock = qra.startBlock;

    // Extract operator address
    address operator = beaconDepositContract.getOperator(valPubkey);

    // Previous weights
    Weight[] storage oldWeights = lastActiveWeights[valPubkey];

    // Update operatorVaultAllocations
    _updateOperatorVaultAllocations(operator, oldWeights, qra.weights);

    // Update lastActiveWeights
    delete lastActiveWeights[valPubkey];
    for (uint i = 0; i < qra.weights.length; i++) {
        lastActiveWeights[valPubkey].push(qra.weights[i]);
    }

    activeRewardAllocations[valPubkey] = qra;
    emit ActivateRewardAllocation(valPubkey, startBlock, qra.weights);
    delete queuedRewardAllocations[valPubkey];
}
```

{% endcode %}

</details>

<details>

<summary>Preventing multiple operators from colluding to concentrate rewards in a specific vault</summary>

{% code overflow="wrap" %}

```solidity
// Total allocation sum per vault (sum of all operators)
mapping(address vault => uint96 totalAllocatedByAllOperators) public vaultTotalAllocations;

// Allocation limit per vault (e.g., 8000 = 80%, this value can be modified by governance)
uint96 public constant VAULT_TOTAL_ALLOCATION_LIMIT = 8000;

function _validateVaultTotalAllocation(
    Weight[] calldata newWeights,
    Weight[] storage oldWeights
) internal view {
    // Temporary mapping: vault-wise cumulative sum
    mapping(address => uint96) memory tempTotal;

    // Copy existing vaultTotalAllocations
    for (uint i = 0; i < newWeights.length; i++) {
        address vault = newWeights[i].receiver;
        tempTotal[vault] = vaultTotalAllocations[vault];
    }
    for (uint i = 0; i < oldWeights.length; i++) {
        address vault = oldWeights[i].receiver;
        tempTotal[vault] = vaultTotalAllocations[vault];
    }

    // Subtract oldWeights
    for (uint i = 0; i < oldWeights.length; i++) {
        address vault = oldWeights[i].receiver;
        tempTotal[vault] -= oldWeights[i].percentageNumerator;
    }

    // Add newWeights and check limit
    for (uint i = 0; i < newWeights.length; i++) {
        address vault = newWeights[i].receiver;
        tempTotal[vault] += newWeights[i].percentageNumerator;
        require(
            tempTotal[vault] <= VAULT_TOTAL_ALLOCATION_LIMIT,
            "Total allocation for this vault exceeds the limit"
        );
    }
}

function queueNewRewardAllocation(
    bytes calldata valPubkey,
    uint64 startBlock,
    Weight[] calldata weights
) external onlyOperator(valPubkey) {
    // ... existing validation ...

    // Previous activated RewardAllocation weights for this validator
    Weight[] storage oldWeights = lastActiveWeights[valPubkey];

    // Check vault total allocation limit
    _validateVaultTotalAllocation(weights, oldWeights);

    // ... existing queuing logic ...
}

function activateReadyQueuedRewardAllocation(bytes calldata valPubkey) external onlyDistributor {
    if (!isQueuedRewardAllocationReady(valPubkey, block.number)) return;
    RewardAllocation storage qra = queuedRewardAllocations[valPubkey];
    uint64 startBlock = qra.startBlock;

    // Previous weights
    Weight[] storage oldWeights = lastActiveWeights[valPubkey];

    // Update vaultTotalAllocations
    // Subtract oldWeights
    for (uint i = 0; i < oldWeights.length; i++) {
        address vault = oldWeights[i].receiver;
        vaultTotalAllocations[vault] -= oldWeights[i].percentageNumerator;
    }
    // Add newWeights
    for (uint i = 0; i < qra.weights.length; i++) {
        address vault = qra.weights[i].receiver;
        vaultTotalAllocations[vault] += qra.weights[i].percentageNumerator;
    }

    // ... rest of the activation logic ...
}
```

{% endcode %}

</details>

---

### <a href="#id-3-lsd-boost-bgt" id="id-3-lsd-boost-bgt"></a>Threat 3: Profit-taking by repeatedly creating new vaults after LSD protocol's BGT boost ends

After the BGT boost for the LSD protocol ends, if a new vault is created to receive rewards, the existing vault's APR will decrease, leading to a situation where only the new vault takes profits.

#### Impact

`Low`

Although this can cause a temporary decrease in APR for some users, it is a limited and temporary loss and does not significantly affect the overall stability or operation of the system. Therefore, it is rated `Low`.

#### Guideline

> - **Validators participating in the boost must ensure a minimum incentive for a certain period.**
>   - This is calculated by multiplying the most recent BGT issuance by the `incentiveRate` of each incentive token and the reward allocation period (`guaranteeBlocks`).
>   - The `minIncentiveBalance` is calculated as the incentive amount for the BGT issued per period.
>   - When allocating rewards, `getCurrentIncentiveBalance` checks if all incentive tokens have a quantity greater than or equal to `minIncentiveBalance`. If insufficient, allocation is not possible.

#### Best Practice

`Custom Code`

{% code overflow="wrap" %}

```solidity
contract RewardVault {
    // ... (existing state variables and code omitted) ...

    // Minimum incentive balance per token
    mapping(address => uint256) public minIncentiveBalance;

    uint256 public guaranteeBlocks = 2000; // Currently, the validator reward allocation delay is 2000 blocks


    // ... (existing code omitted) ...

    /// @notice Change the number of blocks for minimum incentive guarantee (onlyFactoryOwner)
    function setGuaranteeBlocks(uint256 _guaranteeBlocks) external onlyFactoryOwner {
        require(_guaranteeBlocks > 0, "RewardVault: guaranteeBlocks must be positive");
        guaranteeBlocks = _guaranteeBlocks;
    }

    /// @dev Update the minimum incentive balance per token based on BGT issuance and incentiveRate
    function _updateMinIncentiveBalance(address token, uint256 bgtEmitted) internal {
        uint256 incentiveRate = incentives[token].incentiveRate;
        // Expected payout for 2000 blocks = bgtEmitted (this distribution amount) * 2000 / 1 (with PRECISION applied)
        minIncentiveBalance[token] = bgtEmitted * GUARANTEE_BLOCKS * incentiveRate / FixedPointMathLib.PRECISION;
    }

    /// @dev Update the minimum balance with each incentive distribution
    function _processIncentives(bytes calldata pubkey, uint256 bgtEmitted) internal {
        // ... existing code ...
        uint256 whitelistedTokensCount = whitelistedTokens.length;
        for (uint256 i; i < whitelistedTokensCount; ++i) {
            address token = whitelistedTokens[i];
            Incentive storage incentive = incentives[token];
            // ... existing distribution logic ...
            // Update minimum balance after distribution
            _updateMinIncentiveBalance(token, bgtEmitted);
        }
    }

    /// @notice Check if the balance of all incentive tokens is greater than or equal to the minimum balance for each token
		function getCurrentIncentiveBalance() external view returns (bool) {
		    uint256 len = whitelistedTokens.length;
		    for (uint256 i = 0; i < len; ++i) {
		        address token = whitelistedTokens[i];
		        if (incentives[token].amountRemaining < minIncentiveBalance[token]) {
		            return false; // Return false if even one is insufficient
		        }
		    }
		    return true; // Return true if all are sufficient
		}

    // ... (rest of the existing code) ...
}
```

{% endcode %}

{% code overflow="wrap" %}

```solidity
function _validateWeights(bytes memory valPubkey, Weight[] calldata weights) internal {
    if (weights.length > maxNumWeightsPerRewardAllocation) {
        TooManyWeights.selector.revertWith();
    }
    _checkForDuplicateReceivers(valPubkey, weights);

    uint96 totalWeight;
    for (uint256 i; i < weights.length;) {
        Weight calldata weight = weights[i];

        if (weight.percentageNumerator == 0 || weight.percentageNumerator > maxWeightPerVault) {
            InvalidWeight.selector.revertWith();
        }

        // Original: Whitelist check
        if (!isWhitelistedVault[weight.receiver]) {
            NotWhitelistedVault.selector.revertWith();
        }

        // Incentive threshold check: all incentive token balances must be above the threshold
        address vault = weight.receiver;
        bool isSufficient = RewardVault(vault).getCurrentIncentiveBalance();
        if (!isSufficient) {
            // Vaults with insufficient incentives cannot be included in the reward allocation
            InvalidWeight.selector.revertWith();
        }

        totalWeight += weight.percentageNumerator;
        unchecked { ++i; }
    }
    if (totalWeight != ONE_HUNDRED_PERCENT) {
        InvalidRewardAllocationWeights.selector.revertWith();
    }
}

function _checkIfStillValid(Weight[] memory weights) internal view returns (bool) {
    uint256 length = weights.length;
    if (length > maxNumWeightsPerRewardAllocation) {
        return false;
    }
    for (uint256 i; i < length;) {
        address vault = weights[i].receiver;
        if (weights[i].percentageNumerator > maxWeightPerVault) {
            return false;
        }
        if (!isWhitelistedVault[vault]) {
            return false;
        }
        // Incentive threshold check: all incentive token balances must be above the threshold
        bool isSufficient = RewardVault(vault).getCurrentIncentiveBalance();
        if (!isSufficient) {
            return false;
        }
        unchecked { ++i; }
    }
    return true;
}
```

{% endcode %}

---

### <a href="#id-4" id="id-4"></a>Threat 4: BGT Inflation Manipulation

If the parameters `boostMultiplier` and `rewardConvexity` used to calculate BGT inflation are set incorrectly, it can lead to unintended inflation or deflation of BGT, causing economic instability.

#### Impact

`Low`

Incorrect parameter settings can cause temporary economic instability, but since these parameters can only be changed by the owner through governance, the possibility of malicious manipulation is low. Therefore, it is rated `Low`.

#### Guideline

> - **Set reasonable ranges for `boostMultiplier` and `rewardConvexity`.**
>   - `boostMultiplier`: Should be set within a range that does not cause excessive inflation.
>   - `rewardConvexity`: Should be set considering the balance between boost effect and inflation.
> - **Changes to these parameters must go through a governance process with sufficient discussion and voting.**
> - **Regularly monitor the inflation rate and adjust parameters as needed.**

#### Best Practice

[`BlockRewardController.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/pol/rewards/BlockRewardController.sol#L104-L121)

{% code overflow="wrap" %}

```solidity
function setBGTInflation(
    int256 _rewardConvexity,
    uint256 _boostMultiplier,
    uint256 _rewardRate,
    uint256 _baseRate
)
    external
    onlyOwner
{
    // These values are sensitive and should be set carefully.
    // Additional checks can be added here to ensure they fall within a safe range.
    if (_rewardConvexity <= 0 || _rewardConvexity > FixedPointMathLib.WAD) {
        InvalidRewardConvexity.selector.revertWith();
    }
    rewardConvexity = _rewardConvexity;
    boostMultiplier = _boostMultiplier;
    rewardRate = _rewardRate;
    baseRate = _baseRate;
    emit SetBGTInflation(msg.sender, _rewardConvexity, _boostMultiplier, _rewardRate, _baseRate);
}
```

{% endcode %}

---

### <a href="#id-5-apr" id="id-5-apr"></a>Threat 5: Inaccurate APR calculation and display

If the APR is calculated and displayed inaccurately, users may make incorrect investment decisions, leading to financial losses.

#### Impact

`Low`

Inaccurate APR display can mislead users, but since the actual reward amount is calculated correctly on-chain, the direct financial loss is limited. Therefore, it is rated `Low`.

#### Guideline

> - **Use an accurate formula to calculate APR.**
>   - APR should be calculated based on the total rewards distributed over a specific period and the total staked amount.
> - **Clearly display the APR calculation criteria to users.**
>   - Provide a detailed explanation of how the APR is calculated on the UI.
> - **Regularly verify the accuracy of the displayed APR.**
>   - Periodically compare the on-chain reward data with the displayed APR to check for discrepancies.

#### Best Practice

`Custom Code (Frontend)`

{% code overflow="wrap" %}

```javascript
// Function to calculate and display APR
async function displayAPR() {
  // 1. Get total rewards distributed over the last 24 hours
  const totalRewards = await rewardVaultContract.methods
    .getRecentRewards()
    .call();

  // 2. Get total staked amount
  const totalStaked = await stakingTokenContract.methods
    .balanceOf(rewardVaultAddress)
    .call();

  // 3. Calculate APR
  // APR = (Total Rewards per Year / Total Staked) * 100
  const apr = ((totalRewards * 365) / totalStaked) * 100;

  // 4. Display APR on the UI
  document.getElementById("apr-display").innerText = `APR: ${apr.toFixed(2)}%`;
}
```

{% endcode %}

---

### <a href="#id-6-claimfees" id="id-6-claimfees"></a>Threat 6: Unclaimed rewards (`claimFees`) are not properly burned

If the `claimFees` function is front-run, a user may have to pay HONEY without receiving their fee reward, resulting in a loss.

#### Impact

`Low`

Although front-running `claimFees` can cause a temporary distortion of fee rewards for some users, this is a limited occurrence for individual users and does not significantly affect the overall stability or operation of the system. Therefore, it is rated `Low`.

#### Guideline

> - **Before claiming fees, compare the balance of the fee that serves as the calculation basis with the user's expected reward. If the actual claimable fee is less, revert.**
>   - Previously, to claim, only an array of addresses of the desired fee tokens was passed as an argument.
>   - Additionally, create an array of the expected amount for each fee token and pass it as an argument. If the contract's current fee token amount for that token is less than the expected amount, revert.

#### Best Practice

`Custom Code (BEX.sol)`

{% code overflow="wrap" %}

```solidity
// existing claimFees function
function claimFees(address[] memory tokens) external returns (uint[] memory amounts) {
    // ... (existing logic)
}

// new claimFees function with expected amounts
function claimFeesWithExpected(address[] memory tokens, uint[] memory expectedAmounts) external returns (uint[] memory amounts) {
    require(tokens.length == expectedAmounts.length, "Mismatched arrays");

    amounts = new uint[](tokens.length);
    for (uint i = 0; i < tokens.length; i++) {
        uint amount = fees[tokens[i]][msg.sender];

        // Check if the actual claimable amount meets the expected amount
        require(amount >= expectedAmounts[i], "Fee amount lower than expected");

        if (amount > 0) {
            fees[tokens[i]][msg.sender] = 0;
            // safeTransfer
            IERC20(tokens[i]).safeTransfer(msg.sender, amount);
        }
        amounts[i] = amount;
    }
}
```

{% endcode %}

</rewritten_file>
