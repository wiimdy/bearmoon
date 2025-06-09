---
icon: honey-pot
---

# PoL 보안 가이드라인: 오라클 및 HONEY

<table><thead><tr><th width="591.7421875">위협</th><th align="center">영향도</th></tr></thead><tbody><tr><td><a data-mention href="honey.md#id-1">#id-1</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="honey.md#id-2-basket">#id-2-basket</a></td><td align="center"><code>Informational</code></td></tr><tr><td><a data-mention href="honey.md#id-3">#id-3</a></td><td align="center"><code>Informational</code></td></tr></tbody></table>

### 위협 1: 외부 오라클 가격 조작 및 신뢰할 수 없는 오라클 로직

외부 오라클 가격 조작 및 신뢰할 수 없는 오라클 로직(단일 오라클 의존, 비대칭 처리 등)을 통해 HONEY 토큰의 민팅/리딤 과정에서 프로토콜 손실 또는 사용자 피해가 발생할 수 있다.

#### 영향도

`Low`

단일 오라클에 의존하거나 디페깅시에 사용자에게 명확히 안내하지 못할 경우 사용자 피해로 이어질 수 있으며 Flash Loan을 통한 가격 조작에 취약할 가능성이 있어 `Low` 로 평가

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

{% code overflow="wrap" %}
```solidity
uint256 private constant DEFAULT_PEG_OFFSET = 0.002e18;
uint256 private constant MAX_PEG_OFFSET = 0.02e18;

// 페깅 로직 확인
function isPegged(address asset) public view returns (bool) {
    if (!priceOracle.priceAvailable(asset)) return false;
    IPriceOracle.Data memory data = priceOracle.getPriceUnsafe(asset);
    if (data.publishTime < block.timestamp - priceFeedMaxDelay) return false;
    return (1e18 - lowerPegOffsets[asset] <= data.price) && (data.price <= 1e18 + upperPegOffsets[asset]);
}
```
{% endcode %}

