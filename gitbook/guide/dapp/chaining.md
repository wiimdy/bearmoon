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

# dApp 보안 가이드라인: 체이닝

<table><thead><tr><th width="616.01953125">위협</th><th align="center">영향도</th></tr></thead><tbody><tr><td><a data-mention href="chaining.md#id-1">#id-1</a></td><td align="center"><code>High</code></td></tr><tr><td><a data-mention href="chaining.md#id-2-dex-lsp-erc-4626">#id-2-dex-lsp-erc-4626</a></td><td align="center"><code>Medium</code></td></tr><tr><td><a data-mention href="chaining.md#id-3-honey-beraborrow">#id-3-honey-beraborrow</a></td><td align="center"><code>Medium</code></td></tr></tbody></table>

### 위협 1: 개별 프로토콜 붕괴 시 연쇄 반응으로 인한 체인 역플라이휠 발생

인프라레드가 베라체인의 핵심 보상 분배 및 스테이킹 메커니즘을 상당 부분 담당하고 있으므로 만약 인프라레드 프로토콜이 붕괴된다면 스테이킹 보상 지급이 중단되거나 오류가 발생하고 검증인 및 위임자들의 신뢰가 급격히 하락할 것이다.

이는 결국 베라체인 네트워크 보안 약화로 이어질 수 있으며 다른 연계된 dApp들의 정상적인 작동을 방해하여 생태계 전반의 역플라이휠이 발생할 수 있다.

Infrared 프로토콜은 베라체인의 PoL 경제에서 사실상 보상 엔진 역할을 한다. 먼저 BGT와 BERA를 스테이킹한 뒤 iBGT·iBERA라는 1:1 액면가의 LST 토큰을 발행해 주고, Vault 내부에서는 자동 복리-스테이킹을 계속 돌려서 새로 나온 BGT 블록 보상과 거래 수수료를 실시간으로 적립·분배한다. 이 덕분에 이용자는 유동성을 잠그지 않고도 스테이킹 이자를 받을 수 있고, 다른 dApp에 iBGT 또는 iBERA를 담보나 LP 자산으로 자유롭게 넣을 수 있다. 실제로 Infrared의 TVL은 10억 달러 이상으로 베라체인 전체에서 1위이며, DeFiLlama 기준으로 전체 체인 TVL의 40 % 내외를 차지한다.

#### 공격 시나리오

1. **LST 즉시 디페그 → 가격 폭락**\
   해킹이든 컨트랙트 일시 중단이든 Infrared가 출금을 막으면, iBGT·iBERA는 더 이상 BGT 또는 BERA를 언제든 1:1로 바꿀 수 있는 토큰이 아니게 된다. 시장은 즉시 이를 가격에 반영해 iBGT, iBERA 프리미엄이 하락한다. 이런 급격한 하락은 Kodiak WETH:iBGT, WBERA:iBGT, BEX USDC:iBERA 같은 LST-기반 LP 풀을 불균형 상태로 만들고, 유동성 공급자들은 손실을 피하려고 LP 토큰을 회수하면서 풀의 유동성이 줄어든다.
2. **담보 가치 폭락 → Beraborrow 연쇄 청산**\
   Beraborrow의 DenManager는 iBGT·iBERA 가격을 Infrared 전용 TWAP 오라클로 가져온다. 시세가 30 %만 떨어져도 다수의 Den 포지션이 최소 담보 비율(MCR)을 밑돌아 자동 청산되기 시작한다다. 청산 과정에서 대량으로 쏟아져 나온 NECT가 시장에 매도되면, 네이티브 스테이블코인 페그에도 하방 압력이 가중된다.
3. **LSP 고갈 → 4626 인플레이션 취약점 노출**\
   Den 대량 청산으로 넘어온 NECT는 우선 LSP로 유입되는데, 이 잔액이 빠르게 소진되면 LSP의 totalSupply가 0 근처까지 줄어듭니다. LSP는 `totalSupply == 0` 가드와 virtual accounting이 없어 1 wei 예치 뒤 도네이션으로 지분 100 %를 차지하는 ERC-4626 인플레이션 공격이 가능해진다. 공격자가 LSP를 털어 가면 NECT 페그 회복에 쓰여야 할 유동성이 완전히 증발한다.
