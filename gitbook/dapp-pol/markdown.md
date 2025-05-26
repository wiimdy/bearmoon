---
icon: plane-arrival
---

# dApp: Lending 가이드라인

### 위협 1: 담보별 위험도 평가 미흡으로 인한 과도한 담보 인정

공격자가 새로 추가된 알트코인을 담보로 NECT를 과도하게 차용 후, 해당 토큰 폭락 시 LSP가 손실 흡수

#### 가이드라인

> * **각 담보 자산(iBGT, iBERA, LP 토큰 등)의 유동성, 변동성, 오라클 신뢰도를 개별적으로 평가하고, 이에 따른 LTV(담보인정비율), 청산 임계값, 청산 패널티 등을 차등 설정.**

#### Best Practice

[`DenManager.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Beraborrow/src/core/DenManager.sol)

```solidity
require(params.MCR <= BERABORROW_CORE.CCR() && params.MCR >= 1.1e18, "MCR cannot be > CCR or < 110%");
MCR = params.MCR;
```

***

### 위협 2: 스테이블 코인($NECT)의 디페깅

NECT가 디페깅된 상황에서 공격자가 1달러 상당의 BTC 담보를 redemption으로 회수하여 차익 실현

#### 가이드라인

> * **스테이블 코인 유동성 풀 충분성 확보 및 DEX 거래량 모니터링**
> * **페깅 이탈 시 긴급 안정화 메커니즘 자동 실행**

***

### 위협 3: 담보 가격 오라클 조작을 통한 부당한 청산 및 차용

공격자가 소형 DEX에서 토큰 가격을 플래시론으로 조작하여 PriceFeed를 속이고 저평가된 담보로 과도한 NECT 차용

#### 가이드라인

> * **최소 2개 이상의 독립적인 가격 소스 사용**
> * **가격 편차 임계값 설정 (예: 5% 초과 시 거래 일시 중단)**
> * **타임윈도우 기반 가격 평균화 적용 (TWAP)**
> * **급격한 가격 하락 시 청산 지연 메커니즘 적용**

#### Best Practice

[`PriceFeed.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Beraborrow/src/core/PriceFeed.sol)

```solidity
if (_heartbeat > MAX_ORACLE_HEARTBEAT) revert PriceFeed__HeartbeatOutOfBoundsError();
        IAggregatorV3Interface newFeed = IAggregatorV3Interface(_chainlinkOracle);
        (FeedResponse memory currResponse, FeedResponse memory prevResponse) = _fetchFeedResponses(newFeed);
        
        if (_token == address(0)) revert PriceFeed__PotentialDos();

        if (!_isFeedWorking(currResponse, prevResponse)) {
            revert PriceFeed__InvalidFeedResponseError(_token);
        }
        if (_isPriceStale(currResponse.timestamp, _heartbeat, _staleThreshold)) {
            revert PriceFeed__FeedFrozenError(_token);
        }
```

***

### 위협 4: ERC-4626 인플레이션 공격

LSP의 totalSupply **≈** 0 상태에서 1wei 예치 후 NECT를 직접 전송하여 후속 예치자 지분 탈취

#### 가이드라인

> * **Virtual Shares 메커니즘 구현:**
>   * **초기 배포 시 최소 1000 wei의 가상 지분 및 자산 설정**
>   * **OpenZeppelin의 decimal offset 적용 (최소 6자리)**
>   * **최소 예치금 임계값 설정 (예: 0.01 NECT)**
> * **부트스트랩 기간 보호 강화:**
>   * **`deposit()/mint()`함수에도 whenNotBootstrapPeriod 적용**
>   * **첫 24시간 동안 최소 예치금 100 NECT로 설정**
>   * **totalSupply=0 상태 감지 및 자동 보호 모드 활성화**

#### Best Practice

