---
icon: user-check
---

# PoL 보안 가이드라인: 벨리데이터

### 위협 1: 권한 없는 주소에 의한 밸리데이터 등록/해제/정보 수정

#### 가이드라인

> * **밸리데이터 관련 중요 정보 변경은 다중 서명을 통해서만 가능하도록 설계**
> * **세분화된 권한 관리 및 최소 권한 원칙 적용**
> * **중요한 설정 변경 시 타임락 메커니즘 적용으로 급작스러운 변경 방지**

#### Best Practice&#x20;

```solidity
// contracts/src/pol/BeaconDeposit.sol

function acceptOperatorChange(bytes calldata pubkey) external {
    ...
    // operator 변경시 타임락 적용
    if (queuedTimestamp + ONE_DAY > uint96(block.timestamp)) { 
        NotEnoughTime.selector.revertWith();
    }

    address oldOperator = _operatorByPubKey[pubkey];
    _operatorByPubKey[pubkey] = newOperator;
    delete queuedOperator[pubkey];
    emit OperatorUpdated(pubkey, newOperator, oldOperator);
}

// contracts/src/pol/rewards/RewardVaultFactory.sol
// AccessControlUpgradeable 적용으로 세분화된 권한 관리 및 최소 권한 원칙 적용
contract RewardVaultFactory is AccessControlUpgradeable, UUPSUpgradeable {

    /// @notice The VAULT MANAGER role.
    bytes32 public constant VAULT_MANAGER_ROLE = keccak256("VAULT_MANAGER_ROLE");

    /// @notice The VAULT PAUSER role.
    bytes32 public constant VAULT_PAUSER_ROLE = keccak256("VAULT_PAUSER_ROLE");
    ...
}
```

***

### 위협 2: 밸리데이터의 스테이킹 된 자산(예: BGT 위임량) 계산 오류

#### 가이드라인

> * 스테이킹 및 위임 관련 상태 변수를 안전하게 업데이트
>   * 상태 변경 전 사전 조건 검증 (잔액, 권한, 한도 확인)
>   * 관련 상태 변수들의 원자적 일괄 업데이트
>   * 상태 변경 중간 및 완료 후 불변성 검증
> * 관련 이벤트 발생 시 명확한 로그 기록
> * unchecked 블록 사용 시 오버플로우/언더플로우 조건을 사전에 검증
> * 모든 상태 변경 후 `invariantCheck` modifier 를 통한 자동 검증 수행
> * 스테이킹 수량 계산 시 정밀도를 고려한 반올림 정책 일관성 유지

#### Best Practice&#x20;

```solidity
// contracts/src/pol/BGT.sol
OwnableUpgradeable 적용으로 governance 전용 함수 보호  //애배배
setMinter, setStaker 함수에서 onlyOwner 적용, zero address 검증 및 이벤트 발생
```

contracts/src/pol/BGT.sol

* activateBoost에서 상태 읽기 → 검증 → 일괄 업데이트 패턴 적용
* dropBoost에서 unchecked 블록 내 계산 전 충분한 조건 검증

contracts/src/base/StakingRewards.sol

* `_stake`에서 totalSupply 오버플로우 검증

***

### 위협 3: operator의 reward allocation 설정 미흡

#### 가이드라인

> * reward allocation에 대한 명확한 상한선 설정 및 검증
> * operator 변경 시 queue 메커니즘과 시간 지연을 통한 급작스러운 변경 방지
> * operator 변경 요청은 현재 operator만, 승인은 새로운 operator만 가능한 이중 인증 구조
> * operator 변경 시 기존 staking 잔액에 대한 freeze 기간 설정 및 점진적 권한 이전

#### Best Practice&#x20;

```solidity
// ccontracts/src/pol/BGTStaker.sol
onlyFeeCollector modifier로 보상 알림 권한 제한
BGTStaker의 stake/withdraw를 BGT 컨트랙트만 호출 가능하도록 제한
recoverERC20에서 reward token 회수 방지로 보상 안정성 확보
```

***

### 위협 4: 출금 로직 미존재로 validator cap에서 벗어날 때까지 체인에 자금 동결

#### 가이드라인&#x20;

> * 예치 인출 로직 추가 및 검증, 거버넌스를 통해 조정 가능한 출금 제한 및 냉각 기간 설정
> * boost drop 시 적절한 delay 메커니즘을 통한 급작스러운 대량 출금 방지
> * queue 시스템을 통한 단계별 출금 프로세스 구현
> * emergency withdrawal 기능 구현 시 penalty 메커니즘 적용

#### Best Practice&#x20;

```solidity
// contracts/src/pol/BGT.sol
queueDropBoost와 dropBoost를 통한 2단계 출금 프로세스
drop boost 시 시간 지연 조건 체크로 급작스러운 출금 방지
redeem 함수를 통한 BGT → native token 교환 출구 제공
```

***

### 위협 4: 출금 로직 미존재로 validator cap에서 벗어날 때까지 체인에 자금 동결

블록 보상 분배 시 중복 수령, 누락

\| 가이드라인 |

1\. 동일 timestamp 중복 처리 방지 메커니즘 구현

2\. Beacon block root 검증과 proposer index/pubkey의 암호학적 검증

3\. 보상 분배 시 totalRewardDistributed 추적으로 누락/중복 방지

4\. 블록 처리 상태를 기록하는 bitmap 또는 mapping을 통한 중복 처리 완전 차단

5\. 보상 분배 실패 시 자동 재시도 메커니즘 및 실패 로그 기록 시스템

\| Best Practice |

contracts/src/pol/rewards/Distributor.sol

* \_processTimestampInBuffer로 중복 처리 방지
* Beacon block root와 proposer 검증
* 마지막 receiver는 잔여 reward 받아 정확한 분배 보장
