---
icon: plane-arrival
---

# dApp 보안 가이드라인: Lending



<table><thead><tr><th width="582.4453125">위협</th><th width="215.7291259765625" align="center">영향도</th></tr></thead><tbody><tr><td><a data-mention href="lending.md#id-1">#id-1</a></td><td align="center"><code>Medium</code></td></tr><tr><td><a data-mention href="lending.md#id-2-erc-4626">#id-2-erc-4626</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="lending.md#id-3-recovery-mode">#id-3-recovery-mode</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="lending.md#id-4-owner">#id-4-owner</a></td><td align="center"><code>Low</code></td></tr></tbody></table>

### 위협 1: 대량 청산이 담보 가격 하락을 유발하여 추가 청산을 촉발하는 악순환

대규모 청산이 담보 자산의 급격한 가격 하락을 유발하고, 이는 다시 더 많은 포지션의 청산을 촉발하는 연쇄 반응을 일으킨다. 이 악순환은 사용자들의 담보 자산 손실 및 프로토콜의 부실 채권을 생성한다.&#x20;

#### 영향도&#x20;

`Medium`

사용자에게 과도한 담보 손실을 강요하고, 심각할 경우 프로토콜에 회수 불가능한 부실 채권을 남겨 시스템의 지급 불능을 초래할 수 있다. 발생 확률이 시장 상황에 따라 존재하며 과거 사례를 통해 피해가 치명적일 수 있어(레퍼런스 추가) `Medium`로 평가한다.

#### 가이드라인

> *   **연쇄반응 방지 메커니즘**
>
>     *   Recovery Mode에서 담보 상환 제한
>
>
>
>         ```solidity
>         function _requireValidAdjustmentInCurrentMode(...) {...
>              // recoveryMode에서 담보 상환 불가
>              if (_isRecoveryMode) {
>                 require(_collWithdrawal == 0, "BorrowerOps: Collateral withdrawal not permitted Recovery Mode");
>                 if (_isDebtIncrease) {
>                     _requireICRisAboveCCR(newICR);
>                     _requireNewICRisAboveOldICR(newICR, oldICR);
>                 }
>                 ...
>         }
>                     
>         // recoveryMode에서 대출 포지션 닫기 불가            
>         function closeDen(...) {
>         ...
>         require(!isRecoveryMode, "BorrowerOps: Operation not permitted during Recovery Mode");
>         }
>         ```
>
>
> * **Dynamic Risk Parameters**
>   *   recoveryMode 시 청산 기준 하향 조정 메커니즘
>
>
>
>       ```solidity
>       function liquidateDens(..) {
>
>       // 일반 모드일 경우
>       if (ICR <= _LSP_CR_LIMIT) {
>           singleLiquidation = _liquidateWithoutSP(denManager, account);
>           _applyLiquidationValuesToTotals(totals, singleLiquidation);
>       } else if (ICR < applicableMCR) {
>           singleLiquidation = _liquidateNormalMode(
>               denManager,
>               account,
>               debtInStabPool,
>               denManagerValues.sunsetting
>           );
>           debtInStabPool -= singleLiquidation.debtToOffset;
>           _applyLiquidationValuesToTotals(totals, singleLiquidation);
>       } else break; // break if the loop reaches a Den with ICR >= MCR
>
>       // recoverMode일 경우 
>       // recoverMode 체크 (CCR > TCR) && 청산 대상인지 체크 (ICR < TCR)
>
>       {
>           uint256 TCR = BeraborrowMath._computeCR(entireSystemColl, entireSystemDebt);
>           if (TCR >= borrowerOperations.BERABORROW_CORE().CCR() || ICR >= TCR)
>               break;
>       }
>
>       // 현재 recoverMode가 켜져 있고 해당 Den의 ICR이 TCR 보다 작으면 청산 진행
>       singleLiquidation = _tryLiquidateWithCap(
>           denManager,
>           account,
>           debtInStabPool,
>           _getApplicableMCR(account, denManagerValues),
>           denManagerValues.price
>       );
>       ```

#### **Best practice**

