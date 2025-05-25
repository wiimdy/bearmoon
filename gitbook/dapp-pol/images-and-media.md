---
icon: rotate-reverse
---

# dApp: DEX 가이드라인

### 위협 1: 토큰 스왑 슬리피지 극대화 및 최소 아웃풋 계산 오류

#### 가이드라인

> * **슬리피지 허용 한도 설정 및 검증:**
>   * **거래 전 최대 슬리피지 임계값 사전 정의 (예: 0.5%, 1%, 2%)**
>   * **사용자 설정 슬리피지와 계산된 최소 아웃풋 일치 확인**
>   * **슬리피지 초과 시 거래 자동 취소**
> * **대량 거래 시 분할 처리:**
>   * **임계값 초과 거래 자동 분할 알고리즘 (예: 총 유동성의 5% 초과시)**
>   * **분할 거래 간 최소 블록 간격 설정 (예: 1-2 블록)**
>   * **분할 거래별 개별 슬리피지 검증 및 전체 누적 슬리피지 확인**
> * **실시간 가격 모니터링 및 검증:**
>   * **거래 실행 직전 최신 가격 재확인 및 가격 변동 임계값 초과 시 계산 재수행**
>   * **다중 가격 소스 활용 및 교차 검증, 가격 소스 장애 시 대체 소스 전환**
>   * **현재 유동성 기반 실시간 슬리피지 예측 공식**

#### Best Practice

```solidity
// BEX/contracts/WeightedMath.sol
// 스왑 한도: 스왑 금액은 총 잔액의 해당 비율보다 클 수 없음 (30%)
// 풀 안정성 & 과도하게 큰 거래로 인한 가격변동 방지
uint256 internal constant _MAX_IN_RATIO = 0.3e18;
uint256 internal constant _MAX_OUT_RATIO = 0.3e18;
// ... 중략 ...
_require(amountIn <= balanceIn.mulDown(_MAX_IN_RATIO), Errors.MAX_IN_RATIO);
// ... 중략 ...
_require(amountOut <= balanceOut.mulDown(_MAX_OUT_RATIO), Errors.MAX_OUT_RATIO);

```

```solidity
// KodiakIslandWithRouter/src/vaults/KodiakIslandWithRouter.sol
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

### 위협 2: 풀 상태 업데이트시 불일치

#### 가이드라인

> * **원자적 거래 보장:**
>   * **모든 관련 풀 상태 변경을 단일 트랜잭션 내 처리**
>   * **중간 단계 실패 시 전체 거래 롤백 메커니즘**
> * **중간 상태 검증:**
>   * **각 풀 업데이트 후 K=xy 불변량 검증**
>   * **풀 간 가격 일관성 확인 및 총 토큰 공급량 보존 검증**
> * **풀 상태 동기화:**
>   * **풀 간 상태 불일치 탐지 임계값 설정 (예: 0.1% 가격 편차)**
>   * **자동 재동기화 트리거 및 동기화 실패 시 풀 일시 중단**

#### Best Practice

```solidity
// BEX/contracts/WeightedMath.sol
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

***

### 위협 3: 토큰 가격 조작 및 플래시론 공격

#### 가이드라인

> * **플래시론 공격 방지:**
>   * **거래 전후 가격 변동률 제한 (예: 단일 블록 내 ±10%)**
>   * **플래시론 사용 탐지 시 추가 수수료 자동 부과**
>   * **동일 블록 내 복수 거래 수수료 누적 계산**
> * **오라클 가격 검증:**
>   * **최소 2개 이상 독립적 오라클 가격 소스 활용**
>   * **오라클 간 가격 편차 임계값 설정 (예: 5% 이내)**
>   * **가격 업데이트 주기 검증 (예: 최근 1시간 이내)**
> * **최소 유동성 요구사항:**
>   * **풀별 최소 유동성 임계값 동적 설정**
>   * **유동성 대비 거래량 비율 제한 (예: 단일 거래 최대 30%)**

#### Best Practice

