---
icon: plane-arrival
---

# dApp 보안 가이드라인: Lending



<table><thead><tr><th width="582.4453125">위협</th><th width="215.7291259765625" align="center">영향도</th></tr></thead><tbody><tr><td><a data-mention href="lending.md#id-1">#id-1</a></td><td align="center"><code>Informational</code></td></tr><tr><td><a data-mention href="lending.md#id-2-erc-4626">#id-2-erc-4626</a></td><td align="center"><code>Informational</code></td></tr><tr><td><a data-mention href="lending.md#id-3">#id-3</a></td><td align="center"><code>Informational</code></td></tr><tr><td><a data-mention href="lending.md#id-4-recovery-mode">#id-4-recovery-mode</a></td><td align="center"><code>Informational</code></td></tr><tr><td><a data-mention href="lending.md#id-5-owner">#id-5-owner</a></td><td align="center"><code>Informational</code></td></tr><tr><td><a data-mention href="lending.md#id-6">#id-6</a></td><td align="center"><code>Informational</code></td></tr><tr><td><a data-mention href="lending.md#id-7">#id-7</a></td><td align="center"><code>Informational</code></td></tr></tbody></table>

### 위협 1: 담보 평가 및 가격 결정 메커니즘의 취약점

유동성이 낮은 토큰이 담보로 등록될 경우 공격자가 소형 DEX에서 토큰 가격을 플래시론으로 조작하여 PriceFeed를 속이고 고평가된 담보로 과도한 NECT를 차용한다. 다시 가격이 복구되어 청산 되어도 담보에 비해 많은 금액을 대출 하여 프로토콜에 손해를 입힌다.

#### 영향도&#x20;

`Informational`

공격자는 충분한 유동성을 가지고 거버넌스에 의해 승인될 만한 담보의 오라클을 조작해야 하는데 이는 매우 어렵고 비용이 많이 들기에 `Informational`로 평가했다.

#### 가이드라인

> * **각 담보 자산(iBGT, iBERA, 특정 Kodiak/BEX LP 토큰 등)의 위험 프로파일을 개별적으로 평가하고, 이에 따라 LTV(담보인정비율), MCR(최소담보비율), 청산 패널티 등을 차등 설정한다. 위험 프로파일 평가는 다음 지표들을 포함한다.**

1. **유동성 평가:**

* **판정 지표:**
  * **온체인 DEX 유동성 깊이: 해당 토큰과 주요 페어(HONEY, USDC, WETH)의 DEX 풀에 예치된 총 가치 (TVL) 및 슬리피지.**&#x20;
    * **BeraBorrow의 DenManager.sol 자체에는 직접적인 유동성 측정 로직이 없으나, 새로운 담보 추가 시 Factory.sol의 deployNewInstance를 통해 설정되는 파라미터들이 이 평가를 기반으로 해야 한다.**
  * **24시간 거래량: 해당 토큰의 온체인 DEX 거래량**
* **기준: 각 지표에 대해 최소 임계값을 설정하고, 미달 시 '저유동성 토큰'으로 분류하여 LTV 하향 조정 및 MCR 상향 조정.**\


2. **변동성 산정:**

* **산정 방식:**
  * **기간: 최소 지난 30일 이상의 가격 데이터 사용.**
  * **지표: 해당 기간 동안 일별 종가 기준 로그 수익률의 표준편차(Historical Volatility)를 계산.**
  * **Volatility = σ = sqrt( (1/N) \* Σ( (R\_i - R\_avg)^2 ) )**
    * **N: 기간 내 관찰 횟수**
    * **R\_i​: i 시점의 로그 수익률 (ln(Pi/Pi−1)ln(Pi​/Pi−1​))**
    * **R\_avg​: 평균 로그 수익률**
* **활용: 계산된 변동성을 기준으로 등급을 나누고(낮음, 중간, 높음, 매우 높음), 등급에 따라 LTV 및 청산 관련 파라미터를 차등 적용.**\


3. **N개 오라클 가격 피드 사용 및 통합:**

* **최소 요건: 각 담보에 대해 최소 2개, 권장 3개 이상의 독립적인 가격 소스를 사용한다.**&#x20;
* **통합 방식:**
  * **중간값 방식: N개의 오라클로부터 가격을 받아 정렬 후 중간값을 최종 가격으로 사용. 이는 극단적인 가격을 제시하는 단일 오라클의 영향을 제거한다.**
  * **가중 평균 방식: 각 오라클의 신뢰도, 업데이트 빈도 등을 고려하여 가중치를 부여하고 가중 평균을 사용할 수 있으나, 가중치 설정의 객관성 확보가 중요하다.**



4. **가격 편차 검증 및 대응:**

