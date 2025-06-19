---
icon: rotate-reverse
---

# dApp Security Guidelines: DEX

<table><thead><tr><th width="597.64453125">Threat</th><th align="center">Impact</th></tr></thead><tbody><tr><td><a data-mention href="dex.md#id-1-lp">#id-1-lp</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="dex.md#id-2">#id-2</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="dex.md#id-3">#id-3</a></td><td align="center"><code>Informational</code></td></tr><tr><td><a data-mention href="dex.md#id-4">#id-4</a></td><td align="center"><code>Informational</code></td></tr><tr><td><a data-mention href="dex.md#id-5">#id-5</a></td><td align="center"><code>Informational</code></td></tr><tr><td><a data-mention href="dex.md#id-6">#id-6</a></td><td align="center"><code>Informational</code></td></tr></tbody></table>

### Threat 1: LP Token Value Calculation and Issuance Errors <a href="#id-1-lp" id="id-1-lp"></a>

When adding liquidity to a pool, the value of the issued LP tokens may not match the actual value of the pool assets, leading to new liquidity providers receiving excessive gains or losses.

#### Impact

`Low`

It is rated `Low` because if new liquidity providers receive LP tokens that do not match the actual value of the pool assets due to calculation and issuance errors, some users may experience limited losses or gains.

#### Guideline

