---
icon: plane-arrival
---

# dApp: Lending 보안 가이드라인

<table><thead><tr><th width="570.18359375">위협</th><th align="center">영향도</th></tr></thead><tbody><tr><td><a data-mention href="lending.md#id-1">#id-1</a></td><td align="center"></td></tr><tr><td><a data-mention href="lending.md#id-2-erc-4626">#id-2-erc-4626</a></td><td align="center"></td></tr><tr><td><a data-mention href="lending.md#id-3">#id-3</a></td><td align="center"></td></tr><tr><td><a data-mention href="lending.md#id-4-icr-tcr">#id-4-icr-tcr</a></td><td align="center"></td></tr><tr><td><a data-mention href="lending.md#id-5">#id-5</a></td><td align="center"></td></tr><tr><td><a data-mention href="lending.md#id-6-redeemcollateral">#id-6-redeemcollateral</a></td><td align="center"></td></tr><tr><td><a data-mention href="lending.md#id-7-denmanager">#id-7-denmanager</a></td><td align="center"></td></tr><tr><td><a data-mention href="lending.md#id-8-owner">#id-8-owner</a></td><td align="center"></td></tr><tr><td><a data-mention href="lending.md#id-9">#id-9</a></td><td align="center"></td></tr><tr><td><a data-mention href="lending.md#id-10-recovery-mode">#id-10-recovery-mode</a></td><td align="center"></td></tr></tbody></table>

### 위협 1: 담보 평가 및 가격 결정 메커니즘의 취약점

유동성이 낮은 토큰을 담보로 등록될 경우, 공격자가 소형 DEX에서 토큰 가격을 플래시론으로 조작하여 PriceFeed를 속이고 저평가된 담보로 과도한 NECT 차용

#### 가이드라인

> * **각 담보 자산(iBGT, iBERA, LP 토큰 등)의 유동성, 변동성, 오라클 신뢰도를 개별적으로 평가하고, 이에 따른 LTV(담보인정비율), 청산 임계값, 청산 패널티 등을 차등 설정**
> * **최소 2개 이상의 독립적인 가격 소스 사용**
> * **가격 편차 임계값 설정**&#x20;
> * **TWAP 적용**&#x20;
> * **급격한 가격 하락 시 청산 지연 메커니즘 적용**

#### Best Practice