* **편차 검증 대상:**
  * **오라클 간 편차: 위 3번에서 사용되는 N개의 오라클 가격들 간의 상호 편차.**
  * **오라클 가격과 TWAP 가격 간 편차: 실시간 오라클 가격과 특정 기간(예: 30분, 1시간)의 TWAP 간의 편차.**
* **가격 편차 수식 (예시: 오라클 중앙값과 개별 오라클 간):**
  * **PmedianPmedian​: N개 오라클 가격의 중간값**
  * **PoracleiPoraclei​​: i번째 개별 오라클 가격**
  * **Deviation\_i = |P\_median - P\_oracle\_i| / P\_median \* 100%**
* **임계값 및 대응:**
  * **임계값 설정: Deviation\_i > 5% (또는 오라클-TWAP 편차 > 10%)**
  * **대응 조치:**
    * **경고 및 로깅: 편차가 임계값을 초과하면 시스템에 즉시 경고를 발생시키고 관련 데이터를 로깅한다.**
    * **일시적 운영 중단 (Circuit Breaker): 해당 담보를 사용한 신규 대출 및 청산 실행을 일시적으로 중단한다.**
      * **BeraBorrow DenManager.sol의 setPaused(bool \_paused) 와 유사한 기능을 담보별로 두거나, BeraborrowCore.sol의 setNewCCR 호출과 연계하여 해당 담보의 CCR을 일시적으로 매우 높게 설정하여 사실상 중단시키는 방안 고려.**
    * **보수적 가격 사용: 편차가 발생한 오라클을 제외하고 가격을 다시 계산한다.**
    * **TWAP 의존도 증가: 실시간 가격 대신 TWAP 가격을 일시적으로 사용하거나, TWAP 반영 비중을 높인다.**
    * **거버넌스 개입: 심각한 편차 발생 시, 거버넌스를 통해 해당 오라클을 교체하거나 문제를 해결할 때까지 담보 자격을 정지시킨다.**



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

공격자는 ERC-4626 볼트의 총 공급량이 거의 없을 때 아주 적은 지분을 예치한 후, 자산을 볼트에 직접 전송하여 자신의 지분 가치를 부풀린다. 이후 예치하는 사용자들은 부풀려진 지분 가격 때문에 훨씬 적은 지분을 받게 되어, 사실상 공격자에게 자신의 자산을 빼앗기는 손해를 입게 된다.

#### 영향도&#x20;

`Informational`

발생한다면 큰 영향을 끼치지만 LSP에 공급량이 없는 경우와 공격자가 지분 가치를 부풀리고 이후 사용자가 토큰을 예치하는 경우는 가능성이 매우 낮으므로 `Informational` 로 평가했다.

#### 가이드라인