[`HoneyFactory.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Core/src/honey/HoneyFactory.sol#L163-L170)&#x20;

```solidity
// 오라클에서 최신 가격을 가져오도록 설계
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

{% code overflow="wrap" %}
```solidity
contract EnhancedMultiOracleSystem {
    struct OracleData {
        address oracle;
        uint256 weight;
        bool isActive;
        bool isEmergencyPaused;
    }

// 가이드라인: 긴급 중단 기능
    function emergencyPause(address asset) external onlyManager {
        emergencyPaused[asset] = true;
    }
    
// 가이드라인: 편차 검사 + 가중평균 계산
    function getAggregatedPrice(address asset) external view returns (uint256) {
        require(!emergencyPaused[asset], "Emergency paused");
        
        OracleData[] memory oracles = assetOracles[asset];
        require(oracles.length >= MIN_ORACLES, "Insufficient oracles");
        
        uint256[] memory prices = new uint256[](oracles.length);
        uint256[] memory weights = new uint256[](oracles.length);
        uint256 validCount = 0;
        
        // 1. 가격 수집
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
        
        // 2. 중앙값 계산 및 편차 검사
        uint256 median = _calculateMedian(prices, validCount);
        uint256 totalWeight = 0;
        uint256 weightedSum = 0;
        
        for (uint256 i = 0; i < validCount; i++) {
            uint256 deviation = _calculateDeviation(prices[i], median);
            
            // 0.15% 초과 편차 시 제외
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

### 위협 2: 지나치게 민감한 디페깅 기준 및 Basket 모드 활성화 조건 악용

매우 낮은 수준의 가격 변동에도 디페깅으로 간주하는 기준은 사소한 시장 변동성에도 Basket 모드를 빈번하게 활성화시켜 사용자 경험을 저해할 수 있다.&#x20;

또한, 공격자가 의도적으로 특정 구성 스테이블 코인의 미세한 디페깅을 유도하여 Basket 모드를 발동시키고 사용자가 예측하지 못한 자산 구성 비율로 민팅이나 리딤하도록 유도할 가능성이 존재한다.

예를 들어, 복수의 구성 스테이블 코인 중 일부만 소폭 디페깅된 경우에도 Basket 모드에 의한 상환이 강제된다면 사용자는 정상 페깅 상태인 자산으로만 받기를 원했음에도 원치 않은 자산을 수령하게 될 위험이 발생한다.

#### 영향도

`Informational`

디페깅 기준치는 프로토콜이 결정하는 것이나 민팅과 리딤 로직의 basket 모드가 각각 따로 동작한다면 혼란을 가중시킬 수 있으며, 세분화된 basket 모드를 통해 사용자 편의성을 올리는 편을 권고하기 위해 `Informational` 로 평가

#### 가이드라인

> * **민감도 조정 기준:** 민팅과 리딤시에 각각 따로 basket 모드가 따로 동작하는 것이 아니라 [가격 변동률](../../reference.md#id-0.1-0.2-0.5-0.1-0.2-honey-default_peg_offset-0.5-chainlink) 차이별로 basket 모드의 단계를 나누어 적용
>   * 경고 단계 (0.1%): 1분 지속 시 사용자 알림
>   * (일시적 디페깅) 제한 단계 (0.2%): 1분 지속 시 해당 자산 민팅 제한 및 교환비 조정
>   * (디페깅) Basket 단계 (0.5%): 1분 지속 시 즉시 Basket 모드 활성화
> * **Basket 모드 활성화는 최후의 안정성 유지 수단으로 고려하며 페깅 자산의 안정성 회복 시 자동 해제**
>   * **안정성 회복:** [1시간 연속 안정(0.2% 미만)](../../reference.md#id-1-2-1-180) 시 자동으로 정상 모드 복귀

#### Best Practice

[`HoneyFactory.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Core/src/honey/HoneyFactory.sol#L526-L553)&#x20;

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

`커스텀 코드`&#x20;

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

### 위협 3: 디페깅된 자산의 상환시 가치 평가 및 사용자 고지 불확실성

'디페깅된 자산이 어떤 가격으로 평가되어 사용자에게 반환되는지', '이 과정에서 사용자가 어느 정도의 잠재적 손실을 감수해야 하는지'에 대한 기준과 고지가 명확하지 않다면 사용자는 basket 모드 상태에서 받을 토큰의 가치를 정확하게 평가할 수 없다.

#### 영향도

`Informational`

사용자 편의성 측면에서의 위협이기에 `Informational` 로 평가

#### 가이드라인

> * **Basket 모드가 활성화 된 상태에서 상환 시 디페깅된 자산은** [**3개 이상의 오라클**](../../reference.md#chainlink-3)**을 참조하여 자산의 가치를 평가(현재 베라체인은 신뢰가능한 chainlink 오라클 및 HONEY 오라클로 pyth, spot 오라클 참조)**
>   * 이 과정에서 활성화된 오라클만을 참조(비활성화, 긴급중단 오라클 참조 금지)
> * **사용자에게 상환 과정에서 디페깅 자산이 포함될 수 있다는 점, 디페깅 자산의 평가 기준, 그리고 이로 인한 잠재적 손실 가능성에 대해 명확하고 쉽게 고지하는 절차 필요**
>   * 디페깅된 자산으로 인한 예상 손실을 어떻게 계산하는지에 대한 [수식 기반 설명](../../reference.md#calculateloss-acknowledgerisk)
> * **필요시 프로토콜 차원에서 디페깅된 자산으로 인한 급격한 손실 위험을 일부 완화할 수 있는 내부 준비금 운영 고려**
>   * 준비금 구성은 상환과정에서 발생한 수수료의 일부를 활용해서 내부 준비금으로 운영
>   * 준비금은 basket 모드 활성화 시에 한정하여 활성화하며 사용자 손실을 최소화하는데 사용

#### Best Practice

[`HoneyFactory.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Core/src/honey/HoneyFactory.sol#L368-L418)&#x20;

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
        // Basket 모드 상환 로직
    }
}
```
{% endcode %}

`커스텀 코드`&#x20;

<pre class="language-solidity" data-overflow="wrap"><code class="lang-solidity">// 상환 전 디페깅된 자산 포함 여부와 예상 손실을 미리 계산하여 사용자에게 경고하고 위험 인지 확인을 받는 사전 고지 시스템

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
        // 사용자 위험 인지 확인
        emit RiskAcknowledged(msg.sender, honeyAmount);
    }
} 

// calculateLoss() - Reference [26]: 디페깅 비율 × 자산 가치로 손실 계산
function calculateLoss(address asset, uint256 honeyAmount) internal view returns (uint256) {
    // 1. 현재 시장 가격 조회 (Reference [25]: 다중 오라클)
    uint256 currentPrice = getAggregatedPrice(asset);
    uint256 pegPrice = 1e18; // $1.00
    
    // 2. 디페깅 상황에서만 손실 계산
    if (currentPrice >= pegPrice) return 0;
    
    // 3. 사용자가 받을 해당 자산의 양 계산
    // UserAssetAmount = HoneyAmount × AssetWeight
    uint256[] memory weights = getWeights();
    uint256 assetIndex = getAssetIndex(asset);
    uint256 userAssetAmount = honeyAmount * weights[assetIndex] / 1e18;
    
    // 4. Reference [26] 수식 적용: Loss = AssetValueAtPeg × DepegRatio
    
    // DepegRatio = (PegPrice - CurrentPrice) / PegPrice
    uint256 depegRatio = (pegPrice - currentPrice) * 1e18 / pegPrice;
    
    // AssetValueAtPeg = UserAssetAmount × PegPrice  
    uint256 assetValueAtPeg = userAssetAmount * pegPrice / 1e18;
    
    // Loss = AssetValueAtPeg × DepegRatio
    uint256 loss = assetValueAtPeg * depegRatio / 1e18;
    
    return loss;
}

</code></pre>

\


[^1]: 다중 오라클 집계와 활성화된 오라클만 참조하는 페깅 상태 검증 로직, 신뢰성 있는 가격 판단

[^2]: 레퍼런스 \[26] calculateLoss 수식 레퍼런스\
    디페깅 비율 × 자산 가치로 손실 계산, 사용자 위험 고지와 acknowledgeRisk 확인 필수