4. **검증자·위임자 신뢰 붕괴 → 네트워크 보안 약화**\
   Infrared는 자체적으로 검증자 노드를 운영하면서 스테이킹된 BGT를 다시 네트워크에 위임해 둔다. TVL 기준으로 전체 스테이킹 지분의 10 억 달러 이상이 Infrared Vault에 묶여 있으므로, Vault가 중단되면 해당 지분이 불능 상태가 된다. 결과적으로 유효 스테이크가 급감하고 검증자 세트 중 일부가 블록 제안에서 제외되면서 블록 인터벌이 늘어난다.
5. **PoL 인센티브 중단 → 생태계 역플라이휠**\
   Infrared가 보상 분배를 멈추면 BeraChef·RFRV Vault로부터 나오는 PoL 보상도 같이 멈춘다. 유동성 공급자는 돈이 안 되는 풀을 떠나고, TVL이 줄어든 dApp들은 다시 인센티브를 삭감하며 악순환이 시작된다.&#x20;

#### 영향도

`High`

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

***

### 위협 2: DEX 풀 불균형 연쇄청산으로 인한 LSP ERC-4626 인플레이션 공격

BeraBorrow는 베라체인의 PoL 메커니즘과 긴밀하게 통합되어 있으며, Infrared의 iBGT, iBERA 토큰과 Kodiak, BEX 등의 DEX LP 토큰을 담보로 사용한다. 이러한 복잡한 상호의존성은 LSP의 ERC-4626 인플레이션 공격 취약점과 연쇄적으로 결합될 때 심각한 시스템 위험을 초래할 수 있다.

**공격 시나리오**

1. 공격자가 베라체인 DEX에서 대량 거래를 통해, Beraborrow에서 담보로 사용되는 LP를 발행하는 유동성 풀(예: kodiak의 HONEY-BERA)의 불균형을 유발한다.&#x20;
2. LP 토큰 가치 하락으로 담보비율(ICR)이 최소담보비율(MCR) 이하로 떨어지면서 대량 청산이 시작된다. 청산 규모가 LSP의 NECT 잔액을 초과하면서 LSP 예치자들의 대량 인출 러시가 발생한다.
3. 연쇄 청산과 인출 러시로 LSP의 totalSupply가 거의 0에 가까운 상태에 도달한다. 베라버로우 LSP는 BaseCollateralVault와 달리 virtual accounting 메커니즘을 구현하지 않았으며, deposit/mint 함수에서 totalSupply=0 보호장치가 없다.
4. 공격자가 1 wei의 NECT를 예치하여 100% 지분을 획득한 후, NECT 토큰을 LSP 컨트랙트로 직접 대량 전송한다. DebtToken의 \_requireValidRecipient 함수는 LSP 주소를 차단하지 않으며, LSP의 totalAssets() 함수는 도네이션된 NECT를 자산 계산에 포함하지 않는다.
5. 후속 예치자가 NECT를 예치할 때 ERC-4626의 convertToShares 계산에서 Solidity 반올림으로 인해 0 shares를 받게 되고, 공격자는 전체 잔액을 인출하여 이익을 실현한다.

**시스템적 위험**

* 이 연쇄적 공격은 베라체인의 PoL 메커니즘과 베라버로우의 다중 담보 대출 시스템 간 상호의존성을 악용하여 단일 취약점을 시스템 전체 위험으로 확대시킨다. Infrared의 iBGT, iBERA 토큰들이 주요 담보로 사용되어 DEX 풀 불균형이 Infrared 스테이킹 플랫폼, 베라버로우 대출 시스템, LSP에 걸쳐 도미노 효과를 일으킬 수 있다. 따라서 LSP의 ERC-4626 인플레이션 공격 취약점은 단순한 스마트 컨트랙트 버그를 넘어 베라체인 생태계 전반의 시스템적 위험으로 평가되어야 한다.

#### 영향도

`Medium`

#### 가이드라인

