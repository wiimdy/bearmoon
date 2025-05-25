---
description: >-
  여러 dApp의 기능을 조합하여 사용하는 복합적인 DeFi 전략(예: LP 토큰을 담보로 스테이블코인 발행 후, 다시 해당 스테이블코인을
  유동성 풀에 제공)은 높은 수익률을 제공할 수 있지만, 동시에 위험도 증폭시킵니다.
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

### 위협 1: DEX 풀 불균형으로 LP 토큰 담보가치 급락 시 대출 대량 청산

#### 가이드라인

> * Dex 풀의 불균형 발생 시 LP 토큰을 담보로 하는 Lending에 경고 시스템 제작
> * Dex-Lending 프로토콜 간 실시간 위험 지표 공유

#### Best Practice&#x20;

```solidity
// contracts/src/pol/BeaconDeposit.sol

// 첫 deposit시 operator가 zero address인지 검증
function deposit( ...
if (_operatorByPubKey[pubkey] == address(0)) {
    if (operator == address(0)) {
        ZeroOperatorOnFirstDeposit.selector.revertWith();
    }
    ...
}

// operator 변경시 타임락 적용
function acceptOperatorChange(bytes calldata pubkey) external {
    ...

    if (queuedTimestamp + ONE_DAY > uint96(block.timestamp)) { 
        NotEnoughTime.selector.revertWith();
    }

    address oldOperator = _operatorByPubKey[pubkey];
    _operatorByPubKey[pubkey] = newOperator;
    delete queuedOperator[pubkey];
    emit OperatorUpdated(pubkey, newOperator, oldOperator);
}
```

***

### 위협 2: 자산 가치 평가 프로토콜간 불일치로 인한 시스템 불안정

#### 가이드라인

> * 통합 Price Oracle 인프라:&#x20;
>   * LP 토큰, 스테이킹 토큰 등 복합 자산이 프로토콜마다 다르게 평가되는 문제 해결
> * 크로스 프로토콜 가격 합의:&#x20;
>   * 주요 프로토콜 간 가격 정보 실시간 공유 메커니즘

#### Best Practice

```solidity
// contracts/src/pol/BeaconDeposit.sol

• **표준화된 가격 오라클**: 모든 프로토콜이 동일한 가격 참조 소스 사용하도록 표준 제정
• **가격 편차 모니터링**: 프로토콜 간 동일 자산 가격 차이가 2% 초과 시 자동 경고
• **차익거래 임계값 설정**: 24시간 내 동일 사용자의 차익거래 거래량을 $100,000로 제한
• **
• **Dynamic Pricing Adjustment**: 프로토콜 간 가격 차이 발생 시 자동으로 수수료 조정하여 균형 유도
```

***

### 위협 3: 자산 가치 평가 프로토콜간 불일치로 인한 시스템 불안정

시나리오: 개별 프로토콜 붕괴 시 연쇄 반응으로 인한 베라체인 생태계 붕괴

#### 가이드라인

> * 모든 연계 프로토콜의 핵심 지표를 실시간 통합 모니터링
> * 위협 발생 시 사람의 개입 없이 자동으로 방어 메커니즘 실행. Circuit Breaker로 자동으로 시스템 일시 정지
> * 프로토콜 간 상호 의존도 매핑 및 위험 전파 경로 사전 분석

#### Best Practice

```solidity
// contracts/src/pol/BeaconDeposit.sol

• **Cross-Protocol Risk Dashboard**: 모든 연계 프로토콜의 핵심 지표를 실시간 통합 모니터링
• **Gradual Recovery Protocol**: 위기 상황 해결 후 단계적 서비스 재개 절차 (30% → 70% → 100%)
• **Community Alert System**: 위기 상황 시 모든 이해관계자에게 실시간 상황 공유
```