[**`LiquidationManager.sol`**](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Beraborrow/src/core/LiquidationManager.sol#L331-L368)

[**`BorrowOperations.sol`**](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Beraborrow/src/core/BorrowerOperations.sol#L413-L423)

***



### 위협 2: [ERC-4626 인플레이션](../../undefined.md#id-34-erc-4626-virtual-shares-9-decimal-offset-69-share) 공격

공격자는 ERC-4626 볼트의 총 공급량이 거의 없을 때 아주 적은 지분을 예치한 후, 자산을 볼트에 직접 전송하여 자신의 지분 가치를 부풀린다. 이후 예치하는 사용자들은 부풀려진 지분 가격 때문에 훨씬 적은 지분을 받게 되어, 사실상 공격자에게 자신의 자산을 빼앗기는 손해를 입게 된다.

#### 영향도&#x20;

`Low`

발생한다면 큰 영향을 끼치지만 LSP에 공급량이 없는 경우와 공격자가 지분 가치를 부풀리고 이후 사용자가 토큰을 예치하는 경우는 가능성이 낮으므로 `Low` 로 평가한다.

#### 가이드라인

> * **Virtual Shares 메커니즘 구현**
>   * 초기 배포 시 가상 지분 및 자산 설정
>   * [OpenZeppelin의 decimal offset 9자리 적용](https://github.com/OpenZeppelin/openzeppelin-contracts/pull/3979)
>   * 최소 예치금 임계값으로 $NECT 처럼 69개 이상 share 받도록 강제 설정([오픈제플린 권장사항](https://docs.openzeppelin.com/contracts/5.x/erc4626): 최소 100개 이상의 share)&#x20;
> *   **부트스트랩 기간 보호 강화**
>
>     * `deposit()`,`mint()`함수에도 `whenNotBootstrapPeriod` 적용
>     * `totalSupply ≈ 0` 상태 감지 및 자동 보호 모드 활성화
>
>     레퍼런스 - [https://blog.openzeppelin.com/a-novel-defense-against-erc4626-inflation-attacks](https://blog.openzeppelin.com/a-novel-defense-against-erc4626-inflation-attacks)

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

### 위협 3: Recovery Mode 상태 판단 및 전환 메커니즘의 불완전성

Recovery Mode 진입 판단이나 전환 로직의 오류는 시스템이 실제로는 위험한 상태임에도 정상 작동하는 것처럼 보이게 만들어, 추가적인 부실 대출을 허용하고 손실을 확대시킨다.

공격자가 담보 비율(ICR/TCR) 검증 로직을 우회하여 시스템이 [Recovery Mode](../../undefined.md#id-35-recovery-mode-tcr-less-than-ccr-icr-tcr)임에도 과도하게 대출을 하면, 해당 대출은 부실화될 위험이 매우 커진다.

#### 영향도&#x20;

`Low`

Recovery Mode 전환 로직의 실패는 부실 대출을 유발하여 프로토콜에 잠재적 손실을 끼칠 수 있다. 하지만 담보 인출 금지 및 다중 담보 비율(ICR/TCR) 검증과 같은 강력한 보호 장치들이 이미 중첩되어 있으므로 실제 공격이 성공할 확률이 낮아`Low`로 평가한다.

#### 가이드라인

> * **모든 포지션 변경 시 개별 ICR(개별 담보 비율)과 시스템 TCR(총 담보율) 동시 검증**
> * **Mode Transition 안정성**
>   * TCR 계산 시 최신 가격 및 이자 반영 보장
>   * Mode 전환 시 모든 포지션 상태 일괄 업데이트

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

### 위협 4: Owner 권한 남용으로 인한 시스템 무결성 침해

Owner가 권한을 남용하여 프로토콜의 중요 파라미터를 악의적으로 변경하면, 사용자들은 예기치 않은 과도한 수수료 지불 및 자산 청산 위험 증가 등 직접적인 경제적 손실을 입게 된다.

#### 영향도&#x20;

`Low`

Owner의 악의적인 파라미터 변경은 사용자에게 직접적인 자금 손실을 입힐 수 있는 심각한 위협이다. 과거 DeFi 사례에서 보듯, 이는 기술적 취약점뿐만 아니라 신뢰를 받던 핵심 그룹이 돌아서는 '거버넌스 리스크'를 포함한다. 그러나 이러한 권한은 다중 서명과 Timelock로 통제되므로, 실제 성공 가능성은 낮아 `Low`로 평가한다.

#### 가이드라인

> * **거버넌스 권한 분산**
>   * 모든 중요 파라미터 변경에 [멀티시그 + 타임락 적용](../../undefined.md#id-37-owner--mcr-ccr-7)
>   * 긴급 상황 외 paused 상태 변경 금지
>   * 가격 피드 변경 시 공지
> * **파라미터 변경 제한**
>   * MCR, CCR 변경 시 증감 최대치 제한
>   * 수수료 변경 시 월 변경 횟수 제한
>   * 시스템 주소 변경 시 커뮤니티 투표 필수&#x20;
> * **이자율 거버넌스 보호**
>   * 이자율 변경 시 7일 타임락 적용
>   * 이자율 변경폭 제한
>   * 이자율 변경 시 커뮤니티 투표 필수
> * **이자 계산 투명성**
>   * 모든 이자 계산을 체인상에서 검증 가능하도록 공개
>   * 이자 누적 로직의 오버플로우 방지
>   * 이자율 변경 이력 추적 및 감사 가능성 확보

#### Best Practice

[`DenManager.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Beraborrow/src/core/DenManager.sol#L254-L257)

```solidity
require((_paused && msg.sender == guardian()) || msg.sender == owner(), "Unauthorized");
```

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
