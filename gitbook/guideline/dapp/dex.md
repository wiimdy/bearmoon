---
icon: rotate-reverse
---

# dApp 보안 가이드라인: DEX

<table><thead><tr><th width="597.64453125">위협</th><th align="center">영향도</th></tr></thead><tbody><tr><td><a data-mention href="dex.md#id-1-lp">#id-1-lp</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="dex.md#id-2">#id-2</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="dex.md#id-3">#id-3</a></td><td align="center"><code>Informational</code></td></tr><tr><td><a data-mention href="dex.md#id-4">#id-4</a></td><td align="center"><code>Informational</code></td></tr><tr><td><a data-mention href="dex.md#id-5">#id-5</a></td><td align="center"><code>Informational</code></td></tr><tr><td><a data-mention href="dex.md#id-6">#id-6</a></td><td align="center"><code>Informational</code></td></tr></tbody></table>

### 위협 1: LP 토큰 가치 계산 및 발행 오류

풀에 유동성을 추가할 때 실제 풀 자산 가치와 발행되는 LP 토큰 가치가 일치하지 않아 신규 유동성 제공자가 과도한 이득이나 손실을 볼 수 있다.

#### 영향도

`Low`

LP 토큰 가치 계산 및 발행 오류로 인해 신규 유동성 제공자가 실제 풀 자산 가치와 불일치하는 LP 토큰을 받을 경우 일부 사용자가 제한적으로 손실이나 이득을 볼 수 있기 때문에 `Low`로 평가한다.

#### 가이드라인

