---
icon: honey-pot
---

# PoL Security Guidelines: Oracle and HONEY

<table><thead><tr><th width="591.7421875">Threat</th><th align="center">Impact</th></tr></thead><tbody><tr><td><a data-mention href="honey.md#id-1">#id-1</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="honey.md#id-2-basket">#id-2-basket</a></td><td align="center"><code>Informational</code></td></tr><tr><td><a data-mention href="honey.md#id-3">#id-3</a></td><td align="center"><code>Informational</code></td></tr></tbody></table>

### Threat 1: External Oracle Price Manipulation and Unreliable Oracle Logic <a href="#id-1" id="id-1"></a>

External oracle price manipulation and unreliable oracle logic (e.g., reliance on a single oracle, asymmetric processing) can lead to protocol losses or user harm during the HONEY token minting/redeeming process.

#### Impact

`Low`

Relying on a single oracle or failing to clearly inform users during a de-pegging event can lead to user harm. It is also potentially vulnerable to price manipulation via Flash Loans, so it is rated `Low`.

#### Guideline

> * **Use the median or weighted average of at least three independent oracle feeds as the final price.**
> * **Specify the oracle process (add, modify, delete):**
>   * **Add:** A governance vote is required to add a new oracle.
>   * **Modify:** A minimum of 72 hours advance notice and a governance feedback period are required to adjust the weight of an existing oracle.
>     * **72-hour advance notice:** Ensures sufficient time for governance participation.
>   * **Delete:** A replacement oracle is required when removing an oracle feed.
>   * **Emergency Halt:**
>     * Authority: Limited to a multisig or a manager elected by governance.
>     * Post-halt process: A community announcement and recovery plan must be submitted within 24 hours.
>     * Recovery procedure: Requires governance approval.
> * **Specify the processing logic for oracle anomalies:**
>   * Automatically exclude an oracle from aggregation if its connection is delayed by more than 30 seconds.
>   * Reduce the weight by 70% if the deviation from the median of other feeds exceeds ±0.1%, and automatically exclude it if it exceeds ±0.15%.
>     * **±0.1% warning:** 50% of the Honey pegging tolerance (0.2%).
>     * **±0.15% exclusion:** 75% of the Honey pegging tolerance (0.2%).
>   * Price determination must reference at least three oracles; otherwise, temporarily suspend trading.
>   * Reactivating a deactivated oracle requires verification (reason for deactivation, feasibility of reactivation).
>   * Automatic switch to a secondary oracle if the primary oracle fails.
> * **Warn users if the oracle price fluctuates beyond a preset threshold:**
>   * **Threshold setting:** User warning if the 1-minute price exceeds ±0.1%, Circuit Breaker if it exceeds ±0.15%.
>   * **Threshold change:** A minimum of 72 hours advance notice and a governance feedback period are required to change the threshold.
> * **Check for logical asymmetry between oracles.**
>   * Generalization is needed instead of specific oracle logic like "If the spot oracle price exceeds $1.00, treat it as $1.00."
> * **Mitigate the impact of real-time oracle manipulation attacks by determining prices based on a TWAP over a certain period.**
> * **To prevent economic attacks that exploit severe de-pegging of the HONEY token, consider introducing a mechanism that requires a trading delay or additional verification when an abnormal surge in trading volume or a repetitive attack pattern is detected.**

#### Best Practice