> * **Dex 풀의 불균형 발생 시 LP 토큰을 담보로 하는  Lending 프로토콜에 경고 시스템 제작**
> * **Virtual Accounting 시스템 구현**
> * **LSP 컨트랙트에 BaseCollateralVault와 동일한 virtual accounting 메커니즘 도입내부 balance 추적과 실제 토큰 잔액 분리를 통한 도네이션 공격 차단**
> * **최소 예치금 임계값 설정**
>   * **LSP deposit/mint 함수에 최소 예치금 요구사항 추가**&#x20;
>   * **초기 예치 시 더 높은 최소 금액 설정으로 공격 비용 증가**
> * **totalSupply=0 상태 보호 강화**
>   * **모든 예치 함수에 ZeroTotalSupply 체크 확장 적용linearVestingExtraAssets 함수에만 존재하는 보호를 전체 시스템으로 확산**
> * **부트스트랩 기간 보호 메커니즘**
>   * **초기 24-48시간 동안 예치 제한 및 추가 검증 절차 적용**
>   * **부트스트랩 기간 중 관리자 승인 없이는 대량 예치 차단**
> * **LSP-DenManager 간 실시간 청산 모니터링**
>   * **대량 청산 발생 시 LSP 인출 임시 제한 및 경고 시스템 작동연쇄 청산으로 인한 LSP 고갈 상황 사전 감지**
> * **비정상적 예치/인출 패턴 감지**
>   * **단일 트랜잭션에서 극소량 예치 후 대량 자산 전송 패턴 모니터링**
>   * **플래시론과 연계된 복합 공격 시나리오 실시간 탐지**
> * **LSP-DEX 간 유동성 상관관계 추적**
>   * **베라체인 DEX 풀 불균형이 LSP 안정성에 미치는 영향 실시간 분석**

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
    return virtualAssetBalance[asset()]; 
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

### 위협 3: HONEY 가격 불안정으로 인한 Beraborrow 대출 프로토콜 마비

HONEY의 시장 가격이 폭락했음에도  Beraborrow의`PermissionlessPSM.sol`이  1:1로 NECT를 민팅할 경우, 공격자는 저렴해진 HONEY로 대량의 NECT를 확보한다.  이후 이 NECT를 대출 프로토콜에서 고정된 가치로 담보 상환에 악용하여 프로토콜의 자산을 고갈시킨다.

**핵심 취약점**

NECT의 가격 결정 메커니즘: \_whitelistStable 함수 내에서 `wadOffset = (10 ** (nect.decimals() - stable.decimals())`로 HONEY와 NECT 간의 교환 비율 오프셋을 설정한다. 이는 단순히 두 토큰의 소수점 자릿수 차이를 보정하는 역할만 하며, HONEY의 실제 시장 가격을 반영하는 오라클과 연동되어 있지 않는다. 따라서 HONEY의 외부 시장 가격이 폭락하더라도 Beraborrow의 PermissionlessPSM.sol은 여전히 고정된 오프셋인 1:1로 NECT를 민팅해준다.

공격 시나리오

1. HONEY의 가격이 급락하여 공격자가 차익 거래 기회를 포착하고 HONEY를 대량 매집한다.&#x20;
2. 이 HONEY를 가지고 PermissionlessPSM.sol의 deposit 함수를 호출하여 NECT를 대량 Mint한다.&#x20;
3. 이때 wadOffset은 HONEY의 시장가격과 상관 없이 NECT를 1대1로 민팅해준다.
4. 저가에 매수한 NECT로 빚을 상환하거나 sNECT로 교환 후 매도하여 수익을 실현한다.

#### 영향도

`Medium`&#x20;

ㄱ곰곰히 생각해보니 이게 공격인가? 보안의 취약점이 있는건가라는 생각이 드네요 ㅋㅋㅋㅋㅋㅋㅋ 그냥 정상 거래! 차익거래 잖아!!!



#### 가이드라인

> * **NECT 발행 로직에 HONEY 가격 오라클을 연동하여 실시간 가치를 반영하고, 가격 급락 시 발행 수수료를 동적으로 인상하거나 해당 스테이블 코인을 통한 발행을 일시 중단한다.**&#x20;
> * **스테이블 코인별 발행 총량을 관리하여 급격한 민팅을 방지한다.**

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
