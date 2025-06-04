---
icon: honey-pot
---

# PoL 보안 가이드라인: 오라클 및 HONEY

<table><thead><tr><th width="591.7421875">위협</th><th align="center">영향도</th></tr></thead><tbody><tr><td><a data-mention href="honey.md#id-1">#id-1</a></td><td align="center"><code>Medium</code></td></tr><tr><td><a data-mention href="honey.md#id-2-basket">#id-2-basket</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="honey.md#id-3-basket">#id-3-basket</a></td><td align="center"><code>Informational</code></td></tr><tr><td><a data-mention href="honey.md#id-4">#id-4</a></td><td align="center"><code>Informational</code></td></tr></tbody></table>

### 위협 1: 외부 오라클 가격 조작 및 신뢰할 수 없는 오라클 로직

외부 오라클 가격 조작 및 신뢰할 수 없는 오라클 로직(단일 소스 의존, 비대칭 처리 등)을 통해 HONEY 토큰의 민팅/리딤 과정에서 프로토콜 손실 또는 사용자 피해가 발생할 수 있다.

#### 영향도

`Medium`

#### 가이드라인

> * **3개 이상의 독립적인 오라클 피드 중앙값 또는 가중 평균을 최종 가격으로 사용**
> * **오라클 프로세스 명시(추가, 수정, 삭제)**
>   * **추가:** 신규 오라클 추가시 거버넌스 투표 절차 필요
>   * **수정:** 기존 오라클에 대한 가중치 조정 시 최소 72시간 전 사전 공지 및 거버넌스 피드백 기간 필요
>     * **72시간 사전공지:** 거버넌스 참여에 충분한 시간 확보
>   * **삭제:** 오라클 피드 제거 시 대체 오라클 필요
>   * **긴급 중단:**&#x20;
>     * 권한자: 멀티시그 또는 거버넌스가 선출한 매니저로 제한&#x20;
>     * 중단 후 처리: 및 24시간 내에 커뮤니티 공지 및 복구 계획 제출
>     * 복구 절차: 거버넌스 승인 필요
> * **오라클 이상 시 처리 로직 구체화**
>   * 특정 오라클 30초 이상 연결 지연 시 해당 오라클 집계에서 자동 제외
>   * 다른 피드들의 중앙값 대비 ±0.1% 초과 시 가중치 70% 감소, ±0.15% 초과 시 자동 제외
>     * **±0.1% 경고:** Honey 페깅 허용범위(0.2%)의 50% 수준
>     * **±0.15% 제외:** Honey 페깅 허용범위의 75% 수준
>   * 최소 3개 이상의 오라클을 참조하여 가격 결정 및 그 미만일 경우 거래 일시 중단
>   * 비활성화된 오라클 재활성화 시 검증 필요(비활성화 사유, 활성화 가능 여부)
>   * 주 오라클 이상 시 보조 오라클로 자동 전환 메커니즘
> * **오라클 가격 사전 설정된 임계치 이상 변동시 사용자에게 경고**
>   * **임계치 설정:** 1분 가격 ±0.1% 초과 시 사용자 경고, ±0.15% 초과 시 Circuit Breaker
>   * **임계치 변경:** 임계치 변경 시 최소 72시간 전 사전 공지 및 거버넌스 피드백 기간 필요
> * **오라클 간의 로직 비대칭성 확인**
>   * "Spot 오라클 가격이 $1.00 초과 시 → $1.00으로 처리"과 같은 특정 오라클 로직이 아닌 일반화 필요
> * **일정 기간의 TWAP 기준 가격 결정을 통해 실시간 오라클 조작 공격 영향 완화**
> * **HONEY 토큰의 심각한 페깅 이탈을 악용한 경제적 공격을 방지하기 위해 비정상적인 거래량 급증 또는 반복적인 공격 패턴 감지 시 거래 지연이나 추가 검증을 요구하는 메커니즘 도입 고려**

#### Best Practice

&#x20;[`HoneyFactory.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Core/src/honey/HoneyFactory.sol#L569-L578)&#x20;

```solidity
// 페깅 로직 확인
function isPegged(address asset) public view returns (bool) {
    if (!priceOracle.priceAvailable(asset)) return false;
    IPriceOracle.Data memory data = priceOracle.getPriceUnsafe(asset);
    if (data.publishTime < block.timestamp - priceFeedMaxDelay) return false;
    return (1e18 - lowerPegOffsets[asset] <= data.price) && (data.price <= 1e18 + upperPegOffsets[asset]);
}
```