> * **Accurate Value Calculation:**
>   * Reflect the current market price of each token in real-time from reliable oracles like Chainlink and Uniswap TWAP, using only data updated within a minimum of 1 minute to a maximum of 3 minutes. If the price deviation between referenced oracles exceeds a certain percentage (e.g., within [0.5% \~ 2% for Chainlink](https://docs.chain.link/chainlink-nodes/oracle-jobs/all-jobs#spec-format-2)), perform additional verification.
>   *   Apply liquidity weights when calculating the weighted average price by multiplying the liquidity ratio for each token.
>
>       $$\text{Pool Value} = (\text{tokenA}_amount \times \text{priceA}) + (\text{tokenB}_amount \times \text{priceB})$$
>   * Calculate the exact proportion of the new liquidity relative to the entire pool.
> * **Ensuring Numerical Precision:**
>   * Mandatory use of fixed-point math libraries like SafeMath and FixedPointMathLib, with a precision of at least 18 decimal places.
>   * Convert intermediate calculation values to fixed-point units and verify that the precision of the intermediate [calculation results](../../reference.md#id-42.-lp-token-value-calculation-accuracy)<sub>42</sub> does not fall below 1e18.
>   * Optimize the order of addition/multiplication by performing operations on larger numbers first and applying division at the end. Use numerical precision-guaranteeing formula calculation modules like SafeMath and FixedPointMathLib.
> * **Real-time Verification:**
>   *   Compare the calculated LP token value with the actual pool asset value by checking if the following formula holds true:
>
>       $$\text{LP Total Supply} \times \text{Current LP Token Value} \approx \text{LP Pool TVL}$$
>   * Immediately after the liquidity addition transaction is executed, verify that the calculated expected issuance amount matches the actually issued LP token amount.

#### Best Practice

[`ProtocolFeesWithdrawer.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Bex/contracts/ProtocolFeesWithdrawer.sol#L187-L204)

```solidity
using FixedPoint for uint256;
// ... (omitted) ...
polFeeCollectorFees[i] = amount.mulDown(polFeeCollectorPercentage);
// ... (omitted) ...
feeReceiverFees[i] = amount.sub(polFeeCollectorFees[i]);
// ... (omitted) ...
polFeeCollectorPercentage = FixedPoint.ONE; // 100%
require(_polFeeCollectorPercentage <= FixedPoint.ONE, "MAX_PERCENTAGE_EXCEEDED");
```

***

### Threat 2: Liquidity Removal Timing Attack and Minimum Liquidity Bypass <a href="#id-2" id="id-2"></a>

An attacker can exploit moments of sharp price increases or decreases to remove liquidity, causing the remaining liquidity in the pool to fall below a standard threshold or bypassing the minimum holding period to quickly realize profits.

#### Impact

`Low`

Although an attacker can remove liquidity during sharp price fluctuations, causing the pool's remaining liquidity to fall below the threshold or bypassing the minimum holding period to realize profits, the impact on the entire pool is limited, so it is rated `Low`.

#### Guideline

> * **Minimum Liquidity Verification:**
>   *   Verify the minimum liquidity threshold per pool in the smart contract before removing liquidity, as shown below.\
>       (The α value is a coefficient used to impose a high penalty for actions that cause pool imbalance, set to [10^6 based on Curve Finance](https://github.com/curvefi/curve-contract/blob/574f44027d089de0eac765f5a74ea5ae96aba968/contracts/pools/3pool/StableSwap3Pool.vy#L87)).
>
>       $$\text{MinLiquidity} = \max\left(\text{BaseAmount},\ \text{AvgVolume}_{\text{N Days}} \times \alpha\right) \\ \scriptsize (\text{Pool Value}_\text{after removal} \geq \text{MinLiquidity})$$
>   *   Since the pool becomes vulnerable to price manipulation/MEV attacks if the sum of each token's balance multiplied by its market price falls below a certain level, perform real-time verification at the time of liquidity removal based on the oracle price to ensure the total token value is above the threshold.
>
>       $$\text{Pool Value} = \sum_{i=1}^{n} (\text{Token}_i\, \text{Balance} \times \text{Token}_i\, \text{Price}) \\ {\scriptsize (\text{Pool Vaule}_\text {after removal} \geq \text{MinLiquidity})}$$
> * **Timing Attack Prevention:**
>   *   As in cases like Uniswap V3, fix the oracle/TWAP price at the time of the liquidity removal request and settle based on the initial request price until the actual removal is processed.
>
>       $$\text{Remove Value} = \text{Liquidity Amount} \times \text{Price}_{\text{request}}$$
>   *   When removing liquidity, use the average price of the last N blocks (TWAP) as the settlement standard to [prevent temporary price manipulation](../../reference.md#id-45.-twap-calculation-n-block-average)<sub>45</sub>.
>
>       $$\text{TWAP} = \frac{1}{N}\Sigma^{N}_{j=1} \text{Price}_{\text{block }j} \space \scriptsize (N=\text{Block Number})$$
>   *   Like Curve and Balancer, add a condition at the protocol level that requires a [minimum holding period](../../reference.md#id-43.-preventing-liquidity-removal-timing-attacks)<sub>43</sub> to pass after receiving LP tokens for providing liquidity before liquidity can be removed.
>
>       $$(\text{Example: } \text{Current Time} - \text{LP Mint Time} \geq \text{Min Hold Period})$$

#### Best Practice

[`WeightedMath.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Bex/contracts/WeightedMath.sol#L41-L44)

The invariant ratio limit can vary depending on the protocol's risk model. The code below specifies the maximum/minimum invariant limits according to Balancer's weighted invariant formula.

<pre class="language-solidity"><code class="lang-solidity">// <a data-footnote-ref href="#user-content-fn-1">Limit of 300% max invariant increase</a>
uint256 internal constant _MAX_INVARIANT_RATIO = 3e18;
// <a data-footnote-ref href="#user-content-fn-2">Limit of 70% min invariant decrease</a>
uint256 internal constant _MIN_INVARIANT_RATIO = 0.7e18;
</code></pre>

***

### Threat 3: Liquidity Pool Imbalance <a href="#id-3" id="id-3"></a>

Repeated large deposits and withdrawals of a specific token can severely disrupt the token ratio in the pool, leading to price distortion or the depletion of liquidity for some tokens. An attacker can use a flash loan to borrow a large amount of funds in a single block, drastically manipulate the pool price, take a profit, and then immediately repay, inducing regular users to trade at distorted prices.

#### Impact

`Informational`

If the asset ratio in a pool is severely disrupted due to repeated large deposits and withdrawals of a specific token, it can lead to price distortion or liquidity depletion for some tokens. However, since this does not lead to a system-wide security issue or direct loss, it is rated as `Informational`.

#### Guideline

> * **Flash Loan Attack Prevention**
>   * Enforce a hard cap at the protocol level on the maximum price fluctuation a single trade can cause in a liquidity pool.
>   * When a flash loan function call or a large-scale borrow-swap-repay pattern is detected within a transaction, induce a reduction in the attacker's potential profit by imposing an additional 1% fee on top of the basic swap fee, similar to Uniswap and Balancer.
>   * Apply a `lock` modifier to prevent re-entrancy attacks through the flash loan execution function within the same transaction.
> * **Oracle Price Verification**
>   * Utilize at least two independent oracle price sources. If the price deviation between oracles exceeds 1.5%, reject the transaction or conduct further verification.
>     * This threshold is operated by oracle networks like Chainlink and Band Protocol.
>   * DeFi protocols like Compound and [Synthetix](../../reference.md#id-41.-synthetix-oracle-discrepancy-tolerance-standard)<sub>41</sub> specify an oracle discrepancy tolerance of within 1%. To prevent liquidity provider losses due to accumulated discrepancies, they temporarily pause trading if not updated for more than 3 minutes.$$\Delta P \approx \sigma \times \sqrt{t} \\\space {\scriptsize (\text{Example: } \sigma = 0.5\%, t = 3 \text{min} \implies \Delta P \approx 0.5\% \times \sqrt{3} \approx 0.866\%) }$$
>   * Minimize the impact of price manipulation from a single trade by using an average price like TWAP (Time-Weighted Average Price).
> * **Automatic Rebalancing Mechanism**
>   *   Like AMM services such as Uniswap and Curve, set a deviation [threshold](../../reference.md#id-49.-slippage-tolerance-setting-and-verification)<sub>49</sub> against the target ratio for maintaining the asset value ratio in the liquidity pool. Trigger rebalancing when the threshold is exceeded.
>
>       $$\text{Example: } \text{Ratio}_A = \frac{\text{Value}_A}{\text{Value}_A+\text{Value}_B}, \quad \text{Threshold} \approx \frac{C_{gas} + C_{swap}}{\text{Value}_A + Value_B} \\ \scriptsize (|\text{Ratio}_A-\text{Target Ratio}_A| > \text{Threshold} \Rightarrow \text{Rebalance Trigger}) \\ \scriptsize C_{gas}\text{: Network gas cost required to execute the rebalancing transaction} \\ \scriptsize C_{swap}\text{: Swap fee paid to the liquidity pool} \\ \scriptsize \text{Value}_A + \text{Value}_B\text{: Total market value of assets A and B deposited in the pool}$$
>   * When a deviation occurs, provide a trigger in the smart contract for automatic rebalancing to restore price balance, similar to Uniswap's [x\*y=k](../../reference.md#id-47.-curve-stableswap-formula-reference)<sub>47</sub> curve.
> * **Imbalance Monitoring**
>   * Similar to existing DEX services, it is necessary to provide a function to track and calculate key indicators such as the asset ratio and TVL in the pool on a real-time dashboard.
>   * If the operated liquidity pool ratio deviates significantly from the target, build a warning system with deviation-level alerts for administrators to respond immediately.
> * **Automatic Swap Processing**
>   *   Like Curve and Balancer, when providing liquidity with a single token, automatically swap to match the pool's ratio before supplying liquidity to prevent pool imbalance, price distortion, and liquidity depletion. The formula based on Balancer v1 is as follows:
>
>       $$V = \Pi^{n}_{i=1}B_i^{W_i} \\ \scriptsize \text{Example: } V = (B_A^{W_A}) \times (B_A^{W_A}) \times (B_C^{W_C}) \quad (n = 3) \\ (B_{A, B, C} : \text{Token}_{A,B,C}\space\text{ Balances}) \\ (W_{A, B, C}: \text{Token}_{A,B,C}\space\text{Weights})$$
> * **Minimum Liquidity Requirements**
>   *   Based on Balancer, require a minimum liquidity of the greater of 10% of the pool's recent N-day average trading volume or $10,000. This may vary depending on the protocol's governance.
>
>       $$\text{MinLiquidity} = \max\left( \text{BaseAmount},\ \text{AvgVolume}_{N\text{Days}} \times \alpha \right) \\ {\scriptsize ( \text{Example: } \text{MinLiquidity} = \max(10{,}000,\ 150{,}000 \times 0.1 ) = 15{,}000)}$$
>   * In AMMs like Uniswap and KyberSwap, to prevent market price distortion due to slippage, restrict a single trade from exceeding a set percentage of the pool's balance.\
>     (The trade size limit may vary depending on the AMM protocol's risk model; a 30% limit is applied in the example code).$$\text{Price Impact} = 1 - \frac{x}{x + \Delta x} \space \scriptsize (x = \text{Pool Balance}, \Delta x = \text{Asset Increment}) \\ \scriptsize (\text{Example: } 1 - \frac{1}{1 + 0.4286} \approx 0.3 \approx 30\%)$$

#### Best Practice

[`IslandRouter.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Kodiak/IslandRouter/src/vaults/IslandRouter.sol#L119-L149)

{% code overflow="wrap" %}
```solidity
function addLiquiditySingle(
    IKodiakIsland island,
    uint256 totalAmountIn,
    uint256 amountSharesMin,
    uint256 maxStakingSlippageBPS,
    RouterSwapParams calldata swapData,
    address receiver
) external override returns (uint256 amount0, uint256 amount1, uint256 mintAmount) {
    require(maxStakingSlippageBPS <= 10000, "staking slippage too high");
    IERC20 token0 = island.token0();
    IERC20 token1 = island.token1();
    IERC20 tokenIn = swapData.zeroForOne ? token0 : token1;
    tokenIn.safeTransferFrom(msg.sender, address(this), totalAmountIn);
    // Auto Swap
    (uint256 token0Balance, uint256 token1Balance) = _swapAndVerify(token0, token1, tokenIn, swapData);
    // Calculate token amounts for LP token issuance
    (amount0, amount1, mintAmount) = island.getMintAmounts(token0Balance, token1Balance);
    require(mintAmount >= amountSharesMin, "Staking: below min share amount");

    // Slippage conditions vary by protocol; Kodiak implements it as 10000 BPS (100%).
    if (swapData.zeroForOne) require(amount1 >= token1Balance * (10000 - maxStakingSlippageBPS) / 10000, "Staking Slippage: below min amounts");
    else require(amount0 >= token0Balance * (10000 - maxStakingSlippageBPS) / 10000, "Staking Slippage: below min amounts");

    token0Balance -= amount0;
    token1Balance -= amount1;
    // Provide liquidity
    _deposit(island, amount0, amount1, mintAmount, receiver);

    // Return remaining tokens
    if (token0Balance > 0) token0.safeTransfer(msg.sender, token0Balance);
    if (token1Balance > 0) token1.safeTransfer(msg.sender, token1Balance);
}
```
{% endcode %}

[`KodiakIslandWithRouter.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Kodiak/KodiakIslandWithRouter/src/vaults/KodiakIslandWithRouter.sol#L95-L107)

{% code overflow="wrap" %}
```solidity
function getAvgPrice(uint32 interval) public view returns (uint160 avgSqrtPriceX96) {
    // ... (omitted) ...
    // Use UniswapV3 Pool's built-in oracle
    (int56[] memory tickCumulatives,) = pool.observe(secondsAgo);
    require(tickCumulatives.length == 2, "array len");
    unchecked {
        int24 avgTick = int24((tickCumulatives[1] - tickCumulatives[0]) / int56(uint56(interval)));
        avgSqrtPriceX96 = avgTick.getSqrtRatioAtTick();
    }
}
```
{% endcode %}

[`WeightedMath.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Bex/contracts/WeightedMath.sol#L37-L44)

{% code overflow="wrap" %}
```solidity
// Swap limit: swap amount cannot be greater than this percentage of the total balance (30%)
uint256 internal constant _MAX_IN_RATIO = 0.3e18;
uint256 internal constant _MAX_OUT_RATIO = 0.3e18;
// ... (omitted) ...
_require(amountIn <= balanceIn.mulDown(_MAX_IN_RATIO), Errors.MAX_IN_RATIO);
// ... (omitted) ...
_require(amountOut <= balanceOut.mulDown(_MAX_OUT_RATIO), Errors.MAX_OUT_RATIO);
```
{% endcode %}

***

### Threat 4: Token Swap Slippage Maximization and Minimum Output Calculation Errors <a href="#id-4" id="id-4"></a>

Due to large trades, the actual execution price may fluctuate unfavorably, resulting in receiving far fewer tokens than expected. Alternatively, an error in the minimum output calculation may cause a loss by delivering fewer tokens than the minimum amount specified by the user.

#### Impact

`Informational`

Although a sharp increase in slippage due to large trades or an error in the minimum output calculation can lead to users receiving fewer tokens than the minimum amount they specified, this primarily results in an unfavorable execution for individual traders and does not directly impact the overall security of the system. Therefore, it is rated as `Informational`.

#### Guideline

> * **Slippage Tolerance Setting and Verification:**
>   * Like major DEXs such as Uniswap and SushiSwap, guide users to input their own slippage tolerance, pre-defining the maximum slippage threshold before a trade. If the limit is exceeded, the trade is automatically canceled.\
>     (In Uniswap, users can directly specify the slippage percentage in the UI during a swap).
>   *   Use a [formula](../../reference.md#id-49.-slippage-tolerance-setting-and-verification)<sub>49</sub> to verify that the minimum amount entered by the user matches the actually calculated minimum output and confirm the actual amount to be paid (the type of formula may vary by protocol).
>
>       $${\scriptsize (\text{Example: }\text{Minimum Output} = \text{Input Amount} \times (1 - \text{Slippage Tolerance}))}$$
>   * Automatically cancel the trade if the slippage limit is exceeded, as is standard in major DEXs.
> * **Splitting Large Trades:**
>   * Like DEXs on the [1inch](../../reference.md#id-50.-mass-trade-splitting)<sub>50</sub> network, split large trades across multiple DEXs/liquidity pools to minimize slippage and perform slippage verification for each trade.
>   *   To prevent flash loan/MEV attacks and ensure market stability, set a minimum block interval between split trades to restrict their execution in different blocks.
>
>       (Based on UniswapV3, the N value is dynamically specified according to time, generally set between [30 minutes to 1 hour](https://github.com/Uniswap/v3-core/blob/d8b1c635c275d2a9450bd6a78f3fa2484fef73eb/contracts/UniswapV3Pool.sol#L246C17-L246C28)).
>
>       $$\scriptsize {\text(Example: \text{Total Slippage} = 1 - \prod_{i=1}^{n} (1 - \text{Slippage}_i)) \space (n = \text{BlockNum})}$$
> * **Real-time Price Monitoring and Verification:**
>   * Just before trade execution, re-query the oracle/pool price, and if the price fluctuation exceeds a threshold, perform a recalculation or handle the exception, similar to DEX Screeners and Aggregators.
>   * Receive prices from multiple oracles like Chainlink and Band for multi-source price utilization and cross-verification. If the deviation is large, cancel the trade or switch to an alternative source.
>   *   Apply and monitor a real-time slippage prediction formula based on current liquidity, using a formula like the one below.
>
>       $$\scriptsize \text{Price Impact} = 1 - \frac{x}{x + \Delta x} \scriptsize {(x = \text{PoolAmount}, \Delta x =\text{TradeSize})}$$

#### Best Practice

[`WeightedMath.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Bex/contracts/WeightedMath.sol#L37-L44)

```solidity
// Swap limit: swap amount cannot be greater than this percentage of the total balance (30%)
// Prevents price fluctuations from excessively large trades & maintains pool stability
// The swap limit varies by protocol based on their risk model
// Balancer uses a range from 0.0001% to 10%

uint256 internal constant _MAX_IN_RATIO = 0.3e18;
uint256 internal constant _MAX_OUT_RATIO = 0.3e18;
// ... (omitted) ...
_require(amountIn <= balanceIn.mulDown(_MAX_IN_RATIO), Errors.MAX_IN_RATIO);
// ... (omitted) ...
_require(amountOut <= balanceOut.mulDown(_MAX_OUT_RATIO), Errors.MAX_OUT_RATIO);
```

\[[Source for Balancer Swap Limit](https://docs.balancer.fi/concepts/vault/swap-fee.html#setting-a-static-swap-fee)]

[`KodiakIslandWithRouter.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Kodiak/KodiakIslandWithRouter/src/vaults/KodiakIslandWithRouter.sol#L68-L93)

{% code overflow="wrap" %}
```solidity
// Calculate minimum output based on slippage
function worstAmountOut(uint256 amountIn, uint16 slippageBPS, uint160 avgSqrtPriceX96, bool zeroForOne) public pure returns (uint256) {
    // Verify slippage limit
    require(slippageBPS <= 10000, "Invalid slippage");

    uint256 slippage = uint256(avgSqrtPriceX96) * slippageBPS / 10000;

    uint256 sqrtX96 = zeroForOne ? avgSqrtPriceX96 - slippage : avgSqrtPriceX96 + slippage;

    // ... (omitted) ...
}

// Utilize average price based on TWAP
function getAvgPrice(uint32 interval) public view returns (uint160 avgSqrtPriceX96) {
    // ... (omitted) ...

    (int56[] memory tickCumulatives,) = pool.observe(secondsAgo);

    // ... (omitted) ...

    int24 avgTick = int24((tickCumulatives[1] - tickCumulatives[0]) / int56(uint56(interval)));
    avgSqrtPriceX96 = avgTick.getSqrtRatioAtTick();
}

// Verify actual AmountOut by calculating the worst-case output considering slippage
function executiveRebalanceWithRouter(int24 newLowerTick, int24 newUpperTick, SwapData calldata swapData) external whenNotPaused onlyManager {
    require(swapRouter[swapData.router], "Unauthorized router");
    {
        uint256 worstOut = worstAmountOut(swapData.amountIn, compounderSlippageBPS, getAvgPrice(compounderSlippageInterval), swapData.zeroForOne);
        require(swapData.minAmountOut > worstOut, "Set reasonable minAmountOut");
    }
    ...
}
```
{% endcode %}

***

### Threat 5: Fee Management and Modification Vulnerabilities <a href="#id-5" id="id-5"></a>

An administrator could suddenly change the fee rate significantly or withdraw a large amount of fees instantly, causing unexpected losses for liquidity providers.

#### Impact

`Informational`

If an administrator suddenly changes the fee rate or withdraws a large amount of fees, it could cause unexpected losses for liquidity providers. However, this is considered an operational issue that does not directly impact the overall security of the system, so it is rated as `Informational`.

#### Guideline

> * **Automated Fee Management:**
>   *   At the protocol level, handle fee collection automatically with a [trigger for automatic collection](../../reference.md#id-51.-automated-fee-management)<sub>51</sub> when a certain accumulated fee threshold is reached, similar to DEXs like Uniswap and Balancer.
>
>       $$\left( \text{balance0} \times 1000 - \text{amount0In} \times 3 \right) \times\left( \text{balance1} \times 1000 - \text{amount1In} \times 3 \right)\geq\text{reserve0} \times \text{reserve1} \times 1000^2 \\ \scriptsize \text{- balance0, balance1: The balance of token0 and token1 remaining in the pool after the swap.}\\ \text{- amount0In, amount1In: The amount of input token0 and token1 used in the swap.}\\ \text{- reserve0, reserve1: The balance of token0 and token1 before the swap.}$$
>   * Prevent unpredictable large withdrawals by setting a regular collection cycle for fee distribution/withdrawal, as seen in protocols like Curve and SushiSwap.$$\scriptsize (\text{Example: Current Time} - \text{Last Collection Time} \geq \text{Collection Interval})$$
> * **Permission and Change Management:**
>   *   Apply a [timelock](../../reference.md#id-52.-applying-timelock-to-fee-changes)<sub>52</sub> for large withdrawals or sensitive administrator function executions, as shown in the formula below.
>
>       $$\scriptsize \text{Execute Time} = \text{Request Time} + \text{2 days} \text{ (UniswapV2 Example)}$$

#### Best Practice

[`ProtocolFeesWithdrawer.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Bex/contracts/ProtocolFeesWithdrawer.sol#L172-L176)

{% code overflow="wrap" %}
```solidity
// Verify permissions with the `authenticate` modifier
function setPOLFeeCollectorPercentage(uint256 _polFeeCollectorPercentage) external override authenticate {
    // Verify fee limit
    require(_polFeeCollectorPercentage <= FixedPoint.ONE, "MAX_PERCENTAGE_EXCEEDED");
    polFeeCollectorPercentage = _polFeeCollectorPercentage;
    emit POLFeeCollectorPercentageChanged(_polFeeCollectorPercentage);
}

// Batch fee processing
function distributeAndWithdrawCollectedFees(IERC20[] calldata tokens) external override authenticate {
    (
        uint256[] memory polFeeCollectorFees,
        uint256[] memory feeReceiverFees
    ) = _checkWithdrawableTokensAndDistributeFees(tokens); // Verify fee distribution
    _protocolFeesCollector.withdrawCollectedFees(tokens, polFeeCollectorFees, polFeeCollector);
    _protocolFeesCollector.withdrawCollectedFees(tokens, feeReceiverFees, feeReceiver);
}
```
{% endcode %}

***

### Threat 6: Mismatches during Pool State Updates <a href="#id-6" id="id-6"></a>

During a pool rebalancing, if only some token states are changed and the transaction fails midway, it can lead to a mismatch in the pool's invariant or total supply.

#### Impact

`Informational`

If only some token states are changed during a pool rebalancing and the transaction fails, it can lead to a mismatch in the pool's invariant or total supply. However, this is primarily an operational error and does not directly impact the overall security of the system, so it is rated as `Informational`.

#### Guideline

> * **Ensuring Atomic Transactions:**
>   * All pool state changes should be handled within a single transaction to update related variables at once. To prevent re-entrancy during state changes, apply a Re-entrancy Guard like [Uniswap V2's lock mechanism](https://github.com/Uniswap/v2-core/blob/ee547b17853e71ed4e0101ccfd52e70d5acded58/contracts/UniswapV2Pair.sol#L31-L36).
>   * Use keywords like `require`/`assert` to ensure that if an error occurs during an intermediate execution step, the entire transaction is rolled back, preventing any intermediate state from being left behind.
> * **Intermediate State Verification:**
>   *   Immediately after each pool update, verify the invariant using a simple AMM formula like X \* Y = K from Uniswap or a weighted invariant verification formula like Balancer's to prevent price errors, arbitrage, and potential losses.\
>       (In Berachain's case, a [Balancer-style weighted invariant verification formula](https://github.com/balancer/balancer-v2-monorepo/blob/36d282374b457dddea828be7884ee0d185db06ba/pkg/pool-weighted/contracts/WeightedMath.sol#L56-L74) is used).
>
>       $$V = \Pi^{n}_{i=1}B_i^{W_i}$$
>   *   To reduce arbitrage arising from interactions between multiple pools or tokens, check for price consistency between pools and [verify the conservation of the total token supply](../../reference.md#id-55.-balancer-weightedmath-invariant-verification)<sub>55</sub> using a set formula.
>
>       $$\scriptsize (\text{Example: }\sum_{i=1}^{n} \text{Token Supply}_i = \text{Total Supply}\space (n=\text{BlockNum}) )$$
> * **Pool State Synchronization:**
>   * If synchronization is required across multiple pools/chains, set up alerts and automatic responses if the state mismatch exceeds a defined threshold.

#### Best Practice

[`WeightedMath.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Bex/contracts/WeightedMath.sol#L56-L74)

{% code overflow="wrap" %}
```solidity
// Weight-based auto-rebalancing and invariant verification
function _calculateInvariant(uint256[] memory normalizedWeights, uint256[] memory balances)
    internal
    pure
    returns (uint256 invariant)
{
    invariant = FixedPoint.ONE;
    for (uint256 i = 0; i < normalizedWeights.length; i++) {
        invariant = invariant.mulDown(balances[i].powDown(normalizedWeights[i]));
    }
    _require(invariant > 0, Errors.ZERO_INVARIANT);
}
```
{% endcode %}

[^1]: [https://www.chainsecurity.com/blog/curve-lp-oracle-manipulation-post-mortem](https://www.chainsecurity.com/blog/curve-lp-oracle-manipulation-post-mortem)

[^2]: [https://curve.fi/files/stableswap-paper.pdf](https://curve.fi/files/stableswap-paper.pdf)
