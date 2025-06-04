---
icon: rotate-reverse
---

# dApp 보안 가이드라인: DEX

<table><thead><tr><th width="597.64453125">위협</th><th align="center">영향도</th></tr></thead><tbody><tr><td><a data-mention href="dex.md#id-1">#id-1</a></td><td align="center"><code>Medium</code></td></tr><tr><td><a data-mention href="dex.md#id-2-lp">#id-2-lp</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="dex.md#id-3">#id-3</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="dex.md#id-4">#id-4</a></td><td align="center"><code>Informational</code></td></tr><tr><td><a data-mention href="dex.md#id-5">#id-5</a></td><td align="center"><code>Informational</code></td></tr><tr><td><a data-mention href="dex.md#id-6">#id-6</a></td><td align="center"><code>Informational</code></td></tr><tr><td><a data-mention href="dex.md#id-7">#id-7</a></td><td align="center"><code>Informational</code></td></tr></tbody></table>

### 위협 1: 토큰 가격 조작 및 플래시론 공격

공격자가 플래시론을 이용해 단일 블록에서 대량의 자금을 빌려 풀 가격을 급격히 조작한 뒤 이익을 챙기고 바로 상환하여 일반 사용자가 왜곡된 가격에 거래하게 만든다.

#### 영향도&#x20;

`Medium`

#### 가이드라인

> * **플래시론 공격 방지:**
>   * **프로토콜 수준에서 단일 거래가 유동성 풀 가격에 미칠 수 있는 최대 변동률을 하드캡으로 강제**
>   * **트랜잭션 내 플래시론 제공 함수 호출 또는 대규모 차입-스왑-상환 패턴 감지 시 기본 스왑 수수료 외 1%의 추가 수수료 부과**
>   * **동일 블록 내 반복 플래시론 거래 시 거래 횟수에 따라 누적 수수료 적용 (ex: 1회 1%, 2회 2% 등)**
> * **오라클 가격 검증:**
>   * **최소 2개 이상 독립적 오라클 가격 소스 활용하여 오라클 간 가격 편차가 1.5%를 초과할 경우 해당거래 거부 또는 추가 검증 실시**
>   * **일반적인 DeFi 프로토콜은 1% 이내의 오라클 괴리를 허용 한계로 지정하고 괴리 누적에 의한 유동성 공급자 손실 방지를 위해 3분 이상 갱신되지 않으면 거래 일시 정지**\
>     $$\Delta P \approx \sigma \times \sqrt{t} \space {\scriptsize (\text{Example: } \sigma = 0.5\%, t = 3 \text{min} \implies \Delta P \approx 0.5\% \times \sqrt{3} \approx 0.866\%) }$$ \
>     일반적인 DeFi 프로토콜은 1% 이내의 오라클 괴리를 허용 한계로 삼으며 3분 이상 지날 시&#x20;
>   * **TWAP(Time-Weighted Average Price) 등 평균 가격을 사용해 단일 거래의 가격 조작 영향 최소화**
> * **최소 유동성 요구사항:**
>   *   **각 풀의 최근 7일 평균 거래량의 10% 또는 1만 달러 중 큰 값 이상을 최소 유동성으로 요구**
>
>       $$\text{MinLiquidity} = \max\left( \text{BaseAmount},\ \text{AvgVolume}_{N\text{Days}} \times \alpha \right) \\ {\scriptsize ( \text{Example: } \text{MinLiquidity} = \max(10{,}000,\  150{,}000 \times 0.1 ) = 15{,}000)}$$
>   * **단일 거래가 풀 잔고의 최대 10%를 넘지 못하도록 제한 (시장 상황에 따라 5 \~ 15% 범위 내에서 조정)**

#### Best Practice

