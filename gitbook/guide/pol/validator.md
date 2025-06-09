---
icon: user-check
---

# PoL 보안 가이드라인: 검증자

<table><thead><tr><th width="609.89453125">위협</th><th align="center">영향도</th></tr></thead><tbody><tr><td><a data-mention href="validator.md#id-1">#id-1</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="validator.md#id-2">#id-2</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="validator.md#id-3-cap">#id-3-cap</a></td><td align="center"><code>Low</code></td></tr></tbody></table>

### 위협 1: 블록 생성 보상 분배 시 검증자의 보상 중복 수령, 누락

검증자가 블록 생성 보상을 실행 레이어에서 수령하므로 합의 레이어의 정보를 가져와야 한다. \
이 과정에서 정확하지 않는 정보 확인이 진행되면 블록 보상 제공 오류가 발생한다.

#### 영향도

`Low`

검증자 보상 중복 수령 및 누락은 검증자의 손해를 초래하나 Merkle root 검증 기법으로 공격 성공 가능성이 매우 낮기 때문에`Low`로 평가한다.&#x20;

#### 가이드 라인

> * **동일 timestamp 중복 처리 방지 메커니즘 구현**
>   * timestamp를 eip-4788의 [history\_buf\_length](../../reference.md#history_buf_length-eip-4788-8191-12-2)로 mod 연산을 하여 `_processedTimestampsBuffer`에 삽입
>   * EIP-4788의 ring buffer 메커니즘에 따라 8191 슬롯([약 4.55시간, 2초 간격 기준](../../reference.md#id-4.55-8191-2-8)) 후 덮어씌워짐, 이는 보상 주기와 일치함&#x20;
> *   **Beacon block root과 proposer index/pubkey 의 암호학적 검증**
>
>     * &#x20;[`SSZ.verifyProof`](../../reference.md#ssz.verifyproof-simple-serialize-merkle-proposer-index) 함수를 사용하여, 특정 타임스탬프의 비콘 루트를 기준으로 해당 제안자의 보상 자격을 검증
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

악의적 운영자로 인한 피해가 위임 자산의 직접적인 손실보다는 평판 저하 및 미래의 BGT 위임으로 수익 감소에 국한되기 때문에 `Low`로 평가한다.&#x20;

#### 가이드라인

> * **운영자 변경 시**[ **queue 메커니즘과 시간 지연**](../../reference.md#beacondeposit-24)**을 통한 급작스러운 변경 방지**
>   * key = pubkey, value = new operator로 설정하여 운영자 변경 요청 queue 삽입
>   * 운영자 변경시 delay 1일 (현재 컨트랙트 코드에 구현) 지나야 가능
> * **거버넌스 또는 신뢰할 수 있는 제3자를 통한 운영자 강제 변경/취소 메커니즘**
>   * `cancelOperatorChange` msg.sender가 operator, governance 인지 검증 진행
>   * 운영자의 의도적인 commission 급상승, 급하락 같은 행위에 페널티 부여
> * **운영자 변경 시 기존 예치 잔액에 대한** [**잠금 기간 설정 및 점진적 권한**](../../reference.md#greater-than-20) **이전**
>   * 운영자에 대한 booster들의 판단이 진행 되도록 처음에는 보상 분배 권한만 부여 → unboost할 수 있는 시간(unboost delay = 2000 block)을 주어진 후 commission 변경 권한 부여
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

[자발적 출금 로직 부재](../../reference.md#queue-2)로 자금 동결되지만, 베라체인의 [ValidatorSetCap](../../reference.md#validatorsetcap)에 따라 강제 퇴출 시 회수 가능하며, 이는 자산 손실보다는 네트워크 안정성에 잠재적 영향을 미쳐 `Low`로 평가한다.

#### 가이드라인&#x20;

> * **예치, 인출 로직 추가 및 검증, 거버넌스를 통해 조정 가능한 출금 제한 및 잠금 기간 설정**
>   *   **출금 대기 기간**
>
>       * 거버넌스의 타임락 기간(2일) 과 동일하게 설정
>
>       ```solidity
>       uint256 public constant WITHDRAWAL_LOCK_PERIOD = 2 days;
>       ```
>   * **requestWithdrawal 시 검증:**
>     * 호출자가 유효한 검증자인지
>     * 요청 금액이 검증자의 인출 가능한 예치금(또는 최소 예치금 요구사항을 제외한 초과분)을 초과하지 않는지
>     * 활성화된 출금 요청 한도(횟수, 총액)를 초과하지 않는지
>   * **claimWithdrawal 시 검증:**
>     * 호출자가 해당 출금 요청의 정당한 수령인인지
>     * 출금 요청 상태가 READY\_FOR\_CLAIM인지
>     * unlockTime이 실제로 지났는지
>   *   **출금 제한 및 출금 잠금 기간 고려 사항**
>
>       * 네트워크 안정성: 검증자가 갑자기 대량으로 이탈하여 네트워크 보안이 약화되는 것을 방지
>       * 유동성 관리: 프로토콜이 갑작스러운 유동성 유출에 대비하고 안정적으로 자금을 관리할 시간을 확보
>       * 의사결정 신중성: 검증자가 출금 결정을 내리기 전에 충분히 숙고할 시간을 제공
>       * 시장 변동성 대응: 급격한 시장 변동 시 패닉셀로 인한 연쇄적인 자금 이탈을 늦추는 효과
>
>
> * **queue 시스템을 통한 단계별 출금 프로세스 구현**
>   * **requestWithdrawal (검증자/사용자 호출):**
>     * 검증자가 출금 요청 시, 해당 출금 요청액만큼 검증자의 예치금에서 즉시 차감하거나, 출금 대기 상태로 전환하여 추가적인 스테이킹 보상 계산에서 제외
>   * **processWithdrawal (시스템/운영자 호출):**
>     * unlockTime이 도래한 출금 요청들을 식별하고, 해당 자금을 실제로 인출 가능한 상태로 처리
>   * **claimWithdrawal (검증자/사용자 호출):**
>     * `processWithdrawal`을 통해 출금 가능 상태가 된 자금을 검증자(또는 지정된 수령인)가 자신의 지갑으로 최종적으로 인출
>   * **라이프 사이클:**
>     * **요청 (PENDING):** requestWithdrawal 호출 시 Withdrawal 구조체 생성, unlockTime 계산 후 저장
>     * **처리 대기:** block.timestamp < unlockTime 동안 PENDING 상태 유지
>     * **수령 준비 (READY\_FOR\_CLAIM):** block.timestamp >= unlockTime이 되고, processWithdrawal (또는 유사한 시스템 로직)을 통해 상태 변경
>     * **완료 (COMPLETED):** 검증자가 claimWithdrawal을 호출하여 자금 수령 시 상태 변경
>   * **페널티 설정 근거:**
>     * **기회비용 및 시스템 안정성 기여도 보상:**
>       * 정상적인 출금 절차를 따르는 다른 검증자들은 그 기간 동안 네트워크 안정성에 기여하고 유동성을 제공한다. 긴급 출금은 이러한 암묵적인 약속을 깨므로, 그에 대한 비용을 지불
>     * **긴급 출금 남용 방지:**
>       * 페널티가 없다면 모든 사람이 긴급 출금을 사용하므로 꼭 필요한 경우가 아니면 사용하지 않도록 유도
>     * **페널티 수준:**
>       * 현재 남아있는 잠금 기간에 비례하여 기본 페널티 + 추가 페널티 부여
>         * Base\_Penalty\_Rate: 기본적인 최소 페널티 비율 (예: 5%)
>         * Time\_Remaining\_In\_Lock: 정상적인 잠금 기간 중 남은 시간
>         * Total\_Lock\_Period: 원래 설정된 총 잠금 기간
>         * Additional\_Penalty\_Factor: 잠금 기간을 일찍 어길수록 추가로 부과되는 페널티 계수 (예: 10%)

{% hint style="danger" %}
**긴급 인출 기능 구현 시 페널티 메커니즘 적용**

**페널티 계산 수식 예시:**

* Penalty\_Amount = Withdrawal\_Amount \* Penalty\_Rate
* Penalty\_Rate = Base\_Penalty\_Rate + (Time\_Remaining\_In\_Lock / Total\_Lock\_Period) \* Additional\_Penalty\_Factor
{% endhint %}

#### Best Practice&#x20;

```solidity
// 출금 로직 추가 및 lock time, emergency 구현
function requestWithdrawal(uint256 amount, bool _isEmergency) external nonReentrant {
    
    // 기본 페널티 계수 (BPS 단위, 예: 5%는 500)
    uint256 public basePenaltyBps = 500;
    // 추가 페널티 계수 (BPS 단위, 예: 10%는 1000)
    uint256 public additionalPenaltyBps = 1000;
    
    uint256 public constant WITHDRAWAL_LOCK_PERIOD = 2 days;
 
    require(amount > 0, "Amount must be > 0");
    require(validatorStakes[msg.sender] >= amount, "Insufficient staked balance for withdrawal request");

    validatorStakes[msg.sender] -= amount; 

    uint256 currentId = nextWithdrawalId;
    uint256 unlockTime = block.timestamp + WITHDRAWAL_LOCK_PERIOD;

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

    uint256 currentTime = block.timestamp;

    // 긴급 인출은 잠금 기간 내에서만 유효해야 합니다.
    require(currentTime < request.unlockTimestamp, "Emergency withdrawal only valid during lock period");

    // 잠금 기간 중 남은 시간을 계산합니다.
    uint256 timeRemaining = request.unlockTimestamp - currentTime;

    // 남은 시간에 비례하는 변동 페널티 비율을 계산합니다.
    // Penalty_Rate의 변동 부분 = (Time_Remaining_In_Lock / Total_Lock_Period) * Additional_Penalty_Factor
    // 정수 연산에서 정밀도 손실을 막기 위해 곱셈을 먼저 수행합니다.
    // 가정: additionalPenaltyBps와 WITHDRAWAL_LOCK_PERIOD 변수가 컨트랙트에 정의되어 있습니다.
    uint256 variablePenaltyBps = (timeRemaining * additionalPenaltyBps) / WITHDRAWAL_LOCK_PERIOD;

    // 가정: basePenaltyBps 변수가 컨트랙트에 정의되어 있습니다.
    uint256 totalPenaltyBps = basePenaltyBps + variablePenaltyBps;

    penaltyAmount = (amountToWithdraw * totalPenaltyBps) / 10000;

    if (penaltyAmount > amountToWithdraw) {
        penaltyAmount = amountToWithdraw;
    }

    amountToWithdraw -= penaltyAmount;

}
```
