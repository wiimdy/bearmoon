---
description: >-
  여러 dApp의 기능을 연쇄적으로 조합하여 사용하는 복합 DeFi 전략은 고수익 기회를 제공한다.  하지만 이러한 dApp 체이닝은 개별
  dApp 사용 시에는 드러나지 않았던 새로운 상호작용 위험을 발생시키고 기존 위험을 증폭시킬 수 있다.
icon: link
layout:
  title:
    visible: true
  description:
    visible: true
  tableOfContents:
    visible: true
  outline:
    visible: true
  pagination:
    visible: true
---

# dApp 체이닝 보안 가이드라인

<table><thead><tr><th width="616.01953125">위협</th><th align="center">영향도</th></tr></thead><tbody><tr><td><a data-mention href="chaining.md#id-1-dex-lp">#id-1-dex-lp</a></td><td align="center"></td></tr><tr><td><a data-mention href="chaining.md#id-2-honey">#id-2-honey</a></td><td align="center"></td></tr><tr><td><a data-mention href="chaining.md#id-3">#id-3</a></td><td align="center"></td></tr></tbody></table>

### 위협 1: DEX 풀 불균형으로 LP 토큰 담보가치 급락 시 대출 대량 청산, 이로 인한 Beraborrow LSP ERC 4626 인플레이션 공격 취약점&#x20;

### 배경: 베라체인 생태계의 복합적 취약점

베라버로우는 베라체인의 Proof-of-Liquidity(PoL) 메커니즘과 긴밀하게 통합되어 있으며, 특히 Infrared Finance의 iBGT, iBERA 토큰과 Kodiak, BEX 등의 DEX LP 토큰을 담보로 사용한다. 이러한 복잡한 상호의존성은 다단계 공격 벡터를 가능하게 하며, 특히 LSP(Liquid Stability Pool)의 ERC4626 인플레이션 공격 취약점과 연쇄적으로 결합될 때 심각한 시스템 위험을 초래할 수 있다.

### 1단계: DEX 풀 불균형을 통한 LP 토큰 가치 조작

공격자는 먼저 베라체인 DEX(BEX, Kodiak 등)에서 대량 거래를 통해 특정 유동성 풀의 불균형을 유발한다. 예를 들어, HONEY-WBTC LP 토큰을 담보로 사용하는 대출자들이 많은 상황에서 공격자가 WBTC를 대량 덤핑하여 풀의 균형을 깨뜨리면 LP 토큰의 가치가 급락하게 된다. 이는 AMM의 임시적 손실 메커니즘에 의해 LP 토큰 보유자들의 실질 가치가 크게 감소한다.

### 2단계: 연쇄 청산 유발 및 LSP 자금 고갈

LP 토큰 가치 하락으로 인해 해당 토큰을 담보로 한 대출들의 담보비율(ICR)이 최소담보비율(MCR) 이하로 떨어지면서 대량 청산이 시작된다. 베라버로우의 청산 메커니즘에 따라 청산된 부채는 LSP에서 상쇄되고 청산된 담보는 LSP로 전송되지만, 청산 규모가 LSP의 NECT 잔액을 초과하면 남은 부채는 시스템 전체에 재분배된다. 이 과정에서 LSP 내 NECT 잔액이 급격히 감소하며, 다른 담보들의 추가 가격 하락 우려로 인해 LSP 예치자들의 대량 인출 러시가 발생할 수 있다.

### 3단계: LSP totalSupply 최소화 상태 달성

연쇄 청산과 인출 러시의 결과로 LSP의 totalSupply가 거의 0에 가까운 상태에 도달한다. 베라버로우의 LSP는 BaseCollateralVault와 달리 virtual accounting 메커니즘을 구현하지 않았으며, deposit/mint 함수에서 totalSupply=0 상태에 대한 보호장치가 없다. 오직 linearVestingExtraAssets 함수에만 ZeroTotalSupply 체크가 존재하지만 이는 일반적인 예치 과정에는 적용되지 않는다.

### 4단계: ERC4626 인플레이션 공격 실행

공격자는 LSP가 거의 비어있는 상태를 이용하여 1 wei의 NECT를 예치하여 100% 지분을 획득한다. 이후 NECT 토큰의 transfer 함수를 통해 LSP 컨트랙트 주소로 직접 대량의 NECT를 전송한다. DebtToken의 requireValidRecipient 함수는 LSP 주소를 차단하지 않기 때문에 이러한 직접 전송이 성공적으로 이루어진다. LSP의 totalAssets() 함수는 실제 토큰 잔액이 아닌 내부 balanceData.balance\[asset()]만을 반영하므로 도네이션된 NECT는 자산 계산에 포함되지 않는다.