<pre class="language-solidity"><code class="lang-solidity"><strong>//KodiakIslandWithRouter/src/vaults/KodiakIslandWithRouter.sol
</strong>function getAvgPrice(uint32 interval) public view returns (uint160 avgSqrtPriceX96) {
    // ... 중략 ...
    //UniswapV3 Pool 내장 오라클 사용
    (int56[] memory tickCumulatives,) = pool.observe(secondsAgo);
    require(tickCumulatives.length == 2, "array len");
    unchecked {
        int24 avgTick = int24((tickCumulatives[1] - tickCumulatives[0]) / int56(uint56(interval)));
        avgSqrtPriceX96 = avgTick.getSqrtRatioAtTick();
    }
}
</code></pre>

```solidity
// BEX/contracts/WeightedMath.sol
// 스왑 한도: 스왑 금액은 총 잔액의 해당 비율보다 클 수 없음 (30%)
uint256 internal constant _MAX_IN_RATIO = 0.3e18;
uint256 internal constant _MAX_OUT_RATIO = 0.3e18;
// ... 중략 ...
_require(amountIn <= balanceIn.mulDown(_MAX_IN_RATIO), Errors.MAX_IN_RATIO);
// ... 중략 ...
_require(amountOut <= balanceOut.mulDown(_MAX_OUT_RATIO), Errors.MAX_OUT_RATIO);
```

***

## 유동성 풀 관리 취약점



### 위협 4: 유동성 풀 불균형

#### 가이드라인

> * **자동 리밸런싱 메커니즘:**
>   * **목표 비율 대비 편차 임계값 설정 (예: ±15%)**
>   * **편차 발생 시 자동 리밸런싱 트리거 실행**
> * **불균형 모니터링:**
>   * **실시간 풀 비율 추적 및 편차 계산**
>   * **편차 단계별 경고 시스템 (5%, 10%, 15% 단계별 알림)**
> * **동적 수수료 조정:**
>   * **불균형 정도에 비례한 수수료 조정 공식**
>   * **부족한 토큰 공급 시 해당 방향 거래 수수료 증가**

#### Best Practice

```solidity
// BEX/contracts/WeightedMath.sol
uint256 internal constant _MIN_WEIGHT = 0.01e18;
uint256 internal constant _MAX_WEIGHTED_TOKENS = 100;
```

***

### 위협 5: LP 토큰 가치 계산 및 발행 오류

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

```solidity
// BEX/contracts/ProtocolFeesWithdrawer.sol
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

### 위협 6: 유동성 제거 타이밍 공격 및 최소 유동성 우회

#### 가이드라인

> * **최소 유동성 검증:**
>   * **풀별 절대적 최소 유동성 임계값 설정**
>   * **토큰 가치 기준 최소 유동성 검증 (USD 기준)**
>   * **유동성 제거 시 잔여 유동성 임계값 사전 검증**
> * **타이밍 공격 방지:**
>   * **제거 요청 시점의 가격 고정 및 검증**
>   * **다중 블록 평균 가격 활용으로 조작 방지**
>   * **유동성 제공 후 최소 보유 기간 설정 (예: 24시간)**

#### Best Practice

```solidity
// BEX/contracts/WeightedMath.sol
// 최대 300% 불변량 증가 제한
uint256 internal constant _MAX_INVARIANT_RATIO = 3e18;
// 최소 70% 불변량 감소 제한
uint256 internal constant _MIN_INVARIANT_RATIO = 0.7e18;
```

***

## 프로토콜 수수료 취약점

### 위협 7: 수수료 관리 및 변경 취약점

#### 가이드라인

> * **자동화된 수수료 관리:**
>   * **수수료 누적 임계값 도달 시 자동 수집 트리거**
>   * **정기적 수집 주기 설정 (예: 매 24시간)**
> * **권한 및 변경 관리:**
>   * **대량 인출 시 타임락 적용 (예: 72시간 지연)**
>   * **수수료 변경 시 단계적 적용**

#### Best Practice

```solidity
// BEX/contracts/ProtocolFeesWithdrawer.sol
// `authenticate` 모디파이어로 권한 검증
function setPOLFeeCollectorPercentage(uint256 _polFeeCollectorPercentage) external override authenticate {
    // 수수료 상한 검증
    require(_polFeeCollectorPercentage <= FixedPoint.ONE, "MAX_PERCENTAGE_EXCEEDED");
    polFeeCollectorPercentage = _polFeeCollectorPercentage;
    emit POLFeeCollectorPercentageChanged(_polFeeCollectorPercentage);
}
```

```solidity
// BEX/contracts/ProtocolFeesWithdrawer.sol
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