> * **Virtual Shares 메커니즘 구현:**
>   * **초기 배포 시 가상 지분 및 자산 설정**
>   * [**OpenZeppelin의 decimal offset 9자리 적용**](https://github.com/OpenZeppelin/openzeppelin-contracts/pull/3979)
>   * **최소 예치금 임계값으로 $NECT 처럼 69개 이상 share 받도록 강제 설정(**[**오픈제플린 권장사항**](https://docs.openzeppelin.com/contracts/5.x/erc4626)**: 최소 100개 이상의 share)**&#x20;
> * **부트스트랩 기간 보호 강화:**
>   * **`deposit()`,`mint()`함수에도 `whenNotBootstrapPeriod` 적용**
>   * **`totalSupply ≈ 0` 상태 감지 및 자동 보호 모드 활성화**

#### Best Practice

#### [`LiquidStabilityPool.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Beraborrow/src/core/LiquidStabilityPool.sol#L131-L134)&#x20;

```solidity
modifier whenNotBootstrapPeriod() {
        _whenNotBootstrapPeriod();
        _;
    }
```

[`LiquidStabilityPool.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Beraborrow/src/core/LiquidStabilityPool.sol#L136-L149)

```solidity
function _whenNotBootstrapPeriod() internal view {
    // BoycoVaults should be able to unwind in the case ICR closes MCR
    ILiquidStabilityPool.LSPStorage storage $ = _getLSPStorage();
        
    if (
        block.timestamp < $.metaBeraborrowCore.lspBootstrapPeriod()
        && !$.boycoVault[msg.sender]
    ) revert BootstrapPeriod();
}
```

[`BaseCollateralVault.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Beraborrow/src/core/vaults/BaseCollateralVault.sol#L101C4-L103C6)

```solidity
function _decimalsOffset() internal view override virtual returns (uint8) {
        return 18 - assetDecimals();
    }
```

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

플래시론 재진입 공격은 공격자가 대출금 상환 전에 콜백 함수를 통해 프로토콜에 다시 접근하여 담보물을 부당하게 인출하거나 추가 대출을 실행한다. 이는 결국 프로토콜에 상환되지 않는 부실 채권을 남기거나 담보 자산을 탈취당하게 만들어 직접적인 자금 손실을 야기한다.

#### 영향도&#x20;

`Informational`

ㅇ

#### 가이드라인

> * **CEI 패턴 엄격 적용**
> * **플래시론 실행 중 모든 상태 변경 함수 접근 차단**
> * **플래시론 한도 설정**
> * **플래시론 수수료 설정**

#### Best Practice

[`DebtToken.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Beraborrow/src/core/DebtToken.sol#L179-L182)

```solidity
function flashFee(address token, uint256 amount) public view returns (uint256) {
        require(token == address(this), "ERC20FlashMint: wrong token");
        return _flashFee(amount);
}
```

***

### 위협 4: Recovery Mode 상태 판단 및 전환 메커니즘의 불완전성

Recovery Mode 진입 판단이나 전환 로직의 오류는 시스템이 실제로는 위험한 상태임에도 정상 작동하는 것처럼 보이게 만들어, 추가적인 부실 대출을 허용하고 손실을 확대시킨다.

공격자가 담보 비율(ICR/TCR) 검증 로직을 우회하여 시스템이 Recovery Mode임에도 과도하게 NECT를 차용하면, 해당 대출은 부실화될 위험이 매우 커진다.

#### 영향도&#x20;

`Informational`

Recovery Mode에서는 담보 인출 금지 및 부채 증가 시 엄격한 담보비율 검증으로 인해 공격의 가능성이 낮으므로 `Informational`로 평가했다.

#### 가이드라인

> * **모든 포지션 변경 시 개별 ICR(개별 담보 비율)과 시스템 TCR(총 담보율) 동시 검증**
> * **Recovery Mode 개선:**
>   * **Recovery Mode 진입 시 자동 MCR 상향 조정**&#x20;
>   * **Recovery Mode 진입 시 담보 인출 차단**
> * **Mode Transition 안정성:**
>   * **TCR 계산 시 최신 가격 및 이자 반영 보장**
>   * **Mode 전환 시 모든 포지션 상태 일괄 업데이트**

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

[`BeraborrowOperations.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Beraborrow/src/core/BorrowerOperations.sol#L511-L530)

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

### 위협 5: Owner 권한 남용으로 인한 시스템 무결성 침해

Owner가 권한을 남용하여 프로토콜의 중요 파라미터를 악의적으로 변경하면, 사용자들은 예기치 않은 과도한 수수료 지불 및 자산 청산 위험 증가 등 직접적인 경제적 손실을 입게 된다.

#### 영향도&#x20;

`Informational`

Owner의 악의적인 행동은 가능성이 낮기 때문에`Informational`로 평가했다.

#### 가이드라인

> * **거버넌스 권한 분산:**
>   * **모든 중요 파라미터 변경에 멀티시그 + 타임락 적용**
>   * **긴급 상황 외 paused 상태 변경 금지**
>   * **가격 피드 변경 시 공지**
> * **파라미터 변경 제한:**
>   * **MCR, CCR 변경 시 증감 최대치 제한**
>   * **수수료 변경 시 월 변경 횟수 제한**
>   * **시스템 주소 변경 시 커뮤니티 투표 필수**&#x20;

#### Best Practice

[`DenManager.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Beraborrow/src/core/DenManager.sol#L254-L257)

```solidity
require((_paused && msg.sender == guardian()) || msg.sender == owner(), "Unauthorized");
```

***

### 위협 6: 이자율 조작을 통한 부당한 이자 부과

공격자 또는 악의적인 거버넌스가 이자율을 부당하게 조작하면, 차용자는 과도한 이자를 지불하게 되어 직접적인 경제적 손실을 입거나, 예치자는 기대했던 수익을 얻지 못하게 된다.

#### 영향도&#x20;

`Informational`

이자율을 수정하는 것은 owner만 호출 가능하기 때문에`Informational`로 평가했다.

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

### 위협 7: 대량 청산이 담보 가격 하락을 유발하여 추가 청산을 촉발하는 악순환

대규모 청산이 담보 자산의 급격한 가격 하락을 유발하고, 이는 다시 더 많은 포지션의 청산을 촉발하는 연쇄 반응을 일으킨다. 이 악순환은 사용자들에게 과도한 슬리피지로 인한 자산 손실을 강요한다.&#x20;

#### 영향도&#x20;

`Informational`

개별 담보비율 기준 순차 청산 및 위험 담보 점진적 감소 메커니즘으로 대량 청산 완화 로직이 구현되어 있으며, 이는 정상적인 시스템의 동작이기 때문에`Informational`로 평가했다.

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

