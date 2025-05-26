---
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

# dApp 체이닝 가이드라인

여러 dApp의 기능을 연쇄적으로 조합하여 사용하는 복합 DeFi 전략(예: LP 토큰을 담보로 스테이블코인 발행 후, 다시 해당 스테이블코인을 유동성 풀에 제공)은 고수익 기회를 제공합니다. 하지만 이러한 dApp 체이닝은 개별 dApp 사용 시에는 드러나지 않았던 새로운 상호작용 위험을 발생시키고 기존 위험을 증폭시킬 수 있습니다.&#x20;

### 위협 1: DEX 풀 불균형으로 LP 토큰 담보가치 급락 시 대출 대량 청산

DEX 유동성 풀이 한쪽으로 치우치며 LP 토큰 가치가 폭락하자, 이를 담보로 한 대출들이 연쇄적으로 청산될 위험이 발생합니다. 실시간 위험 경고 및 지표 공유 시스템 부재 시 사용자는 대응 시간을 놓쳐 자산 손실을 입게 됩니다.

#### 가이드라인

> * **Dex 풀의 불균형 발생 시 LP 토큰을 담보로 하는 Lending에 경고 시스템 제작**
> * **Dex-Lending 프로토콜 간 실시간 위험 지표 공유**

#### Best Practice&#x20;

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

***

### 위협 2: $HONEY 가격 불안정으로 인한 대출 프로코콜 마비

$HONEY와 대출 프로토콜에서 사용되는 $NECT는 연결되어 있다. $HONEY의 가격이 불안정해지면 $NECT로 1:1 교환하여 담보 상환이 지속돼 대출 프로토콜이 마비 될 수 있다.

#### 가이드라인

> * **$HONEY 가격이 사전에 정의된 안전 임계치 이하로 크게 하락하거나 단기간에 급격한 변동성을 보일 경우, $NECT와 관련된 특정 기능을 일시적으로 중단하거나 제한**

#### Best Practice

```solidity
// $HONEY의 건전성 체크
function setHoneyPriceInstability(bool _isUnstable) external onlyOwner {
    if (isHoneyPriceUnstable != _isUnstable) {
        isHoneyPriceUnstable = _isUnstable;
        emit HoneyPriceInstabilityTriggered(_isUnstable, msg.sender);
    }
}

// $HONEY 가격 불안정 시 $NECT를 통한 1:1 가치 상환 제한
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

#### 가이드라인

> * 모든 연계 프로토콜의 핵심 지표를 실시간 통합 모니터링
> * 위협 발생 시 사람의 개입 없이 자동으로 방어 메커니즘 실행. Circuit Breaker로 자동으로 시스템 일시 정지
> * 프로토콜 간 상호 의존도 매핑 및 위험 전파 경로 사전 분석

#### Best Practice

```solidity
// Circuit Breaker 예시
function setSystemPause(bool _pause, string calldata _reason) external onlyOwner {
    if (_pause) {
        require(currentSystemStatus != SystemStatus.Paused, "System already paused");
        currentSystemStatus = SystemStatus.Paused;
        recoveryLevelPercentage = 0; // 일시 중지 시 운영 레벨 0%
        emit SystemPaused(msg.sender, _reason);
        // 오프체인 Community Alert System이 이 이벤트를 감지하여 모든 이해관계자에게 즉시 알림
    }
}
```