[`LiquidStabilityPool.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Beraborrow/src/core/LiquidStabilityPool.sol)

```solidity
if (totalSupply() == 0) revert ZeroTotalSupply(); // convertToShares will return 0 for 'assets < totalAssets'
```

```
// Some code
```

***

### 위협 5: 플래시론 재진입 공격

공격자가 플래시론 실행 중  콜백을 이용해 동일 트랜잭션에서 담보 인출과 추가 차용을 동시 실행

#### 가이드라인

> * **CEI 패턴 엄격 적용**
> * **플래시론 실행 중 모든 상태 변경 함수 접근 차단**
> * **ReentrancyGuard 추가**
> * **플래시론 한도를 총 공급량의 50%로 제한**
> * **플래시론 수수료 최소 0.05% 설정**

#### Best Practice

[`DebtToken.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Beraborrow/src/core/DebtToken.sol)

```solidity
function flashFee(address token, uint256 amount) public view returns (uint256) {
        require(token == address(this), "ERC20FlashMint: wrong token");
        return _flashFee(amount);
}
```

***

### 위협 6: 상환 프로세스의 MEV 익스트랙션과 프론트러닝을 통한 사용자 손실

봇이 대량 청산 예정인 Den을 감지하여 프론트러닝으로 먼저 LSP offset 실행, 청산 담보를 할인가에 선점 획득

#### 가이드라인

> * **멀티 상환시 무작위 순서 적용**
> * **상환 수수료의 일부를 Stability Pool에 배분**
> * **상환 트랜잭션 시간 기반 수수료 차등 적용**

***

### 위협 7: ICR/TCR 검증 우회를 통한 과도한 차용

공격자가 DenManager의 adjustDen() 함수에서 Recovery Mode 조건 검증 로직을 우회하여 MCR 미달에서도 추가 NECT 차용

#### 가이드라인

> * **담보 비율 검증 강화**
>   * **모든 포지션 변경 시 개별 ICR과 시스템 TCR 동시 검증**
>   * **Recovery Mode 진입 시 새로운 차용 완전 차단**
>   * **담보 인출 시 최소 150% ICR 유지 강제**
> * **시간 기반 제한**
>   * **포지션 조정 후 24시간 내 재조정 제한**
>   * **대량 담보 인출 시 48시간 타임락 적용**
>   * **급격한 담보 비율 변화 시 추가 검증 요구**

#### Best Practice

[`BeraborrowOperation.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Beraborrow/src/core/BorrowerOperations.sol)

```solidity
if (_isRecoveryMode) {
    require(_collWithdrawal == 0, "BorrowerOps: Collateral withdrawal not permitted Recovery Mode");
    if (_isDebtIncrease) {
        _requireICRisAboveCCR(newICR);
        _requireNewICRisAboveOldICR(newICR, oldICR);
    }
} else {
    _requireICRisAboveMCR(newICR, _vars.MCR, _vars.account);
    _requireNewTCRisAboveCCR(newTCR);
}
```

***

### 위협 8: interestRate 조작을 통한 부당한 이자 부과

#### 가이드라인

> * **이자율 거버넌스 보호:**
>   * **이자율 변경 시 7일 타임락 적용**
>   * **이자율 변경폭 제한**
>   * **이자율 변경 시 커뮤니티 투표 필수**
> * **이자 계산 투명성:**
>   * **모든 이자 계산을 체인상에서 검증 가능하도록 공개**
>   * **이자 누적 로직의 오버플로우 방지**
>   * **이자율 변경 이력 추적 및 감사 가능성 확보**

#### Best Practice

[`DenManager.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Beraborrow/src/core/DenManager.sol)

```solidity
uint256 newInterestRate = (INTEREST_PRECISION * params.interestRateInBps) / (BP * SECONDS_IN_YEAR);
if (newInterestRate != interestRate) {
    _accrueActiveInterests();
    // accrual function doesn't update timestamp if interest was 0
    lastActiveIndexUpdate = block.timestamp;
    interestRate = newInterestRate;
}
```

***

### 위협 9: redeemCollateral()을 통한 selective redemption으로 건전한 포지션 타겟팅

공격자가 redeemCollateral()로 낮은 ICR을 가진 iBGT Den만 선별하여 redemption, 해당 사용자의 iBGT를 시장가 이하로 획득

#### 가이드라인