[`HoneyFactory.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Core/src/honey/HoneyFactory.sol#L163-L170)&#x20;

```solidity
// 오라클에서 최신 가격을 가져오도록 설
function setMaxFeedDelay(uint256 maxTolerance) external {
    _checkRole(MANAGER_ROLE);
    if (maxTolerance > MAX_PRICE_FEED_DELAY_TOLERANCE) {
        AmountOutOfRange.selector.revertWith();
    }
    priceFeedMaxDelay = maxTolerance;
    emit MaxFeedDelaySet(maxTolerance);
}
```

`커스텀 코드`&#x20;

```solidity
// 여러 오라클에서 가격을 수집하여 가중 평균으로 최종 가격을 계산하는 다중 오라클 집계 시스템

contract MultiOracleSystem {
    struct OracleData {
        address oracle;
        uint256 weight;
        bool isActive;
    }
    
    mapping(address => OracleData[]) public assetOracles;
    
    function getAggregatedPrice(address asset) external view returns (uint256) {
        OracleData[] memory oracles = assetOracles[asset];
        uint256 totalWeight = 0;
        uint256 weightedSum = 0;
        
        for (uint256 i = 0; i < oracles.length; i++) {
            if (oracles[i].isActive) {
                uint256 price = IPriceOracle(oracles[i].oracle).getPrice(asset);
                weightedSum += price * oracles[i].weight;
                totalWeight += oracles[i].weight;
            }
        }
        
        return totalWeight > 0 ? weightedSum / totalWeight : 0;
    }
}
```

***

### 위협 2: Basket 모드 내 가중치 결정 로직의 외부 영향 취약성 또는 예측 가능성

Basket 모드에서 여러 스테이블 코인을 특정 비율에 따라 반환하거나 요구할 때 구성 비율 결정 로직이 외부 가격 피드의 일시적 오류, 특정 풀의 유동성 급변 등 외부 요인에 의해 공격자에게 유리하게 예측되거나 형성될 수 있다면, 공격자는 Basket 모드 활성화 시점 또는 특정 시장 상황을 노려 자신에게 유리한 조건으로 자산을 교환하려 시도할 수 있다.

#### 영향도

`Low`

#### 가이드라인

> * **외부 오라클 가격을 참조해야 할 경우, 다수 오라클의 평균값을 사용하고 급격한 변동을 방지하기 위한 스무딩 메커니즘을 도입하여 외부 공격에 대한 저항성 증대.**
> * **가중치 결정 로직을 투명하게 공개하며 실시간 외부 변수에 과도하게 의존하여 공격 표면을 넓히지 않도록 설계.**
> * **TWAP 또는 VWAP을 사용하여 단기적인 가격 조작 공격 방어.**

#### Best Practice

[`HoneyFactory.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Core/src/honey/HoneyFactory.sol#L664-L693)&#x20;

```solidity
function _getWeights(bool filterBadCollaterals, bool filterPausedCollateral) internal view returns (uint256[] memory weights) {
    weights = new uint256[](registeredAssets.length);
    uint256 sum = 0;
    
    for (uint256 i = 0; i < registeredAssets.length; i++) {
        if (filterBadCollaterals && isBadCollateralAsset[registeredAssets[i]]) continue;
        if (filterPausedCollateral && vaults[registeredAssets[i]].paused()) continue;
        
        weights[i] = _getSharesWithoutFees(registeredAssets[i]);
        sum += weights[i];
    }
    
    if (sum == 0) return weights;
    for (uint256 i = 0; i < registeredAssets.length; i++) {
        weights[i] = weights[i] * 1e18 / sum;
    }
}
```

`커스텀 코드`&#x20;

```solidity
// 1시간 동안의 시간 가중 평균 가격을 계산하여 단기적인 가격 조작을 방지하고 안정적인 가중치 결정을 위한 스무딩 시스템

contract TWAPBasedWeights {
    struct TWAPData {
        uint256 cumulativePrice;
        uint256 lastUpdateTime;
        uint256 twapPrice;
    }
    
    mapping(address => TWAPData) public twapData;
    uint256 public constant TWAP_PERIOD = 1 hours;
    
    function updateTWAP(address asset, uint256 currentPrice) external {
        TWAPData storage data = twapData[asset];
        uint256 timeElapsed = block.timestamp - data.lastUpdateTime;
        
        if (timeElapsed > 0) {
            data.cumulativePrice += currentPrice * timeElapsed;
            if (timeElapsed >= TWAP_PERIOD) {
                data.twapPrice = data.cumulativePrice / TWAP_PERIOD;
                data.cumulativePrice = 0;
            }
            data.lastUpdateTime = block.timestamp;
        }
    }
}
```

***

### 위협 3: 지나치게 민감한 디페깅 기준 및 Basket 모드 활성화 조건 악용

매우 낮은 수준의 가격 변동에도 디페깅으로 간주하는 기준은, 사소한 시장 변동성에도 Basket 모드를 빈번하게 활성화시켜 사용자 경험을 저해할 수 있다.&#x20;

또한, 공격자가 의도적으로 특정 구성 스테이블 코인의 미세한 디페깅을 유도하여 Basket 모드를 발동시키고 사용자가 예측하지 못한 자산 구성 비율로 민트 또는 리딤하도록 유도할 가능성이 있다.&#x20;

예를 들어, 복수의 구성 스테이블 코인 중 일부만 소폭 디페깅된 경우에도 Basket 모드에 의한 상환이 강제된다면 사용자는 정상 페깅 상태인 자산으로만 받기를 원했음에도 불구하고 원치 않는 디페깅 자산을 일부 수령하게 될 위험이 있다.

#### 영향도

`Informational`

#### 가이드라인

> * **시장의 일반적인 변동성을 고려하여 디페깅 판단 기준의 민감도를 조정하고, 일시적인 미세 변동이 아닌 일정 시간 이상 지속되는 유의미한 가격 이탈 시에만 디페깅으로 간주하는 시간적 요소를 도입**
> * **Basket 모드 활성화는 최후의 안정성 유지 수단으로 고려하며 페깅 자산의 안정성 회복을 우선시**
> * **가능한 한 사용자가 선호하는 단일 페깅 자산으로 민팅/리딤할 수 있는 옵션을 우선적으로 제공하여 사용자 편의성과 예측 가능성 보장**

#### Best Practice

[`HoneyFactory.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Core/src/honey/HoneyFactory.sol#L526-L553)&#x20;

```solidity
function isBasketModeEnabled(bool isMint) public view returns (bool) {
    if (forcedBasketMode) return true;
    
    for (uint256 i = 0; i < registeredAssets.length; i++) {
        address asset = registeredAssets[i];
        if (isBadCollateralAsset[asset] || vaults[asset].paused()) continue;
        if (isMint && !isPegged(asset)) return true;
    }
    return false;
}
```

`커스텀 코드`&#x20;

```solidity
// 일시적인 가격 변동이 아닌 1시간 이상 지속되는 디페깅을 유효한 디페깅으로 인정하여 Basket 모드의 민감도를 낮추는 시간 기반 감지 시스템

contract TimeBasedDepegDetection {
    struct DepegRecord {
        uint256 startTime;
        bool isActive;
    }
    
    mapping(address => DepegRecord) public depegRecords;
    uint256 public constant MIN_DEPEG_DURATION = 1 hours;
    
    function checkSustainedDepeg(address asset) external view returns (bool) {
        DepegRecord memory record = depegRecords[asset];
        return record.isActive && block.timestamp >= record.startTime + MIN_DEPEG_DURATION;
    }
}
```

***

### 위협 4: 디페깅된 자산의 상환시 가치 평가 및 사용자 고지 불확실성

"디페깅된 자산으로는 민팅이 불가능하다"는 정책은 사용자가 자산을 상환할 때, Basket 모드에 디페깅된 스테이블 코인이 포함될 경우 발생할 수 있는 문제다.&#x20;

해당 디페깅된 자산이 어떤 가격으로 평가되어 사용자에게 반환되는지, 이 과정에서 사용자가 어느 정도의 잠재적 손실을 감수해야 하는지에 대한 기준과 고지가 명확하지 않다면 사용자는 예상치 못한 손실을 입을 수 있다.

#### 영향도

`Informational`

#### 가이드라인

> * **상환 시 Basket 모드가 활성화 된 경우, 디페깅된 자산의 가치는 신뢰할 수 있는 복수의 외부 오라클을 참조하여 확실한 체크 필요**
> * **사용자에게 상환 과정에서 디페깅 자산이 포함될 수 있다는 점, 해당 자산의 평가 기준, 그리고 이로 인한 잠재적 손실 가능성에 대해 명확하고 이해하기 쉽게 고지하는 절차 필요**
> * **필요시 프로토콜 차원에서 디페깅된 자산으로 인한 급격한 손실 위험을 일부 완화할 수 있는 내부 준비금(Insurance Fund 등) 운영 고려**

#### Best Practice

[`HoneyFactory.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Core/src/honey/HoneyFactory.sol#L368-L418)&#x20;

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
        // Basket 모드 상환 로직
    }
}
```

`커스텀 코드`&#x20;

```solidity
// 상환 전 디페깅된 자산 포함 여부와 예상 손실을 미리 계산하여 사용자에게 경고하고 위험 인지 확인을 받는 사전 고지 시스템

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
        
        for (uint256 i = 0; i < assets.length; i++) {
            if (!isPegged(assets[i])) {
                depeggedCount++;
                totalLoss += calculateLoss(assets[i], honeyAmount);
            }
        }
        
        return RedeemWarning(depeggedCount > 0, totalLoss, assets);
    }
    
    function acknowledgeRisk(uint256 honeyAmount) external {
        // 사용자 위험 인지 확인
        emit RiskAcknowledged(msg.sender, honeyAmount);
    }
} 
```

\
