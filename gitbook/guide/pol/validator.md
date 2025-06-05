---
icon: user-check
---

# PoL 보안 가이드라인: 검증자

<table><thead><tr><th width="609.89453125">위협</th><th align="center">영향도</th></tr></thead><tbody><tr><td><a data-mention href="validator.md#id-1">#id-1</a></td><td align="center"><code>Medium</code></td></tr><tr><td><a data-mention href="validator.md#id-2">#id-2</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="validator.md#id-3-cap">#id-3-cap</a></td><td align="center"><code>Low</code></td></tr></tbody></table>

### 위협 1: 블록 보상 분배 시 검증자의 중복 수령, 누락

검증자가 블록 생성 보상을 실행 레이어에서 수령하므로 합의 레이어의 정보를 가져와야 한다. \
이 과정에서 정확하지 않는 정보 확인이 진행되면 블록 보상 제공 오류가 발생한다.

#### 영향도

`Medium`&#x20;

검증자 보상 중복 수령 및 누락은 검증자의 손해를 초래하나, EIP-4788 기반 Merkle root 검증의 견고함이 공격 성공 가능성을 현저히 낮추므로 Medium으로 평가된다.

#### 가이드 라인

> * **동일 timestamp 중복 처리 방지 메커니즘 구현**
>   * timestamp를 eip-4788의 history\_buf\_length로 mod 연산을 하여 `_processedTimestampsBuffer`에 삽입.
>   * 최소 4.55 시간 (8191 \* 2초)이 지나면 가장 오래된 타임스탬프 처리 기록이 새로운 기록으로 덮어씌워지며 중복 검증 진행
> *   **Beacon block root과 proposer index/pubkey 의 암호학적 검증**
>
>     * SSZ.verifyProof 함수를 사용하여, 특정 타임스탬프의 비콘 루트(beacon root)를 기준으로 해당 제안자(proposer)의 보상 자격을 검증.
>     * 검증 실패시 revert 발생
>
>     ```solidity
>     if (!SSZ.verifyProof(proposerIndexProof, beaconBlockRoot, proposerIndexRoot, proposerIndexGIndex)) {
>       InvalidProof.selector.revertWith();
>     }
>     ```

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

// _processedTimestampsBuffer를 사용하여 timestamp에 해당하는 보상 수령 체크
function _processTimestampInBuffer(uint64 timestamp) internal returns (bytes32 parentBeaconBlockRoot) {
  // First enforce the timestamp is in the Beacon Roots history buffer, reverting if not found.
  parentBeaconBlockRoot = timestamp.getParentBlockRootAt();

  // Mark the in buffer timestamp as processed if it has not been processed yet.
  uint64 timestampIndex = timestamp % HISTORY_BUFFER_LENGTH;
  if (timestamp == _processedTimestampsBuffer[timestampIndex]) TimestampAlreadyProcessed.selector.revertWith();
  _processedTimestampsBuffer[timestampIndex] = timestamp;

  // Emit the event that the timestamp has been processed.
  emit TimestampProcessed(timestamp);
}