> * **상환 공정성 보장:**
>   * **상환 시 최저 ICR 포지션부터 강제 순서 적용**
>   * **상환 수수료 최소 0.5% 설정 및 동적 조정**
>   * **대량 상환 시 일일 한도 적용 (총 공급량의 10%)**
> * **상환 baseRate 보호:**
>   * **baseRate 급등 방지를 위한 점진적 증가 메커니즘**
>   * **상환 후 7일간 추가 상환 제한**
>   * **상환 수수료 수익을 Stability Pool에 배분하여 인센티브 정렬**

#### Best Practice

[`DenManager.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Beraborrow/src/core/DenManager.sol)

```solidity
function _updateBaseRateFromRedemption(
        uint256 _collateralDrawn,
        uint256 _price,
        uint256 _totalDebtSupply
    ) internal returns (uint256) {
        uint256 decayedBaseRate = _calcDecayedBaseRate();

        /* Convert the drawn collateral back to debt at face value rate (1 debt:1 USD), in order to get
         * the fraction of total supply that was redeemed at face value. */
        uint256 redeemedDebtFraction = (_collateralDrawn * _price) / _totalDebtSupply;

        uint256 newBaseRate = decayedBaseRate + (redeemedDebtFraction / BETA);
        newBaseRate = BeraborrowMath._min(newBaseRate, DECIMAL_PRECISION); // cap baseRate at a maximum of 100%

        // Update the baseRate state variable
        baseRate = newBaseRate;
        emit BaseRateUpdated(newBaseRate);

        _updateLastFeeOpTime();

        return newBaseRate;
    }

```

***

### 위협 10: 악의적인 DenManager 배포를 통한 시스템 무결성 침해

공격자가 Factory를 통해 가짜 DenManager 배포 후 허니팟 담보를 등록, 사용자들이 실제 자산을 예치하도록 유도 후 탈취

#### 가이드라인

> * **배포 권한 제어:**
>   * **Factory 배포 권한을 멀티시그에 한정**
>   * **새로운 담보 추가 시 72시간 타임락 적용**
>   * **담보별 최대 부채 한도 설정 및 점진적 증가**
> * **코드 검증 시스템:**
>   * **새로운 DenManager 배포 전 코드 감사 필수**
>   * **표준 구현체에서 벗어난 수정 사항 공개 검토**
>   * **담보 토큰의 컨트랙트 코드 및 오라클 검증**

#### Best Practice

[`BorrowerOperations.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Beraborrow/src/core/BorrowerOperations.sol)

```solidity
function configureCollateral(IDenManager denManager, IERC20 collateralToken) external {
    require(msg.sender == factory, "!factory");
    denManagersData[denManager] = DenManagerData(collateralToken, uint16(denManagers.length));
    denManagers.push(denManager);
    emit CollateralConfigured(denManager, collateralToken);
}

function removeDenManager(IDenManager denManager) external {
    require(
        denManager.sunsetting() && denManager.getEntireSystemDebt() == 0,
        "Den Manager cannot be removed");
}
```

***

### 위협 11: Owner 권한 남용을 통한 프로토콜 파라미터 악의적 변경

#### 가이드라인

> * **거버넌스 권한 분산:**
>   * **모든 중요 파라미터 변경에 멀티시그 + 타임락 적용**
>   * **긴급 상황 외 paused 상태 변경 금지**
>   * **가격 피드 변경 시 48시간 공지 기간 필수**
> * **파라미터 변경 제한:**
>   * **MCR, CCR 변경 시 최대 10% 증감 제한**
>   * **수수료 변경 시 월 1회 제한**
>   * **시스템 주소 변경 시 커뮤니티 투표 필수**&#x20;

#### Best Practice

