---
icon: user-check
---

# PoL 보안 가이드라인: 검증자

### 위협 1: 운영자 변경 프로세스 악용

시나리오

#### 가이드라인

> * operator 변경 시 queue 메커니즘과 시간 지연을 통한 급작스러운 변경 방지
> * 거버넌스 또는 신뢰할 수 있는 제3자를 통한 강제 변경/취소 메커니즘
> * operator 변경 시 기존 staking 잔액에 대한 freeze 기간 설정 및 점진적 권한 이전
> * 제로 주소가 적용되지 않도록 방지

#### Best Practice&#x20;

[BeaconDeposit.sol](https://github.com/berachain/contracts/blob/a405d00920f5b328c69a73b4c2ed4ef3b13adc0d/src/pol/BGTFeeDeployer.sol#L5)

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

### 위협 2: 출금 로직 미존재로 validator cap에서 벗어날 때까지 자금 동결

#### 가이드라인&#x20;

> * 예치, 인출 로직 추가 및 검증, 거버넌스를 통해 조정 가능한 출금 제한 및 잠금 기간 설정
> * queue 시스템을 통한 단계별 출금 프로세스 구현
> * emergency withdrawal 기능 구현 시 penalty 메커니즘 적용

#### Best Practice&#x20;

```solidity

// 출금 로직 추가 및 lock time, emergency 구현
function requestWithdrawal(uint256 amount, bool _isEmergency) external nonReentrant {
    require(amount > 0, "Amount must be > 0");
    require(validatorStakes[msg.sender] >= amount, "Insufficient staked balance for withdrawal request");

    validatorStakes[msg.sender] -= amount; 

    uint256 currentId = nextWithdrawalId;
    uint256 unlockTime = _isEmergency ? block.timestamp : block.timestamp + withdrawalLockupPeriod;

    validatorWithdrawalRequests[msg.sender].push(Withdrawal({
        id: currentId,
        amount: amount,
        requestTime: block.timestamp,
        unlockTime: unlockTime,
        isEmergency: _isEmergency,
        processed: false
    }));
    
    // 페널티 로직으로 출금에서 삭감
    ... 
    if (request.isEmergency) {
        penaltyAmount = (amountToWithdraw * emergencyWithdrawalPenaltyBps) / 10000;
        if (penaltyAmount > amountToWithdraw) penaltyAmount = amountToWithdraw; 
        amountToWithdraw -= penaltyAmount;
    }
```

***

### 위협 3: 블록 보상 분배 시 검증자의 중복 수령, 누락

#### 가이드 라인

> * 동일 timestamp 중복 처리 방지 메커니즘 구현
> * Beacon block root과 proposer index/pubkey의 암호학적 검증
> * 보상 분배 시 totalRewardDistributed 추적으로 누락/중복 방지
> * 블록 처리 상태를 기록하는 bitmap 또는 mapping을 통한 중복 처리 완전 차단

#### Best Practice&#x20;

{% code fullWidth="false" %}
```solidity
// contracts/src/pol/rewards/Distributor.sol

// 검증자 보상 수령시 timestamp 기록, beacon block과 index 일치 비교
function distributeFor( ...
    // Process the timestamp in the history buffer, reverting if already processed.
    bytes32 beaconBlockRoot = _processTimestampInBuffer(nextTimestamp);
    
    // Verify the given proposer index is the true proposer index of the beacon block.
    _verifyProposerIndexInBeaconBlock(beaconBlockRoot, proposerIndexProof, proposerIndex);
    
    // Verify the given pubkey is of a validator in the beacon block, at the given validator index.
    _verifyValidatorPubkeyInBeaconBlock(beaconBlockRoot, pubkeyProof, pubkey, proposerIndex);
...
}
```
{% endcode %}