[`HoneyFactory.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Core/src/honey/HoneyFactory.sol#L569-L578)

{% code overflow="wrap" %}
```solidity
uint256 private constant DEFAULT_PEG_OFFSET = 0.002e18;
uint256 private constant MAX_PEG_OFFSET = 0.02e18;

// Check pegging logic
function isPegged(address asset) public view returns (bool) {
    if (!priceOracle.priceAvailable(asset)) return false;
    IPriceOracle.Data memory data = priceOracle.getPriceUnsafe(asset);
    if (data.publishTime < block.timestamp - priceFeedMaxDelay) return false;
    return (1e18 - lowerPegOffsets[asset] <= data.price) && (data.price <= 1e18 + upperPegOffsets[asset]);
}
```
{% endcode %}

[`HoneyFactory.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Core/src/honey/HoneyFactory.sol#L163-L170)

```solidity
// Designed to get the latest price from the oracle
function setMaxFeedDelay(uint256 maxTolerance) external {
    _checkRole(MANAGER_ROLE);
    if (maxTolerance > MAX_PRICE_FEED_DELAY_TOLERANCE) {
        AmountOutOfRange.selector.revertWith();
    }
    priceFeedMaxDelay = maxTolerance;
    emit MaxFeedDelaySet(maxTolerance);
}
```

`Custom Code`

{% code overflow="wrap" %}
```solidity
contract EnhancedMultiOracleSystem {
    struct OracleData {
        address oracle;
        uint256 weight;
        bool isActive;
        bool isEmergencyPaused;
    }

// Guideline: Emergency halt function
    function emergencyPause(address asset) external onlyManager {
        emergencyPaused[asset] = true;
    }

// Guideline: Deviation check + weighted average calculation
    function getAggregatedPrice(address asset) external view returns (uint256) {
        require(!emergencyPaused[asset], "Emergency paused");

        OracleData[] memory oracles = assetOracles[asset];
        require(oracles.length >= MIN_ORACLES, "Insufficient oracles");

        uint256[] memory prices = new uint256[](oracles.length);
        uint256[] memory weights = new uint256[](oracles.length);
        uint256 validCount = 0;

        // 1. Collect prices
        for (uint256 i = 0; i < oracles.length; i++) {
            if (oracles[i].isActive && !oracles[i].isEmergencyPaused) {
                try IPriceOracle(oracles[i].oracle).getPrice(asset) returns (uint256 price) {
                    prices[validCount] = price;
                    weights[validCount] = oracles[i].weight;
                    validCount++;
                } catch {}
            }
        }

        require(validCount >= MIN_ORACLES, "Not enough valid oracles");

        // 2. Calculate median and check deviation
        uint256 median = _calculateMedian(prices, validCount);
        uint256 totalWeight = 0;
        uint256 weightedSum = 0;

        for (uint256 i = 0; i < validCount; i++) {
            uint256 deviation = _calculateDeviation(prices[i], median);

            // Exclude if deviation is greater than 0.15%
            if (deviation <= DEVIATION_THRESHOLD) {
                weightedSum += prices[i] * weights[i];
                totalWeight += weights[i];
            }
        }

        require(totalWeight > 0, "No valid prices after filtering");

        return weightedSum / totalWeight;
    }

}
```
{% endcode %}

***

### Threat 2: Exploitation of Overly Sensitive De-pegging Criteria and Basket Mode Activation Conditions <a href="#id-2-basket" id="id-2-basket"></a>

Criteria that consider very low levels of price fluctuation as de-pegging can frequently activate Basket Mode even with minor market volatility, harming the user experience.

There is also a possibility that an attacker could intentionally induce a slight de-pegging of a specific constituent stablecoin to trigger Basket Mode and trick users into minting or redeeming with an unexpected asset composition ratio.

For example, if redemption through Basket Mode is forced even when only some of the multiple constituent stablecoins are slightly de-pegged, users who wanted to receive only normally pegged assets are at risk of receiving unwanted assets.

#### Impact

`Informational`

If the minting and redeeming logic's basket modes operate separately, it can cause confusion. It is recommended to improve user convenience through a more granular basket mode, so it is rated `Informational`.

#### Guideline

> * **Sensitivity Adjustment Criteria:** Instead of having separate basket modes for minting and redeeming, apply different stages of basket mode based on the [price fluctuation rate](../../reference.md#id-23.-market-volatility-data)<sub>23</sub>.
>   * Warning Stage (0.1%): User notification if it persists for 1 minute.
>   * (Temporary De-pegging) Restriction Stage (0.2%): Restrict minting of the asset and adjust the exchange ratio if it persists for 1 minute.
>   * (De-pegging) Basket Stage (0.5%): Immediately activate Basket Mode if it persists for 1 minute.
> * **Basket Mode activation should be considered a last resort for maintaining stability and should be automatically deactivated when the pegged asset's stability is restored.**
>   * **Stability Restoration:** Automatically return to normal mode after [1 hour of continuous stability (less than 0.2%)](../../reference.md#id-24.-ispegged-implementation)<sub>24</sub>.

#### Best Practice

[`HoneyFactory.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Core/src/honey/HoneyFactory.sol#L526-L553)

<pre class="language-solidity" data-overflow="wrap"><code class="lang-solidity">function isBasketModeEnabled(bool isMint) public view returns (bool) {
    if (forcedBasketMode) return true;
    
    for (uint256 i = 0; i &#x3C; registeredAssets.length; i++) {
        address asset = registeredAssets[i];
        if (isBadCollateralAsset[asset] || vaults[asset].paused()) continue;
        if (isMint &#x26;&#x26; !<a data-footnote-ref href="#user-content-fn-1">isPegged</a>(asset)) return true;
    }
    return false;
}
</code></pre>

`Custom Code`

{% code overflow="wrap" %}
```solidity
contract StabilityRecovery {
    struct RecoveryState {
        uint256 recoveryStartTime;
        uint256 lastCheckTime;
        uint256 stableCount;
        bool isRecovering;
    }

    uint256 public constant RECOVERY_CONFIRMATION_PERIOD = 3 hours;
    uint256 public constant STABILITY_CHECK_INTERVAL = 30 seconds;

    function checkAutoRecovery(address asset) external returns (bool) {
        require(
            block.timestamp >= recoveryStates[asset].lastCheckTime + STABILITY_CHECK_INTERVAL,
            "Too frequent checks"
        );

        if (isPriceStable(asset)) {
            if (!recoveryStates[asset].isRecovering) {
                recoveryStates[asset].recoveryStartTime = block.timestamp;
                recoveryStates[asset].isRecovering = true;
                recoveryStates[asset].stableCount = 1;
            } else {
                recoveryStates[asset].stableCount++;

                if (block.timestamp >= recoveryStates[asset].recoveryStartTime + RECOVERY_CONFIRMATION_PERIOD) {
                    _resetToNormalMode(asset);
                    return true;
                }
            }
        } else {
            _resetRecoveryState(asset);
        }

        recoveryStates[asset].lastCheckTime = block.timestamp;
        return false;
    }
}
```
{% endcode %}

***

### Threat 3: Uncertainty in Valuation and User Notification When Redeeming De-pegged Assets <a href="#id-3" id="id-3"></a>

If there are no clear standards and notifications about 'at what price de-pegged assets are valued and returned to the user' and 'how much potential loss the user must bear in this process,' users cannot accurately assess the value of the tokens they will receive in basket mode.

#### Impact

`Informational`

This is a threat in terms of user convenience, so it is rated `Informational`.

#### Guideline

> * **When redeeming while Basket Mode is active, the value of the de-pegged asset is assessed by referencing** [**at least 3 oracles**](../../reference.md#id-25.-oracles-used-by-berachain-chainlink-etc)<sub>25</sub> \
>   **(**&#x43;urrently, Berachain references reliable Chainlink oracles along with Pyth and spot oracles.**).**
>   * In this process, only active oracles are referenced (deactivated, emergency-halted oracles are prohibited).
> * **A clear and simple procedure is needed to notify users that de-pegged assets may be included in the redemption, the valuation criteria for de-pegged assets, and the potential for loss.**
>   * A [formula-based explanation](../../reference.md#id-26.-calculateloss-formula-reference)<sub>26</sub> of how to calculate the estimated loss from de-pegged assets.
> * **If necessary, consider operating an internal reserve fund at the protocol level to partially mitigate the risk of sudden losses from de-pegged assets.**
>   * The reserve fund is composed of a portion of the fees generated during the redemption process and is operated as an internal reserve.
>   * The reserve fund is activated only when basket mode is active and is used to minimize user losses.

#### Best Practice

[`HoneyFactory.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Core/src/honey/HoneyFactory.sol#L368-L418)

{% code overflow="wrap" %}
```solidity
function redeem(address asset, uint256 honeyAmount, address receiver, bool expectBasketMode)
    external whenNotPaused returns (uint256 redeemedAssets) {
    _checkRegisteredAsset(asset);

    bool basketMode = isBasketModeEnabled(false);
    if (basketMode != expectBasketMode) {
        UnexpectedBasketModeStatus.selector.revertWith();
    }

    if (!basketMode) {
        _checkGoodCollateralAsset(asset);
        redeemedAssets = _redeem(asset, honeyAmount, receiver);
    } else {
        uint256[] memory weights = _getWeights(false, true);
        // Basket mode redemption logic
    }
}
```
{% endcode %}

`Custom Code`

<pre class="language-solidity" data-overflow="wrap"><code class="lang-solidity">// Pre-redemption alert and risk acknowledgment system for de-pegged asset exposure

contract RedeemWarningSystem {
    struct RedeemWarning {
        bool hasDepeggedAssets;
        uint256 estimatedLoss;
        address[] depeggedAssets;
    }
    
    function getRedeemWarning(uint256 honeyAmount) external view returns (RedeemWarning memory) {
        address[] memory assets = getRegisteredAssets();
        uint256 depeggedCount = 0;
        uint256 totalLoss = 0;
        
        for (uint256 i = 0; i &#x3C; assets.length; i++) {
            if (!isPegged(assets[i])) {
                depeggedCount++;
                totalLoss += <a data-footnote-ref href="#user-content-fn-2">calculateLoss</a>(assets[i], honeyAmount);
            }
        }
        
        return RedeemWarning(depeggedCount > 0, totalLoss, assets);
    }
    
    function acknowledgeRisk(uint256 honeyAmount) external {
        // Confirm user's risk acknowledgment
        emit RiskAcknowledged(msg.sender, honeyAmount);
    }
} 

// calculateLoss()
function calculateLoss(address asset, uint256 honeyAmount) internal view returns (uint256) {
    // 1. Get current market price
    uint256 currentPrice = getAggregatedPrice(asset);
    uint256 pegPrice = 1e18; // $1.00
    
    // 2. Calculate loss only in a de-pegged situation
    if (currentPrice >= pegPrice) return 0;
    
    // 3. Calculate the amount of the asset the user will receive
    // UserAssetAmount = HoneyAmount * AssetWeight
    uint256[] memory weights = getWeights();
    uint256 assetIndex = getAssetIndex(asset);
    uint256 userAssetAmount = honeyAmount * weights[assetIndex] / 1e18;
    
    // 4. Loss = AssetValueAtPeg * DepegRatio
    
    // DepegRatio = (PegPrice - CurrentPrice) / PegPrice
    uint256 depegRatio = (pegPrice - currentPrice) * 1e18 / pegPrice;
    
    // AssetValueAtPeg = UserAssetAmount * PegPrice  
    uint256 assetValueAtPeg = userAssetAmount * pegPrice / 1e18;
    
    // Loss = AssetValueAtPeg * DepegRatio
    uint256 loss = assetValueAtPeg * depegRatio / 1e18;
    
    return loss;
}

</code></pre>

[^1]: Pegging status verification logic that uses multi-oracle aggregation and references only active oracles for reliable price determination.

[^2]: Reference \[26] calculateLoss formula reference\
    Calculate loss as DepegRatio × AssetValue, requires user risk notification and `acknowledgeRisk` confirmation.