[`KodiakIslandWithRouter.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Kodiak/KodiakIslandWithRouter/src/vaults/KodiakIslandWithRouter.sol#L95-L107)

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

[`WeightedMath.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Bex/contracts/WeightedMath.sol#L37-L44)

```solidity
// 스왑 한도: 스왑 금액은 총 잔액의 해당 비율보다 클 수 없음 (30%)
uint256 internal constant _MAX_IN_RATIO = 0.3e18;
uint256 internal constant _MAX_OUT_RATIO = 0.3e18;
// ... 중략 ...
_require(amountIn <= balanceIn.mulDown(_MAX_IN_RATIO), Errors.MAX_IN_RATIO);
// ... 중략 ...
_require(amountOut <= balanceOut.mulDown(_MAX_OUT_RATIO), Errors.MAX_OUT_RATIO);
```

***

### 위협 2: LP 토큰 가치 계산 및 발행 오류

풀에 유동성을 추가할 때 실제 풀 자산 가치와 발행되는 LP 토큰 가치가 일치하지 않아 신규 유동성 제공자가 과도한 이득이나 손실을 볼 수 있다.

#### 영향도&#x20;

`Low`

#### 가이드라인

> * **정확한 가치 계산:**
>   * **각 토큰의 현재 시장 가격 실시간 반영**
>   * **가중 평균 가격 계산 시 유동성 비중 적용**
>   * **새로운 유동성의 풀 전체 대비 정확한 비중 계산**
> * **수치 정밀도 보장:**
>   * **고정소수점 연산 라이브러리 필수 사용 (최소 18자리)**
>   * **중간 계산 결과의 정밀도 검증 및 유지**
>   * **반올림 오차 누적 방지를 위한 연산 순서 최적화**
> * **실시간 검증:**
>   * **계산된 LP 토큰 가치와 실제 풀 자산 가치 비교**
>   * **발행 예정량과 실제 발행량 일치 확인**
>   * **편차 임계값 초과 시 계산 로직 재검증**

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

### 위협 3: 유동성 제거 타이밍 공격 및 최소 유동성 우회

공격자가 가격이 급등락하는 순간을 노려 유동성을 제거해 풀 내 잔여 유동성이 기준치 이하로 떨어지거나 최소 보유 기간을 우회해 빠르게 이익을 실현할 수 있다.

#### 영향도&#x20;

`Low`

#### 가이드라인

> * **최소 유동성 검증:**
>   * **풀별 절대적 최소 유동성 임계값 설정**
>   * **토큰 가치 기준 최소 유동성 검증**
>   * **유동성 제거 시 잔여 유동성 임계값 사전 검증**
> * **타이밍 공격 방지:**
>   * **제거 요청 시점의 가격 고정 및 검증**
>   * **다중 블록 평균 가격 활용으로 조작 방지**
>   * **유동성 제공 후 최소 보유 기간 설정**

#### Best Practice

[`WeightedMath.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Bex/contracts/WeightedMath.sol#L41-L44)

```solidity
// 최대 300% 불변량 증가 제한
uint256 internal constant _MAX_INVARIANT_RATIO = 3e18;
// 최소 70% 불변량 감소 제한
uint256 internal constant _MIN_INVARIANT_RATIO = 0.7e18;
```

***

### 위협 4: 유동성 풀 불균형

특정 토큰에만 대량 입출금이 반복되면서 풀 내 토큰 비율이 심하게 무너지고 이로 인해 가격이 왜곡되거나 일부 토큰의 유동성이 고갈될 수 있다.

#### 영향도&#x20;

`Informational`

#### 가이드라인

> * **자동 리밸런싱 메커니즘:**
>   * **목표 비율 대비 편차 임계값 설정**
>   * **편차 발생 시 자동 리밸런싱 트리거 실행**
> * **불균형 모니터링:**
>   * **실시간 풀 비율 추적 및 편차 계산**
>   * **편차 단계별 경고 시스템**
> * **자동 스왑 처리:**
>   * **단일 토큰으로 유동성 공급 시 풀의 비율에 맞게 스왑 후 유동성 공급**

#### Best Practice

[`IslandRouter.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Kodiak/IslandRouter/src/vaults/IslandRouter.sol#L119-L149)

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

***

### 위협 5: 토큰 스왑 슬리피지 극대화 및 최소 아웃풋 계산 오류

대량 거래로 인해 실제 체결 가격이 불리하게 변동되어 예상보다 훨씬 적은 토큰을 받게 된다. 또는 최소 아웃풋 계산에 오류가 있어 사용자가 입력한 최소 수량보다 적은 토큰이 지급되어 손실이 발생할 수 있다.

#### 영향도&#x20;

`Informational`

#### 가이드라인

> * **슬리피지 허용 한도 설정 및 검증:**
>   * **거래 전 최대 슬리피지 임계값 사전 정의**
>   * **사용자 설정 슬리피지와 계산된 최소 아웃풋 일치 확인**
>   * **슬리피지 초과 시 거래 자동 취소**
> * **대량 거래 시 분할 처리:**
>   * **임계값 초과 거래 자동 분할 알고리즘**
>   * **분할 거래 간 최소 블록 간격 설정**
>   * **분할 거래별 개별 슬리피지 검증 및 전체 누적 슬리피지 확인**
> * **실시간 가격 모니터링 및 검증:**
>   * **거래 실행 직전 최신 가격 재확인 및 가격 변동 임계값 초과 시 계산 재수행**
>   * **다중 가격 소스 활용 및 교차 검증, 가격 소스 장애 시 대체 소스 전환**
>   * **현재 유동성 기반 실시간 슬리피지 예측 공식**

#### Best Practice

[`WeightedMath.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Bex/contracts/WeightedMath.sol#L37-L44)

```solidity
// 스왑 한도: 스왑 금액은 총 잔액의 해당 비율보다 클 수 없음 (30%)
// 풀 안정성 & 과도하게 큰 거래로 인한 가격변동 방지

uint256 internal constant _MAX_IN_RATIO = 0.3e18;
uint256 internal constant _MAX_OUT_RATIO = 0.3e18;
// ... 중략 ...
_require(amountIn <= balanceIn.mulDown(_MAX_IN_RATIO), Errors.MAX_IN_RATIO);
// ... 중략 ...
_require(amountOut <= balanceOut.mulDown(_MAX_OUT_RATIO), Errors.MAX_OUT_RATIO);

```

[`KodiakIslandWithRouter.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Kodiak/KodiakIslandWithRouter/src/vaults/KodiakIslandWithRouter.sol#L68-L93)

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

***

### 위협 6: 수수료 관리 및 변경 취약점

관리자가 수수료 비율을 갑자기 크게 변경하거나 대량의 수수료를 즉시 인출해 유동성 제공자들이 예기치 못한 손실을 입을 수 있다.

#### 영향도&#x20;

`Informational`

#### 가이드라인

> * **자동화된 수수료 관리:**
>   * **수수료 누적 임계값 도달 시 자동 수집 트리거**
>   * **정기적 수집 주기 설정**
> * **권한 및 변경 관리:**
>   * **대량 인출 시 타임락 적용**
>   * **수수료 변경 시 단계적 적용**

#### Best Practice

[`ProtocolFeesWithdrawer.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Bex/contracts/ProtocolFeesWithdrawer.sol#L172-L176)

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

***

### 위협 7: 풀 상태 업데이트시 불일치

풀 리밸런싱 도중 일부 토큰의 상태만 변경되고 중간에 트랜잭션이 실패하여 풀의 불변량이나 총 공급량이 맞지 않는 불일치 상태가 발생할 수 있다.

#### 영향도&#x20;

`Informational`

#### 가이드라인

> * **원자적 거래 보장:**
>   * **모든 관련 풀 상태 변경을 단일 트랜잭션 내 처리**
>   * **중간 단계 실패 시 전체 거래 롤백 메커니즘**
> * **중간 상태 검증:**
>   * **각 풀 업데이트 후 `X * Y = K` 불변량 검증**
>   * **풀 간 가격 일관성 확인 및 총 토큰 공급량 보존 검증**
> * **풀 상태 동기화:**
>   * **풀 간 상태 불일치 탐지 임계값 설정**
>   * **자동 재동기화 트리거 및 동기화 실패 시 풀 일시 중단**

#### Best Practice

[`WeightedMath.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Bex/contracts/WeightedMath.sol#L56-L74)

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
