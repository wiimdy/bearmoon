---
icon: snake
---

# dApp: LSD 가이드라인

### 위협 1: 대량 예치/인출을 통한 iBERA/BERA 교환 비율 조작

#### 가이드라인

> * **교환 비율 계산 시 복리 효과 선 적용으로 미반영된 수익 정산**
> * **외부 자금 유입과 내부 회계 동기화 적용**
> * **최소 지분 유지로 0 나눗셈 방지**
> * **초기화 시점에서 최소 액수 초기화를 통해 운영 초반 시점 교환 비율 조작 가능성 제거**

#### Best Practice

```solidity
// Some code
```

• src/staking/InfraredBERA.sol\
&#x20; \- L215: compound 함수 선 실행을 통한 미반영 수익 정산 및 반영 절차 적용\
&#x20; \- L223 -> L277: InfraredBERADepositor 컨트랙트 내 queue 함수로 BeaconDeposit 컨트랙트 호출하여 외부 자금 유입 동기화 실시

&#x20; \- L227-L229: 초기화 시점에는 1:1, 이후에는 입금 비율에 비례하여 계산되도록 처리하며 초기화 시도 시 분배량 값이 0으로 초기화되어 iBERA/BERA 교환 비율이 조작될 가능성을 막기위해 예외처리 실시

***

### 위협 2: 특정 validator 자금 집중 현상으로 인한 보상 불균형과 중앙화 발생

#### 가이드라인

> * **validator 별 최대 스테이킹 한도 설정을 통한 보상 불균형 및 중앙화 발생 방지**
> * **validator 상태 추적 및 강제 종료 감지**
> * **리스테이킹 시 분산 정책 적용**
> * **서비스 내부의 사용자 활동에 따른 추가 보상 시스템을 바탕으로 서비스 참여도 증진 및 유동성 증진을 통한 탈중앙성 강화 유도**

#### Best Practice

```solidity
// Some code
```

• src/staking/InfraredBERADepositor.sol\
&#x20; \- L96-L98: 신규 validator 스테이킹을 허용하기 전 강제 퇴출된 기존 validator의 자금을 우선 처리할 때까지 신규 validator 예치를 일시 중단하는 로직 적용\
&#x20; \- L100-L106: 스테이킹 시점의 validator 현재 보유액과 입금 시도 금액의 총합이 스테이킹 최대 한도(MAX\_EFFECTIVE\_BALANCE)를 넘을 경우 예외처리\
&#x20; \- L111-L113: 허가된 validator 운영자 여부를 확인하여 의도되지 않은 스테이킹 발생 방지 처리

• Infrared는 서비스 내부에서 Points 제도를 운영하여 사용자 활동을 강화하는 비즈니스 로직 적용

***

### 위협 3: 수수료 변경 전/후 대량 수확을 통한 악성 행위자 이익 극대화

#### 가이드라인

> * **수수료 변경 전 기존 보상 강제 정산을 진행하여 보상 갈취 사전 차단**
> * **수수료 변경과 보상 수확 기능을 실행할 수 있는 권한을 최소화하여 무단 실행 제한**

#### Best Practice

```solidity
// Some code
```

• src/core/upgrades/InfraredV1\_2.sol\
&#x20; \- L519: 수수료 변경 시 변경 권한을 거버넌스 관리자에 한정하여 변경할 수 있도록 변경 권한 제한\
&#x20; \- L521-L522: 수수료 변경 전 fees 함수 실행을 통해 이전 수수료에 대한 정산을 진행하여 보상 오류 발생 가능성 차단 조치

• src/core/upgrades/InfraredV1\_5.sol\
&#x20; \- L26-L29: 외부 볼트에 대한 보상 수확을 Keeper 역할을 지닌 msg.sender에 한정하여 처리

***

### 위협 4: 악성행위 가능한 토큰을 통한 Bribe 시스템 오염

#### 가이드라인

> * **Bribe 시스템에 사용하는 보상 토큰에 대한 화이트리스트 운영**
> * **최소 Bribe 금액 한도 설정**
> * **BribeCollector에 대한 관련 권한 제한 처리**

#### Best Practice

```solidity
// Some code
```

• src/core/libraries/RewardLib.sol\
&#x20; \- L583: 화이트리스트 토큰 여부 검증 후 해당 시 해당 토큰들에 대한 BribeCollector 동작 실행 준비\
• src/core/upgrades/BribeCollectorV1\_3.sol\
&#x20; \- L60: BribeCollector의 보상 수거 실행 권한을 Keeper 사용자 한정으로 제한 처리

***

### 위협 5: 과도한 수수료 설정을 통한 사용자 이익 침해

#### 가이드라인

> * **수수료 변경 과정에서 수수료 한도 검증을 통한 최대 상한선 설정**

#### Best Practice

```solidity
// Some code
```

• src/core/libraries/RewardLib.sol\
&#x20; \- L263: 최대 수수료 한도 (UNIT\_DENOMINATOR) 설정을 통한 악성 행위에 의한 수수료 변경 여파로 발생하는 피해 최소화

\