// merkle tree를 이용해서 보상자 검증
function _verifyProposerIndexInBeaconBlock(
  bytes32 beaconBlockRoot,
  bytes32[] calldata proposerIndexProof,
  uint64 proposerIndex
) internal view {
  bytes32 proposerIndexRoot = SSZ.uint64HashTreeRoot(proposerIndex);

  if (!SSZ.verifyProof(proposerIndexProof, beaconBlockRoot, proposerIndexRoot, proposerIndexGIndex)) {
    InvalidProof.selector.revertWith();
  }
}
```
{% endcode %}

***

### 위협 2: 운영자 변경 프로세스 악용

검증자가 설정한 운영자가 악의적으로 변경되거나 권한을 탈취당할 경우, 검증인에게 위임된 BGT가 부적절하게 관리될 수 있다. 이는 위임자들의 신뢰 하락 및 평판 실추로 이어져 BGT 위임량이 감소할 수 있다.

#### 영향도

`Low`&#x20;

악의적 운영자로 인한 피해가 위임 자산의 직접적인 손실보다는, 평판 저하 및 미래의 BGT 위임으로 수익 감소에 국한되어 Low로 평가된다.

#### 가이드라인

> * **운영자 변경 시 queue 메커니즘과 시간 지연을 통한 급작스러운 변경 방지**
>   * key = pubkey, value = new operator로 설정하여 운영자 변경 요청 queue 삽입
>   * queue에 1 day 있어야 operator 변경 진행
> * **거버넌스 또는 신뢰할 수 있는 제3자를 통한 운영자 강제 변경/취소 메커니즘**
>   * `cancelOperatorChange` msg.sender를 현재 operator, governance 로 설정
>   * operator의 의도적인 commission 상승, 하락 같은 행위에 페널티로 운영자 변경
> * **운영자 변경 시 기존 예치 잔액에 대한 잠금 기간 설정 및 점진적 권한 이전**
>   * 운영자에 대한 booster들의 판단이 진행 되도록 처음에는 보상 분배 권한만 진행 → unboost할 수 있는 시간을 주어진 후 commission 변경 권한 부여
> * **운영자 주소가 zero address로 적용되지 않도록 방지**

#### Best Practice&#x20;

&#x20;[`BeaconDeposit.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/pol/BeaconDeposit.sol#L84-L128)&#x20;

{% code overflow="wrap" %}
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
{% endcode %}

***

### 위협 3: 출금 로직 미존재로 검증자 cap에서 벗어날 때까지 자금 동결

현재 베라체인에서는 검증자가 예치한 금액을 자발적으로 인출하는 로직이 존재하지 않는다. 따라서 체인에 예치한 금액을 긴급하거나 필요할 때 인출이 불가능하다.

#### 영향도

`Low`&#x20;

자발적 출금 로직 부재로 자금이 일시적으로 동결되지만, 이는 자산의 직접적인 손실이나 탈취가 아니며 향후 검증자 자격(cap) 변동 시 회수 가능하므로 영향은 Low로 평가된다.

#### 가이드라인&#x20;

> * **예치, 인출 로직 추가 및 검증, 거버넌스를 통해 조정 가능한 출금 제한 및 잠금 기간 설정**
>   *   **requestWithdrawal 시 검증:**
>
>       * 호출자가 유효한 검증자인지 (또는 권한을 위임받은 운영자인지).
>       * 요청 금액이 검증자의 인출 가능한 예치금(또는 최소 예치금 요구사항을 제외한 초과분)을 초과하지 않는지.
>       * 활성화된 출금 요청 한도(횟수, 총액)를 초과하지 않는지 (거버넌스 설정).
>       * 현재 출금 제한 기간(예: 특정 네트워크 업그레이드 기간)이 아닌지.
>
>
>   *   **claimWithdrawal 시 검증:**
>
>       * 호출자가 해당 출금 요청의 정당한 수령인인지.
>       * 출금 요청 상태가 READY\_FOR\_CLAIM인지.
>       * unlockTime이 실제로 지났는지 (이중 확인).
>       * (만약 슬래싱 조건이 있다면) 해당 검증자가 출금 대기 중 심각한 페널티(슬래싱)를 받지 않았는지 (슬래싱 발생 시 출금액 조정 또는 거부 가능).
>
>
>   *   출금 제한 및 출금 잠금 기간 고려 사항
>
>       * **네트워크 안정성:** 검증자가 갑자기 대량으로 이탈하여 네트워크 보안이 약화되는 것을 방지. 잠금 기간은 새로운 검증자가 합류하거나 기존 검증자들이 대응할 시간을 제공.
>       * **유동성 관리:** 프로토콜이 갑작스러운 유동성 유출에 대비하고 안정적으로 자금을 관리할 시간을 확보.
>       * **의사결정 신중성:** 검증자가 출금 결정을 내리기 전에 충분히 숙고할 시간을 제공 (특히 장기 스테이킹 인센티브와 연계).
>       * **시장 변동성 대응:** 급격한 시장 변동 시 패닉셀로 인한 연쇄적인 자금 이탈을 늦추는 효과.
>
>
> * **queue 시스템을 통한 단계별 출금 프로세스 구현**
>   *   **requestWithdrawal (검증자/사용자 호출)**
>
>       * **기능:** 검증자가 출금 요청 시, 해당 출금 요청액만큼 검증자의 **유효 예치금(active stake)에서 즉시 차감**하거나, 출금 대기 상태로 전환하여 추가적인 스테이킹 보상 계산에서 제외합니다.
>       * **목적:** 이중 인출 방지 및 출금 요청된 자금이 시스템 내 다른 용도로 사용되지 않도록 보장합니다. 검증자의 실제 가용 예치금 상태를 정확히 반영합니다.
>
>
>   * **processWithdrawal (시스템/운영자 호출):**
>     * **기능:** unlockTime (출금 잠금 해제 시간)이 도래한 출금 요청들을 식별하고, 해당 자금을 실제로 인출 가능한 상태로 "처리" 또는 "준비"합니다. 이는 내부적으로 자금을 별도의 출금 가능 풀로 옮기거나, 출금 가능 플래그를 설정하는 방식일 수 있습니다.
>     * **목적:** 대량의 출금 요청을 효율적으로 관리하고, 실제 자금 이동 전에 최종 상태 확인 및 준비 단계를 거칩니다.\
>
>   * **claimWithdrawal (검증자/사용자 호출):**
>     * **기능:** processWithdrawal을 통해 출금 가능 상태가 된 자금을 검증자(또는 지정된 수령인)가 자신의 지갑으로 최종적으로 인출(수령)합니다. 이 함수 호출 시 실제 토큰 전송이 발생합니다.
>     * **목적:** 검증자가 능동적으로 자신의 자금을 찾아갈 수 있도록 하며, 모든 출금 과정의 최종 단계를 담당합니다.\
>
>   * **라이프 사이클**
>     * **요청 (PENDING):** requestWithdrawal 호출 시 Withdrawal 구조체 생성, unlockTime 계산 후 저장.
>     * **처리 대기:** block.timestamp < unlockTime 동안 PENDING 상태 유지.
>     * **수령 준비 (READY\_FOR\_CLAIM):** block.timestamp >= unlockTime이 되고, processWithdrawal (또는 유사한 시스템 로직)을 통해 상태 변경.
>     * **완료 (COMPLETED):** 검증자가 claimWithdrawal을 호출하여 자금 수령 시 상태 변경.

