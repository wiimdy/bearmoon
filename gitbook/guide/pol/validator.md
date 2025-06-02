---
icon: user-check
---

# PoL 보안 가이드라인: 검증자

<table><thead><tr><th width="609.89453125">위협</th><th align="center">영향도</th></tr></thead><tbody><tr><td><a data-mention href="validator.md#id-1">#id-1</a></td><td align="center"><code>Medium</code></td></tr><tr><td><a data-mention href="validator.md#id-2">#id-2</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="validator.md#id-3-cap">#id-3-cap</a></td><td align="center"><code>Low</code></td></tr></tbody></table>

### 위협 1: 블록 보상 분배 시 검증자의 중복 수령, 누락

검증자가 블록 생성 보상을 실행 레이어에서 수령하므로 합의 레이어의 정보를 가져와야 한다. \
이 과정에서 정확하지 않는 정보 확인이 진행되면 블록 보상 제공 오류가 발생한다.

#### 영향도

`Medium`

#### 가이드 라인

> * **동일 timestamp 중복 처리 방지 메커니즘 구현**
> * **Beacon block root과 proposer index/pubkey 의 암호학적 검증**
> * **보상 분배 시 totalRewardDistributed 추적으로 누락/중복 방지**
> * **블록 처리 상태를 기록하는 bitmap 또는 mapping을 통한 중복 처리 완전 차단**

#### Best Practice&#x20;

[`Distributor.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/pol/rewards/Distributor.sol#L100-L121)

{% code fullWidth="false" %}
```solidity
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

***

### 위협 2: 운영자 변경 프로세스 악용

검증자가 설정한 운영자가 악의적으로 변경되거나 권한을 탈취당할 경우, 검증인에게 위임된 BGT가 부적절하게 관리될 수 있다. 이는 검증인의 직접적인 자산 손실은 물론 위임자들의 신뢰 하락 및 평판 실추로 이어져 프로토콜에서 받는 인센티브양도 감소한다.

#### 영향도

`Low`

#### 가이드라인

> * **운영자 변경 시 queue 메커니즘과 시간 지연을 통한 급작스러운 변경 방지**
> * **거버넌스 또는 신뢰할 수 있는 제3자를 통한 운영자 강제 변경/취소 메커니즘**
> * **운영자 변경 시 기존 예치 잔액에 대한 잠금 기간 설정 및 점진적 권한 이전**
> * **운영자 주소가 zero address로 적용되지 않도록 방지**

#### Best Practice&#x20;

&#x20;[`BeaconDeposit.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/pol/BeaconDeposit.sol#L84-L128)&#x20;

```solidity
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

### 위협 3: 출금 로직 미존재로 검증자 cap에서 벗어날 때까지 자금 동결

현재 베라체인에서는 검증자가 예치한 금액을 자발적으로 인출하는 로직이 존재하지 않는다. 따라서 체인에 예치한 금액을 긴급하거나 필요할 때 인출이 불가능하다.

#### 영향도

`Low`

#### 가이드라인&#x20;

> * **예치, 인출 로직 추가 및 검증, 거버넌스를 통해 조정 가능한 출금 제한 및 잠금 기간 설정**
> * **queue 시스템을 통한 단계별 출금 프로세스 구현**
> * **긴급 인출 기능 구현 시 페널티 메커니즘 적용**

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