[`DenManager.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Beraborrow/src/core/DenManager.sol)

```solidity
require((_paused && msg.sender == guardian()) || msg.sender == owner(), "Unauthorized");
```

***

### 위협 12: 대량 인출을 통한 Stability Pool 고갈로 청산 메커니즘 마비

대량 청산 시 LSP의 NECT 잔고가 부족하여 청산이 불가능해지고, Recovery Mode 진입으로 시스템 마비

#### 가이드라인

> * **유동성 보호 메커니즘:**
>   * **24시간 내 최대 인출 한도 설정 (예: 풀 크기의 30%)**
>   * **대량 인출 시 점진적 수수료 증가 (예: 0.1% → 1%)**
>   * **풀 크기가 임계값 이하 시 새로운 차용 제한**
> * **인센티브 분배:**
>   * **청산 시 추가 보너스 토큰 배분**
>   * **장기 예치자에게 수수료 할인 혜택 제공**

***

### 위협 13: 대량 청산이 담보 가격 하락을 유발하여 추가 청산을 촉발하는 악순환

#### 가이드라인

> * **연쇄반응 방지 메커니즘:**
>   * **시간대별 청산 한도 설정**
>   * **Recovery Mode에서 추가 청산 제한 강화**
> * **Dynamic Risk Parameters:**
>   * **변동성 증가 시 MCR 자동 상향 조정 메커니즘**
>   * **시장 스트레스 지수 기반 청산 지연 시스템**
>   * **대량 청산 감지 시 새로운 차용 일시 중단**

#### Best practice

[`DenManager.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Beraborrow/src/core/DenManager.sol)

```solidity
function startSunset() external onlyOwner {
    sunsetting = true;
    _accrueActiveInterests();
    interestRate = SUNSETTING_INTEREST_RATE;
    lastActiveIndexUpdate = block.timestamp;
    redemptionFeeFloor = 0;
    maxSystemDebt = 0;
    baseRate = 0;
    maxRedemptionFee = 0;
}
```

***

### 위협 14: 고정 이자율 모델의 한계

시장 상황과 무관한 고정 이자율로 인한 자본 효율성 저하 및 리스크 부적절한 반영

#### 가이드라인

> * **Dynamic Interest Rate 도입:**
>   * **이용률 기반 이자율 모델 구현 (Compound/Aave 스타일)**
>   * **담보별 리스크 프리미엄 차등 적용**
>   * **시장 변동성에 따른 이자율 동적 조정**
> * **Interest Rate 거버넌스:**
>   * **이자율 변경 시 타임락 적용**
>   * **이자율 변경폭 제한**&#x20;
>   * **커뮤니티 투표를 통한 이자율 모델 파라미터 결정**

***

### 위협 15: 다중 담보 상관관계 위협

여러 담보 자산 간 높은 상관관계로 인한 동시 가격 하락 시 시스템 위험 증폭

#### 가이드라인

> * **포트폴리오 위험 관리:**
>   * **단일 담보 집중도 한도 설정**
>   * **상관관계 높은 자산군별 통합 위험 한도 적용**

#### Best Practice

[`DenManager.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Beraborrow/src/core/DenManager.sol)

```solidity
uint256 _newTotalDebt = totalActiveDebt + _compositeDebt;
require(_newTotalDebt + defaultedDebt <= maxSystemDebt, "Collateral debt limit reached");
totalActiveDebt = _newTotalDebt;
```

***

### 위협 16: Recovery Mode 상태 판단 및 전환 메커니즘의 불완전성

TCR이 CCR 이하 진입했으나 BorrowerOperations의 checkRecoveryMode() 로직 버그로 정상 모드 유지, 추가 차용 허용으로 손실 확대

#### 가이드라인

> * **Recovery Mode 개선:**
>   * **Recovery Mode 진입 시 자동 MCR 상향 조정**&#x20;
>   * **시장 안정화까지 새로운 차용 완전 차단**
>   * **Recovery Mode 지속 시간에 따른 단계적 대응 강화**
> * **Mode Transition 안정성:**
>   * **TCR 계산 시 최신 가격 및 이자 반영 보장**
>   * **Mode 전환 시 모든 포지션 상태 일괄 업데이트**
>   * **Recovery Mode 탈출 후 24시간 모니터링 기간 설정**

#### Best Practice

[`BorrowerOperations.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Beraborrow/src/core/BorrowerOperations.sol)

```solidity
function checkRecoveryMode(uint256 TCR) public view returns (bool) {
    return TCR < BERABORROW_CORE.CCR();
}
```