{% hint style="danger" %}
**긴급 인출 기능 구현 시 페널티 메커니즘 적용**

**페널티 계산 수식 예시:**

* Penalty\_Amount = Withdrawal\_Amount \* Penalty\_Rate
* Penalty\_Rate = Base\_Penalty\_Rate + (Time\_Remaining\_In\_Lock / Total\_Lock\_Period) \* Additional\_Penalty\_Factor
* Base\_Penalty\_Rate: 기본적인 최소 페널티 비율 (예: 5%).
* Time\_Remaining\_In\_Lock: 정상적인 잠금 기간 중 남은 시간.
* Total\_Lock\_Period: 원래 설정된 총 잠금 기간.
* Additional\_Penalty\_Factor: 잠금 기간을 일찍 어길수록 추가로 부과되는 페널티 계수 (예: 10%).
* 간단하게는 고정 비율 페널티(예: 출금액의 10%)를 적용할 수도 있습니다.

**페널티 비율 설정 근거:**

* **기회비용 및 시스템 안정성 기여도 보상:** 정상적인 출금 절차를 따르는 다른 검증자들은 그 기간 동안 네트워크 안정성에 기여하고 유동성을 제공합니다. 긴급 출금은 이러한 암묵적인 약속을 깨는 것이므로, 그에 대한 비용을 지불하는 것입니다.
* **긴급 출금 남용 방지:** 페널티가 없다면 모든 사람이 긴급 출금을 사용하려 할 것이므로, 꼭 필요한 경우가 아니면 사용하지 않도록 유도하는 억제책입니다.
* **페널티 수준:** 너무 낮으면 억제 효과가 없고, 너무 높으면 실제로 긴급한 상황에 처한 검증자에게 과도한 부담이 될 수 있습니다. 프로토콜의 장기적인 안정성과 검증자의 유연성 사이의 균형을 고려하여 설정됩니다 (예: 전체 예치금의 5\~15% 범위).
{% endhint %}

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