### 5단계: 후속 예치자 공격 및 이익 실현

후속 예치자가 NECT를 예치하려 할 때, ERC4626의 convertToShares 계산에서  solidity의 반올림으로 인해 0 shares를 받게 된다. 공격자는 이후 자신의 지분으로 전체 잔액을 인출할 수 있다. 이 공격은 LSP가 재배포되거나 대규모 청산 후 사용자들이 대부분 인출한 상황에서 반복적으로 실행 가능하며, 베라버로우 시스템의 신뢰성과 안정성을 심각하게 훼손할 수 있다.

### 시스템적 위험 및 영향

이러한 연쇄적 공격은 베라체인의 PoL 메커니즘과 베라버로우의 다중 담보 대출 시스템 간의 상호의존성을 악용하여 단일 취약점을 시스템 전체의 위험으로 확대시킵니다. 특히 Infrared의 iBGT, iBERA 토큰들이 베라버로우에서 주요 담보로 사용되고 있어, DEX 풀 불균형이 Infrared 스테이킹 플랫폼, 베라버로우 대출 시스템, 그리고 LSP에 걸쳐 도미노 효과를 일으킬 수 있다. 따라서 LSP의 ERC4626 인플레이션 공격 취약점은 단순한 스마트 컨트랙트 버그를 넘어서 베라체인 생태계 전반의 시스템적 위험으로 평가되어야 한다.

#### 가이드라인

> * **Dex 풀의 불균형 발생 시 LP 토큰을 담보로 하는  Lending 프로토콜에 경고 시스템 제작**
> * **Dex-Lending 프로토콜 간 실시간 위험 지표 공유**
> * #### Virtual Accounting 시스템 구현
>   * #### LSP 컨트랙트에 BaseCollateralVault와 동일한 virtual accounting 메커니즘 도입내부 balance 추적과 실제 토큰 잔액 분리를 통한 도네이션 공격 차단
> * 최소 예치금 임계값 설정
>   * LSP deposit/mint 함수에 최소 예치금 요구사항 추가&#x20;
>   * 초기 예치 시 더 높은 최소 금액 설정으로 공격 비용 증가
> * #### totalSupply=0 상태 보호 강화
>   * #### 모든 예치 함수에 ZeroTotalSupply 체크 확장 적용linearVestingExtraAssets 함수에만 존재하는 보호를 전체 시스템으로 확산
> * 부트스트랩 기간 보호 메커니즘
>   * 초기 24-48시간 동안 예치 제한 및 추가 검증 절차 적용
>   * 부트스트랩 기간 중 관리자 승인 없이는 대량 예치 차단
> * LSP-DenManager 간 실시간 청산 모니터링
>   * 대량 청산 발생 시 LSP 인출 임시 제한 및 경고 시스템 작동연쇄 청산으로 인한 LSP 고갈 상황 사전 감지
> * #### totalSupply 임계값 기반 알림 시스템
>   * #### LSP totalSupply가 설정된 최소값 이하로 떨어질 시 자동 경고관리자 및 사용자에게 실시간 알림 전송
> * 비정상적 예치/인출 패턴 감지
>   * 단일 트랜잭션에서 극소량 예치 후 대량 자산 전송 패턴 모니터링
>   * 플래시론과 연계된 복합 공격 시나리오 실시간 탐지
> * LSP-DEX 간 유동성 상관관계 추적
>   * 베라체인 DEX 풀 불균형이 LSP 안정성에 미치는 영향 실시간 분석
>   * Kodiak, BEX 등 주요 DEX와의 데이터 공유 시스템 구축
> * 긴급 일시 정지 메커니즘
>   * 의심스러운 활동 감지 시 LSP 예치/인출 기능 즉시 중단 권한다중 서명 기반 긴급 대응 체계 구축
> * 사용자 교육 및 투명성 강화
>   * LSP 위험성 및 ERC4626 메커니즘에 대한 사용자 교육 자료 제공
>   * 공격 시나리오 및 방어 현황에 대한 정기적 투명성 보고서 발행
> * 보험 및 보상 체계 구축
>   * 인플레이션 공격 피해자를 위한 보험 풀 또는 보상 메커니즘 마련
>   * 커뮤니티 기반 피해 복구 프로토콜 개발
> * 정기적 보안 감사 및 업그레이드
>   * LSP 컨트랙트에 대한 분기별 보안 감사 실시
>   * 새로운 공격 벡터 발견 시 즉시 업그레이드 프로세스 진행