[`DenManager.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Beraborrow/src/core/DenManager.sol#L302-L336)

```solidity
// MCR 설정등 각 담보에 따라 차등 설정

function setParameters(IFactory.DeploymentParams calldata params) public  {
    require(!sunsetting, "Cannot change after sunset");
    require(params.MCR <= BERABORROW_CORE.CCR() && params.MCR >= 1.1e18, 
            "MCR cannot be > CCR or < 110%");
 //...
    MCR = params.MCR;
}
```

***

### 위협 2: ERC-4626 인플레이션 공격

LSP의 totalSupply **≈** 0 상태에서 1wei 예치 후 NECT를 직접 전송하여 후속 예치자 지분 탈취

#### 가이드라인

> * **Virtual Shares 메커니즘 구현:**
>   * **초기 배포 시 최소 1000 wei의 가상 지분 및 자산 설정**
>   * **OpenZeppelin의 decimal offset 적용 (최소 6자리)**
>   * **최소 예치금 임계값 설정**&#x20;
> * **부트스트랩 기간 보호 강화:**
>   * **`deposit()`,`mint()`함수에도 `whenNotBootstrapPeriod` 적용**
>   * **`totalSupply ≈ 0` 상태 감지 및 자동 보호 모드 활성화**

#### Best Practice

`커스텀 코드`

```solidity
// totalSupply가 0이 되는 것을 방지.

constructor(address _assetToken) {
    if (_assetToken == address(0)) {
        revert("Zero address provided for asset token");
    }
    asset = IERC20(_assetToken);

    // 이 지분은 실질적으로 소각된 것과 같지만, totalSupply 계산에는 포함됨.
    totalSupply = LOCKED_SHARES;
    balanceOf[address(0)] = LOCKED_SHARES;
    ...
}

function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
// 가이드라인: 최소 예치금 임계값 설정 & 부트스트랩 기간 보호 강화
if (block.timestamp < bootstrapEndTime) {
    // 부트스트랩 기간: 더 엄격한 최소 예치금 적용
    require(assets >= MIN_DEPOSIT_BOOTSTRAP, "Deposit amount below bootstrap period minimum");
} else {
    // 일반 기간: 일반 최소 예치금 적용
    require(assets >= MIN_DEPOSIT_NORMAL, "Deposit amount below normal minimum");
}
```

***

### 위협 3: 플래시론 재진입 공격

공격자가 플래시론 실행 중  콜백을 이용해 동일 트랜잭션에서 담보 인출과 추가 차용을 동시 실행

#### 가이드라인

> * **CEI 패턴 엄격 적용**
> * **플래시론 실행 중 모든 상태 변경 함수 접근 차단**
> * **플래시론 한도를 총 공급량의 50%로 제한**
> * **플래시론 수수료 최소 0.05% 설정**

#### Best Practice

[`DebtToken.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Beraborrow/src/core/DebtToken.sol#L179-L182)

```solidity
function flashFee(address token, uint256 amount) public view returns (uint256) {
        require(token == address(this), "ERC20FlashMint: wrong token");
        return _flashFee(amount);
}
```

***

### 위협 4: ICR/TCR 검증 우회를 통한 과도한 차용

공격자가 DenManager의 `adjustDen()`함수에서 Recovery Mode 조건 검증 로직을 우회하여 MCR 미달에서도 추가 NECT 차용

#### 가이드라인

> * **담보 비율 검증 강화**
>   * **모든 포지션 변경 시 개별 ICR과 시스템 TCR 동시 검증**
>   * **Recovery Mode 진입 시 새로운 차용 완전 차단**
>   * **담보 인출 시 최소 ICR 설정**
> * **시간 기반 제한**
>   * **포지션 조정 후 24시간 내 재조정 제한**
>   * **대량 담보 인출 시 48시간 타임락 적용**
>   * **급격한 담보 비율 변화 시 추가 검증 요구**

#### Best Practice

[`BeraborrowOperation.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Beraborrow/src/core/BorrowerOperations.sol#L511-L530)

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

### 위협 5: 이자율 조작을 통한 부당한 이자 부과

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

[`DenManager.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Beraborrow/src/core/DenManager.sol#L326-L336)

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

### 위협 6: redeemCollateral()을 통한 선택적 상환으로 건전한 포지션 타겟팅

공격자가 `redeemCollateral()`로 높은 ICR을 가진 Den만 선별하여 상환, 해당 사용자의 담보를 시장가 이하로 획득

#### 가이드라인

> * **상환 공정성 보장:**
>   * **상환 시 최저 ICR 포지션부터 강제 순서 적용**
>   * **상환 수수료 최소 0.5% 설정 및 동적 조정**
>   * **대량 상환 시 일일 한도 적용**
> * **상환 baseRate 보호:**
>   * **baseRate 급등 방지를 위한 점진적 증가 메커니즘**
>   * **상환 후 7일간 추가 상환 제한**
>   * **상환 수수료 수익을 Stability Pool에 배분하여 인센티브 정렬**

#### Best Practice

[`DenManager.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Beraborrow/src/core/DenManager.sol#L487-L508)

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

### 위협 7: 악의적인 DenManager 배포를 통한 시스템 무결성 침해

공격자가 Factory를 통해 가짜 DenManager 배포 후 가짜 담보를 등록, 사용자들이 실제 자산을 예치하도록 유도 후 탈취

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

[`BorrowerOperations.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Beraborrow/src/core/BorrowerOperations.sol#L123-L128)

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

### 위협 8: Owner 권한 남용을 통한 프로토콜 파라미터 악의적 변경

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

[`DenManager.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Beraborrow/src/core/DenManager.sol#L254-L257)

```solidity
require((_paused && msg.sender == guardian()) || msg.sender == owner(), "Unauthorized");
```

***

### 위협 9: 대량 청산이 담보 가격 하락을 유발하여 추가 청산을 촉발하는 악순환

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

### 위협 10: Recovery Mode 상태 판단 및 전환 메커니즘의 불완전성

TCR이 CCR 이하 진입했으나 BorrowerOperations의 `checkRecoveryMode()` 로직 버그로 정상 모드 유지, 추가 차용 허용으로 손실 확대

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

[`BorrowerOperations.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Beraborrow/src/core/BorrowerOperations.sol#L182-L184)

```solidity
// 현재 TCR 체크 
function checkRecoveryMode(uint256 TCR) public view returns (bool) {
    return TCR < BERABORROW_CORE.CCR();
}

// 보호모드에 따라 다른 기준 적용
if (isRecoveryMode) {
    _requireICRisAboveCCR(vars.ICR);
} else {
    _requireICRisAboveMCR(vars.ICR, denManager.MCR(), account);
    uint256 newTCR = _getNewTCRFromDenChange(
        vars.totalPricedCollateral,
        vars.totalDebt,
        _collateralAmount * vars.price,
        true,
        vars.compositeDebt,
        true
    ); // bools: coll increase, debt increase
    _requireNewTCRisAboveCCR(newTCR);
}
```