> * **정확한 가치 계산:**
>   * Chainlink, Uniswap Twap 등 신뢰할 수 있는 오라클에서 각 토큰의 현재 시장 가격 실시간 반영하여 최소 1분 \~ 최대 3분 이내로 갱신된 데이터만 사용하며, 참고하는 오라클 간 가격 편차가 일정 비율 이상(Ex: [Chainlink - 0.5% \~ 2% 이내](https://docs.chain.link/chainlink-nodes/oracle-jobs/all-jobs#spec-format-2))이면 추가 검증
>   *   토큰별 유동성 비율을 곱해 가가중 평균 가격 계산 시 유동성 비중 적용
>
>       $$\text{Pool Value} = (\text{tokenA}_amount \times \text{priceA}) + (\text{tokenB}_amount \times \text{priceB})$$
>   * 새로운 유동성의 풀 전체 대비 정확한 비중 계산
> * **수치 정밀도 보장:**
>   * SafeMath, FixedPointMathLib 등과 같은 고정소수점 연산 라이브러리 필수 사용하여 최소 18자리의 소수점 연산 정밀도 사용
>   * 연산 중간값을 고정소수점 단위로 변환 후 사용하여 중간 [계산 결과](../../reference.md#id-42.-lp)<sub>42</sub>의 정밀도가 1e18 미만으로 떨어지지 않도록 검증 및 유지
>   * 덧셈/곱셈 순서를 최적화하여 큰 수부터 연산하고 마지막에 나누기 적용하는 방식으로 연산하며, SafeMath, FixedPointMathLib 등의 수치 정밀도를 보장하는 수식 연산 모듈을 사용
> * **실시간 검증:**
>   *   아래 수식의 일치 여부를 통해 계산된 LP 토큰의 가치와 실제 풀 자산 가치 비교
>
>       $$\text{LP Total Supply} \times \text{Current LP Token Value} \approx \text{LP Pool TVL}$$
>   * 유동성 추가 트랜잭션 실행 직후 계산된 발행 예정량과 실제 발행 LP 토큰 수량이 일치하는지 확인

#### Best Practice

[`ProtocolFeesWithdrawer.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Bex/contracts/ProtocolFeesWithdrawer.sol#L187-L204)

```solidity
using FixedPoint for uint256;
// ... 중략 ...
polFeeCollectorFees[i] = amount.mulDown(polFeeCollectorPercentage);
// ... 중략 ...
feeReceiverFees[i] = amount.sub(polFeeCollectorFees[i]);
// ... 중략 ...
polFeeCollectorPercentage = FixedPoint.ONE; // 100%
require(_polFeeCollectorPercentage <= FixedPoint.ONE, "MAX_PERCENTAGE_EXCEEDED");
```

***

### 위협 2: 유동성 제거 타이밍 공격 및 최소 유동성 우회

공격자가 가격이 급등락하는 순간을 노려 유동성을 제거해 풀 내 잔여 유동성이 기준치 이하로 떨어지거나 최소 보유 기간을 우회해 빠르게 이익을 실현할 수 있다.

#### 영향도

`Low`

가격 급등락 시점에 공격자가 유동성을 제거해 풀 내 잔여 유동성이 기준치 이하로 떨어지거나 최소 보유 기간을 우회해 이익을 실현할 수 있으나 풀 전체에 미치는 영향이 제한적이기 때문에 `Low`로 평가한다.

#### 가이드라인

> * **최소 유동성 검증:**
>   *   유동성 제거 전 풀별 최소 유동성 임계값을 아래와 같이 스마트 컨트랙트에 적용하여 검증\
>       (⍺ 값은 풀의 불균형을 유발하는 행위에 대해 높은 비율의 페널티를 발생시키기 위해 사용하는 계수로 [Curve Finance 기준 10 \*\* 6 으로 설정](https://github.com/curvefi/curve-contract/blob/574f44027d089de0eac765f5a74ea5ae96aba968/contracts/pools/3pool/StableSwap3Pool.vy#L87))
>
>       $$\text{MinLiquidity} = \max\left(\text{BaseAmount},\ \text{AvgVolume}_{\text{N Days}} \times \alpha\right) \\ \scriptsize (\text{Pool Value}_\text{after removal} \geq \text{MinLiquidity})$$
>   *   풀 내 각 토큰의 잔고 x 시장 가격의 합이 일정 수준 이하로 떨어지면 가격 조작/MEV 공격에 취약해지므로 유동성 제거 시점의 오라클 가격 기준으로 토큰 가치 기준 합산 후 임계값 이상인지 실시간 검증
>
>       $$\text{Pool Value} = \sum_{i=1}^{n} (\text{Token}_i\, \text{Balance} \times \text{Token}_i\, \text{Price}) \\ {\scriptsize (\text{Pool Vaule}_\text {after removal} \geq \text{MinLiquidity})}$$
> * **타이밍 공격 방지:**
>   *   Uniswap V3 등의 사례와 같이 유동성 제거 요청 시점의 오라클/TWAP 가격을 고정을 고정하여 실제 제거가 처리될 때까지 최초 요청 가격을 기준으로 정산 검증
>
>       $$\text{Remove Value} = \text{Liquidity Amount} \times \text{Price}_{\text{request}}$$
>   *   유동성 제거 시, 최근 N 블록의 평균 가격(TWAP)을 정산 기준으로 활용하여 [일시적 가격 조작방지](../../reference.md#id-45.-twap-n)<sub>45</sub>
>
>       $$\text{TWAP} = \frac{1}{N}\Sigma^{N}_{j=1} \text{Price}_{\text{block }j} \space \scriptsize (N=\text{Block Number})$$
>   *   Curve, Balancer 등과 같이 프로토콜 레벨에서 유동성 제공 후 LP 토큰 수령 시 [최소 보유 기간](../../reference.md#id-43)<sub>43</sub>이 지나야만 유동성 제거가 가능하도록 조건 추가
>
>       $$(\text{Example: } \text{Current Time} - \text{LP Mint Time} \geq \text{Min Hold Period})$$

#### Best Practice

[`WeightedMath.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Bex/contracts/WeightedMath.sol#L41-L44)

불변량 비율 제한은 프로토콜 리스크 모델에 따라 달라질 수 있으며, 아래의 코드는 Balancer의 가중치 불변량 공식에 따른 최대/최소 불변량 제한을 명시한 코드임

<pre class="language-solidity"><code class="lang-solidity">// <a data-footnote-ref href="#user-content-fn-1">최대 300% 불변량 증가 제한</a>
uint256 internal constant _MAX_INVARIANT_RATIO = 3e18;
// <a data-footnote-ref href="#user-content-fn-2">최소 70% 불변량 감소 </a>
uint256 internal constant _MIN_INVARIANT_RATIO = 0.7e18;
</code></pre>

***

### 위협 3: 유동성 풀 불균형

특정 토큰에만 대량 입출금이 반복되면서 풀 내 토큰 비율이 심하게 무너지고 이로 인해 가격이 왜곡되거나 일부 토큰의 유동성이 고갈될 수 있다. 공격자는 플래시론을 이용해 단일 블록에서 대량의 자금을 빌려 풀 가격을 급격히 조작한 뒤 이익을 챙기고 바로 상환하여 일반 사용자가 왜곡된 가격에 거래하도록 유도한다.

#### 영향도

`Informational`

특정 토큰에만 대량 입출금이 반복되어 풀 내 자산 비율이 심하게 무너질 경우, 가격 왜곡이나 일부 토큰 유동성 고갈이 발생할 수 있으나 시스템 전체의 보안이나 직접적 손실로 이어지지 않기 때문에 `Informational`로 평가한다.

#### 가이드라인

> * **플래시론 공격 방지**
>   * 프로토콜 수준에서 단일 거래가 유동성 풀 가격에 미칠 수 있는 최대 변동률을 하드캡으로 강제
>   * 트랜잭션 내 플래시론 제공 함수 호출 또는 대규모 차입-스왑-상환 패턴 감지 시 Uniswap, Balancer와 유사하게 기본 스왑 수수료 외 1%의 추가 수수료 부과하여 공격 성공시의 실익 감소 유도
>   * 동일 트랜잭션 내에서 플래시론 실행 함수 재진입을 통한 공격을 방지하기 위해 lock 제한자 적용
> * **오라클 가격 검증**
>   * 최소 2개 이상의 독립적 오라클 가격 소스 활용하여 오라클 간 가격 편차가 1.5%를 초과할 경우 해당거래 거부 또는 추가 검증 실시
>     * Chainlink, Band Protocol 등의 오라클 네트워크에서 운용하는 임계값
>   * Compound, [Synthetix](../../reference.md#id-41.-synthetix)<sub>41</sub> 등의 DeFi 프로토콜은 1% 이내의 오라클 괴리를 허용 한계로 지정하고 괴리 누적에 의한 유동성 공급자 손실 방지를 위해 3분 이상 갱신되지 않으면 거래 일시 정지\
>     $$\Delta P \approx \sigma \times \sqrt{t} \\\space {\scriptsize (\text{Example: } \sigma = 0.5\%, t = 3 \text{min} \implies \Delta P \approx 0.5\% \times \sqrt{3} \approx 0.866\%) }$$
>   * TWAP(Time-Weighted Average Price) 등 평균 가격을 사용해 단일 거래의 가격 조작 영향 최소화
> * **자동 리밸런싱 메커니즘**
>   *   Uniswap, Curve 등의 AMM 서비스와 같이 유동성 풀 내 자산 가치 비율 유지를 위한 목표 비율 대비 편차 [임계값 설정](../../reference.md#id-49)<sub>49</sub>하여 초과 시 리밸런싱을 트리거 하도록 실시
>
>       $$\text{Example: } \text{Ratio}_A = \frac{\text{Value}_A}{\text{Value}_A+\text{Value}_B}, \quad \text{Threshold} \approx \frac{C_{gas} + C_{swap}}{\text{Value}_A + Value_B} \\ \scriptsize (|\text{Ratio}_A-\text{Target Ratio}_A| > \text{Threshold} \Rightarrow \text{Rebalance Trigger}) \\ \scriptsize C_{gas}\text{: 리밸런싱 트랜잭션을 실행하는 데 필요한 네트워크 가스 비용} \\ \scriptsize C_{swap}\text{: 유동성 풀에 지불하는 스왑 수수료} \\ \scriptsize \text{Value}_A + \text{Value}_B\text{: 풀에 예치된 자산 A와 B의 총 시장가치}$$
>   * Uniswap의 [x\*y=k ](../../reference.md#curve-stableswap)<sub>47</sub>곡선과 같이 편차 발생 시 스마트 컨트랙트에서 시 자동 리밸런싱하는 트리거를 제공하여 가격 균형 회복 유도
> * **불균형 모니터링**
>   * 기존 DEX 서비스와 유사하게 풀내 자산 비율, TVL 등의 주요 지표를 실시간 대시보드에서 추적 및 계산하는 기능 제공 필요
>   * 운영하는 유동성 풀 비율이 목표치를 크게 벗어날 경우 편차 단계별 경고 시스템을 통해 관리자가 즉시 대응할 수 있는 경고 시스템 구축
> * **자동 스왑 처리**
>   *   Curve, Balancer 등과 같이 단일 토큰으로 유동성 공급 시 자동으로 풀의 비율에 맞게 스왑 후 유동성 공급하여 풀 불균형, 가격 왜곡, 유동성 고갈을 방지하며 Balancer v1 기준 공식은 아래와 같음
>
>       $$V = \Pi^{n}_{i=1}B_i^{W_i} \\ \scriptsize \text{Example: } V = (B_A^{W_A}) \times (B_A^{W_A}) \times (B_C^{W_C}) \quad (n = 3) \\ (B_{A, B, C} : \text{Token}_{A,B,C}\space\text{ Balances}) \\ (W_{A, B, C}: \text{Token}_{A,B,C}\space\text{Weights})$$
> * **최소 유동성 요구사항**
>   *   Balancer 기준 각 풀의 최근 N일 평균 거래량의 10% 또는 1만 달러 중 큰 값 이상을 최소 유동성으로 요구하며 이는 프로토콜 별 거버넌스에 따라 차이가 발생
>
>       $$\text{MinLiquidity} = \max\left( \text{BaseAmount},\ \text{AvgVolume}_{N\text{Days}} \times \alpha \right) \\ {\scriptsize ( \text{Example: } \text{MinLiquidity} = \max(10{,}000,\ 150{,}000 \times 0.1 ) = 15{,}000)}$$
>   * Uniswap, KyberSwap 등의 AMM에서 슬리피지에 의한 시장 가격 왜곡을 방지하기 위해 단일 거래가 풀 잔고의 정해진 비율을 넘지 못하도록 제한\
>     (AMM 프로토콜의 리스크 모델에 따라 거래 규모 제한이 다를 수 있으며, 예시 코드 기준으로 30% 적용)\
>     $$\text{Price Impact} = 1 - \frac{x}{x + \Delta x} \space \scriptsize (x = \text{Pool Balance}, \Delta x = \text{Asset Increment}) \\ \scriptsize (\text{Example: } 1 - \frac{1}{1 + 0.4286} \approx 0.3 \approx 30\%)$$

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
    // 자동 스왑
    (uint256 token0Balance, uint256 token1Balance) = _swapAndVerify(token0, token1, tokenIn, swapData);
    // LP토큰 발행을 위한 토큰 양 계산
    (amount0, amount1, mintAmount) = island.getMintAmounts(token0Balance, token1Balance);
    require(mintAmount >= amountSharesMin, "Staking: below min share amount");
		
    // 프로토콜별로 슬리피지 조건이 다르며, Kodiak 기준으로 10000 BPS (100%) 로 구현되어 있음.
    if (swapData.zeroForOne) require(amount1 >= token1Balance * (10000 - maxStakingSlippageBPS) / 10000, "Staking Slippage: below min amounts");
    else require(amount0 >= token0Balance * (10000 - maxStakingSlippageBPS) / 10000, "Staking Slippage: below min amounts");

    token0Balance -= amount0;
    token1Balance -= amount1;
    // 유동성 공급
    _deposit(island, amount0, amount1, mintAmount, receiver);

    // 남은 토큰 반환
    if (token0Balance > 0) token0.safeTransfer(msg.sender, token0Balance);
    if (token1Balance > 0) token1.safeTransfer(msg.sender, token1Balance);
}
```
{% endcode %}

[`KodiakIslandWithRouter.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Kodiak/KodiakIslandWithRouter/src/vaults/KodiakIslandWithRouter.sol#L95-L107)

{% code overflow="wrap" %}
```solidity
function getAvgPrice(uint32 interval) public view returns (uint160 avgSqrtPriceX96) {
    // ... 중략 ...
    //UniswapV3 Pool 내장 오라클 사용
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
// 스왑 한도: 스왑 금액은 총 잔액의 해당 비율보다 클 수 없음 (30%)
uint256 internal constant _MAX_IN_RATIO = 0.3e18;
uint256 internal constant _MAX_OUT_RATIO = 0.3e18;
// ... 중략 ...
_require(amountIn <= balanceIn.mulDown(_MAX_IN_RATIO), Errors.MAX_IN_RATIO);
// ... 중략 ...
_require(amountOut <= balanceOut.mulDown(_MAX_OUT_RATIO), Errors.MAX_OUT_RATIO);
```
{% endcode %}

***

### 위협 4: 토큰 스왑 슬리피지 극대화 및 최소 아웃풋 계산 오류

대량 거래로 인해 실제 체결 가격이 불리하게 변동되어 예상보다 훨씬 적은 토큰을 받게 된다. 또는 최소 아웃풋 계산에 오류가 있어 사용자가 입력한 최소 수량보다 적은 토큰이 지급되어 손실이 발생할 수 있다.

#### 영향도

`Informational`

대량 거래로 인해 슬리피지가 급격히 커지거나 최소 아웃풋 계산 오류로 사용자가 입력한 최소 수량보다 적은 토큰을 받을 수 있으나, 이는 주로 개별 거래자의 불리한 체결로 이어지고 시스템 전체의 보안에는 직접적인 영향을 미치지 않기 때문에 `Informational`로 평가한다.

#### 가이드라인

> * **슬리피지 허용 한도 설정 및 검증:**
>   * Uniswap, SushiSwap 등의 주요 DEX와 같이 사용자가 직접 슬리피지 한도를 입력하도록 유도하여 거래 전 최대 슬리피지 임계값 사전 정의하고 한도 초과 시 자동 취소\
>     (Uniswap의 경우 swap 과정에서 사용자가 UI 상에서 슬리피지 비율을 직접 지정할 수 있음)
>   *   사용자가 입력한 최소 수량과 실제 계산된 최소 아웃풋이 일치하는지 [검증하기 위해 수식](../../reference.md#id-49)<sub>49</sub>을 활용하여 실제 지급량 확인 (프로토콜에 따라 수식 종류가 다를 수 있음)
>
>       $${\scriptsize (\text{Example: }\text{Minimum Output} = \text{Input Amount} \times (1 - \text{Slippage Tolerance}))}$$
>   * 주요 DEX와 동일하게 슬리피지 한도 초과 감지 시 거래 자동 취소 처리
> * **대량 거래 시 분할 처리:**
>   * [1inch](../../reference.md#id-50)<sub>50</sub> 네트워크 등의 DEX와 동일하게 여러 DEX / 유동성 풀에 대형 거래를 분할하여 슬리피지를 최소화하고 각 거래별 슬리피지 검증 실시
>   *   플래시론/MEV 공격 방지, 시장 안정성 확보를 위해 각 분할 거래를 서로 다른 블록에 실행하도록 제한하기 위해 분할 거래 간 최소 블록 간격 설정
>
>       (UniswapV3 기준으로 N값을 시간에 따라 유동적으로 지정하며 일반적으로 [30분 \~ 1시간](https://github.com/Uniswap/v3-core/blob/d8b1c635c275d2a9450bd6a78f3fa2484fef73eb/contracts/UniswapV3Pool.sol#L246C17-L246C28) 사이를 지정함)
>
>       $$\scriptsize {\text(Example: \text{Total Slippage} = 1 - \prod_{i=1}^{n} (1 - \text{Slippage}_i)) \space (n = \text{BlockNum})}$$
> * **실시간 가격 모니터링 및 검증:**
>   * DEX Screener, Aggregator 등과 같이 거래 실행 직전 오라클/풀 가격 재조회 및 가격 변동 임계값 초과 시 재계산 또는 예외처리 실시
>   * Chainlink, Band 등의 여러 오라클에서 가격을 받아 다중 가격 소스 활용 및 교차 검증하고 편차가 크면 거래 취소 또는 대체 소스 전환
>   *   아래 수식과 같은 방식으로 현재 유동성 기반 실시간 슬리피지 예측 공식 적용하여 모니터링 및 검증 실시
>
>       $$\scriptsize \text{Price Impact} = 1 - \frac{x}{x + \Delta x} \scriptsize {(x = \text{PoolAmount}, \Delta x =\text{TradeSize})}$$

#### Best Practice

[`WeightedMath.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Bex/contracts/WeightedMath.sol#L37-L44)

```solidity
// 스왑 한도: 스왑 금액은 총 잔액의 해당 비율보다 클 수 없음 (30%)
// 풀 안정성 & 과도하게 큰 거래로 인한 가격변동 방지
// 스왑 한도는 프로토콜 별로 프로토콜별 리스크 모델에 따라 다르며
// Balancer의 경우 0.0001% ~ 10%로 사용

uint256 internal constant _MAX_IN_RATIO = 0.3e18;
uint256 internal constant _MAX_OUT_RATIO = 0.3e18;
// ... 중략 ...
_require(amountIn <= balanceIn.mulDown(_MAX_IN_RATIO), Errors.MAX_IN_RATIO);
// ... 중략 ...
_require(amountOut <= balanceOut.mulDown(_MAX_OUT_RATIO), Errors.MAX_OUT_RATIO);
```

\[[Balancer 스왑 한도 출처](https://docs.balancer.fi/concepts/vault/swap-fee.html#setting-a-static-swap-fee)]

[`KodiakIslandWithRouter.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Kodiak/KodiakIslandWithRouter/src/vaults/KodiakIslandWithRouter.sol#L68-L93)

{% code overflow="wrap" %}
```solidity
// 슬리피지 기반 최소 출력 계산
function worstAmountOut(uint256 amountIn, uint16 slippageBPS, uint160 avgSqrtPriceX96, bool zeroForOne) public pure returns (uint256) {
    // 슬리피지 한도 검증
    require(slippageBPS <= 10000, "Invalid slippage");
    
    uint256 slippage = uint256(avgSqrtPriceX96) * slippageBPS / 10000;

    uint256 sqrtX96 = zeroForOne ? avgSqrtPriceX96 - slippage : avgSqrtPriceX96 + slippage;

    // ... 중략 ...
}

// TWAP 기반 평균 가격 활용
function getAvgPrice(uint32 interval) public view returns (uint160 avgSqrtPriceX96) {
    // ... 중략 ...
    
    (int56[] memory tickCumulatives,) = pool.observe(secondsAgo);
    
    // ... 중략 ...
    
    int24 avgTick = int24((tickCumulatives[1] - tickCumulatives[0]) / int56(uint56(interval)));
    avgSqrtPriceX96 = avgTick.getSqrtRatioAtTick();
}

// 슬리피지를 고려한 최악의 출력값을 계산하여 실제 AmountOut 검증
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

### 위협 5: 수수료 관리 및 변경 취약점

관리자가 수수료 비율을 갑자기 크게 변경하거나 대량의 수수료를 즉시 인출해 유동성 제공자들이 예기치 못한 손실을 입을 수 있다.

#### 영향도

`Informational`

관리자가 수수료 비율을 갑자기 변경하거나 대량의 수수료를 인출할 경우 유동성 제공자에게 예기치 않은 손실이 발생할 수 있으나 시스템 전체의 보안에 직접적인 영향을 미치지 않는 운영상의 문제이기 때문에 `Informational`로 평가한다.

#### 가이드라인

> * **자동화된 수수료 관리:**
>   *   Uniswap, Balancer 등의 DEX와 같이 일정 이상의 수수료 누적 임계값 도달 시 [자동 수집 트리거](../../reference.md#id-51)<sub>51</sub>되도록 프로토콜 레벨에서 처리
>
>       $$\left( \text{balance0} \times 1000 - \text{amount0In} \times 3 \right) \times\left( \text{balance1} \times 1000 - \text{amount1In} \times 3 \right)\geq\text{reserve0} \times \text{reserve1} \times 1000^2 \\ \scriptsize \text{- balance0, balance1: swap 이후 풀에 남은 토큰0, 1의 잔액}\\ \text{- amount0In, amount1In: swap에 사용된 입력 토큰 0, 1의 양}\\ \text{- reserve0, reserve1: swap 이전의 토큰 0,1의 잔액}$$
>   * Curve, SushiSwap 등과 같이 수수료 분배/인출을 정기적으로 실행하는 수집 주기를 설정하여 예측 불가능한 대량 인출 방지\
>     $$\scriptsize (\text{Example: Current Time} - \text{Last Collection Time} \geq \text{Collection Interval})$$
> * **권한 및 변경 관리:**
>   *   대량 인출 또는 민감한 관리자 함수 실행 시 [타임락 적용](../../reference.md#id-52)<sub>52</sub>을 아래 수식과 같이 적용
>
>       $$\scriptsize \text{Execute Time} = \text{Request Time} + \text{2 days} \text{ (UniswapV2 Example)}$$

#### Best Practice

[`ProtocolFeesWithdrawer.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Bex/contracts/ProtocolFeesWithdrawer.sol#L172-L176)

{% code overflow="wrap" %}
```solidity
// `authenticate` 모디파이어로 권한 검증
function setPOLFeeCollectorPercentage(uint256 _polFeeCollectorPercentage) external override authenticate {
    // 수수료 상한 검증
    require(_polFeeCollectorPercentage <= FixedPoint.ONE, "MAX_PERCENTAGE_EXCEEDED");
    polFeeCollectorPercentage = _polFeeCollectorPercentage;
    emit POLFeeCollectorPercentageChanged(_polFeeCollectorPercentage);
}

// 배치 수수료 처리
function distributeAndWithdrawCollectedFees(IERC20[] calldata tokens) external override authenticate {
    (
        uint256[] memory polFeeCollectorFees,
        uint256[] memory feeReceiverFees
    ) = _checkWithdrawableTokensAndDistributeFees(tokens); // 수수료 분배 검증
    _protocolFeesCollector.withdrawCollectedFees(tokens, polFeeCollectorFees, polFeeCollector);
    _protocolFeesCollector.withdrawCollectedFees(tokens, feeReceiverFees, feeReceiver);
}
```
{% endcode %}

***

### 위협 6: 풀 상태 업데이트시 불일치

풀 리밸런싱 도중 일부 토큰의 상태만 변경되고 중간에 트랜잭션이 실패하여 풀의 불변량이나 총 공급량이 맞지 않는 불일치 상태가 발생할 수 있다.

#### 영향도

`Informational`

풀 리밸런싱 과정에서 일부 토큰 상태만 변경되고 트랜잭션이 실패할 경우 풀의 불변량이나 총 공급량 불일치가 발생할 수 있으나 이는 주로 운영상 오류로 시스템 전체 보안에는 직접적인 영향을 미치지 않기 때문에 `Informational`로 평가한다.

#### 가이드라인

> * **원자적 거래 보장:**
>   * 모든 풀 상태 변경을 단일 트랜잭션 내 처리하여 관련 변수를 한 번에 갱신해야 하며, 상태 변경 중 재진입 방지를 위해 [Uniswap V2의 lock 매커니즘](https://github.com/Uniswap/v2-core/blob/ee547b17853e71ed4e0101ccfd52e70d5acded58/contracts/UniswapV2Pair.sol#L31-L36)과 같은 Re-entrancy Gaurd 적용
>   * require/assert 등의 키워드를 이용하여 중간 실행 단계에서 오류 발생 시 전체 거래가 롤백되는 메커니즘을 적용하여 중간 상태가 남지 않도록 설계
> * **중간 상태 검증:**
>   *   Uniswap 등의 단순 AMM에서 사용하는 X \* Y = K 수식 또는 Balancer와 같은 가중치 불변량 검증 수식을 이용하여 각 풀 업데이트 직후 불변량 검증을 통해 가격 오류, 아비트라지, 손실 발생 가능성 차단\
>       (Berachain의 경우 [Balancer 방식의 가중치 불변량 검증 수식](https://github.com/balancer/balancer-v2-monorepo/blob/36d282374b457dddea828be7884ee0d185db06ba/pkg/pool-weighted/contracts/WeightedMath.sol#L56-L74) 사용)
>
>       $$V = \Pi^{n}_{i=1}B_i^{W_i}$$
>   *   여러 풀 또는 토큰 간의 연동으로 인해 발생하는 아비트라지를 줄이기 위해 정해진 수식을 이용하여 풀 간 가격 일관성 확인 및 [총 토큰 공급량 보존 검증](../../reference.md#id-55.-balancer-weightedmath)<sub>55</sub>
>
>       $$\scriptsize (\text{Example: }\sum_{i=1}^{n} \text{Token Supply}_i = \text{Total Supply}\space (n=\text{BlockNum}) )$$
> * **풀 상태 동기화:**
>   * 여러 풀/체인 간 동기화가 필요한 경우 상태 불일치가 정해진 임계값을 넘으면 경고 및 자동 대응 설정

#### Best Practice

[`WeightedMath.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Bex/contracts/WeightedMath.sol#L56-L74)

{% code overflow="wrap" %}
```solidity
// 가중치 기반 자동 리밸런싱 및 불변량 검증
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