#### Best Practice&#x20;

`커스텀 코드`

```solidity
// LP 토큰의 건정성을 확인하는 함수
function updateLpTokenRisk(address _lpToken, bool _isHighRisk) external onlyOwner {
    require(_lpToken != address(0), "LP token: zero address"); 
    if (lpTokenIsHighRisk[_lpToken] != _isHighRisk) {
        lpTokenIsHighRisk[_lpToken] = _isHighRisk;
        emit LpTokenRiskStatusUpdated(_lpToken, _isHighRisk);
        // 이 이벤트는 오프체인 경고 시스템에 의해 감지되어 사용자에게 알림을 보낼 수 있습니다.
    }
}
```

```solidity
// 1. Virtual accounting 추가
mapping(address => uint) internal virtualAssetBalance;

function totalAssets() public view override returns (uint) {
    return virtualAssetBalance[asset()]; // 핵심 수정
}

// 2. deposit 함수에 보호 로직 추가
function _depositAndMint(/*...*/) private {
    if (totalSupply() == 0) {
        require(assets >= 1000e18, "LSP: Minimum initial deposit");
    }
    
    _provideFromAccount(msg.sender, assets);
    virtualAssetBalance[asset()] += assets; // Virtual balance 추적
    
    // 기존 로직...
}
```

***

### 위협 2: HONEY 가격 불안정으로 인한 대출 프로토콜 마비

HONEY와 대출 프로토콜에서 사용되는 NECT는 연결되어 있다. HONEY의 가격이 불안정해지면 NECT로 1:1 교환하여 담보 상환이 지속돼 대출 프로토콜이 마비 될 수 있다.

#### 가이드라인

> * **HONEY 가격이 사전에 정의된 안전 임계치 이하로 크게 하락하거나 단기간에 급격한 변동성을 보일 경우, NECT와 관련된 특정 기능을 일시적으로 중단하거나 제한**

#### Best Practice

`커스텀 코드`

```solidity
// HONEY의 건전성 체크
function setHoneyPriceInstability(bool _isUnstable) external onlyOwner {
    if (isHoneyPriceUnstable != _isUnstable) {
        isHoneyPriceUnstable = _isUnstable;
        emit HoneyPriceInstabilityTriggered(_isUnstable, msg.sender);
    }
}

// HONEY 가격 불안정 시 $NECT를 통한 1:1 가치 상환 제한
function repayDebtWithNect(uint256 _amountToRepay) external {
    address user = msg.sender;
    require(_amountToRepay > 0, "Repayment amount must be positive");
    require(userDebtInNect[user] >= _amountToRepay, "Amount exceeds debt");

    if (isHoneyPriceUnstable) {
        emit NectRepaymentBlocked(user, _amountToRepay, "$HONEY price is unstable. $NECT repayments temporarily suspended.");
        revert("Repayments with $NECT are temporarily suspended due to $HONEY price instability.");
    }
    ...
}
```

***

### 위협 3: 개별 프로토콜 붕괴 시 연쇄 반응으로 인한 베라체인 생태계 붕괴

인프라레드가 베라체인의 핵심 보상 분배 및 스테이킹 메커니즘을 상당 부분 담당하고 있으므로 만약 인프라레드 프로토콜이 붕괴된다면 스테이킹 보상 지급이 중단되거나 오류가 발생하고 검증인 및 위임자들의 신뢰가 급격히 하락할 것이다.

이는 결국 베라체인 네트워크 보안 약화로 이어질 수 있으며 다른 연계된 dApp들의 정상적인 작동을 방해하여 생태계 전반의 불안정성을 증폭시킬 수 있다.

#### 가이드라인

> * **모든 연계 프로토콜의 핵심 지표를 실시간 통합 모니터링**
> * **위협 발생 시 사람의 개입 없이 자동으로 방어 메커니즘 실행. 서킷 브레이커로 자동으로 시스템 일시 정지**
> * **프로토콜 간 상호 의존도 매핑 및 위험 전파 경로 사전 분석**

#### Best Practice

`커스텀 코드`

```solidity
// Circuit Breaker 예시
function setSystemPause(bool _pause, string calldata _reason) external onlyOwner {
    if (_pause) {
        require(currentSystemStatus != SystemStatus.Paused, "System already paused");
        currentSystemStatus = SystemStatus.Paused;
        recoveryLevelPercentage = 0; // 일시 중지 시 운영 레벨 0%
        emit SystemPaused(msg.sender, _reason);
    }
}
```
