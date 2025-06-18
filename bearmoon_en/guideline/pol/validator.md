---
icon: user-check
---

# PoL Security Guidelines: Validator

<table><thead><tr><th width="609.89453125">Threat</th><th align="center">Impact</th></tr></thead><tbody><tr><td><a data-mention href="validator.md#threat-1-duplicate-or-missed-validator-rewards-during-block-reward-distribution">#threat-1-duplicate-or-missed-validator-rewards-during-block-reward-distribution</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="validator.md#threat-2-exploitation-of-the-operator-change-process">#threat-2-exploitation-of-the-operator-change-process</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="validator.md#threat-3-funds-frozen-until-validator-exits-cap-due-to-non-existent-withdrawal-logic">#threat-3-funds-frozen-until-validator-exits-cap-due-to-non-existent-withdrawal-logic</a></td><td align="center"><code>Low</code></td></tr></tbody></table>

### Threat 1: Duplicate or Missed Validator Rewards During Block Reward Distribution <a href="#id-1" id="id-1"></a>

Validators receive block creation rewards on the execution layer, so they must retrieve information from the consensus layer.\
If incorrect information is verified during this process, block reward distribution errors can occur.

#### Impact

`Low`

Duplicate or missed validator rewards can cause losses for validators, but the probability of a successful attack is very low due to the Merkle root verification technique. Therefore, it is rated as `Low`.

#### Guideline

> * **Implement a mechanism to prevent duplicate processing of the same timestamp**
>   * Insert the timestamp into `_processedTimestampsBuffer` by performing a modulo operation with eip-4788's [history\_buf\_length](../../reference.md#history_buf_length).
>   * According to EIP-4788's ring buffer mechanism, it is overwritten after 8191 slots ([approximately 4.55 hours, based on a 2-second interval](../../reference.md#id-4.55-8191-2)), which matches the reward cycle.
> *   **Cryptographic verification of the Beacon block root and proposer index/pubkey**
>
>     * Use the [`SSZ.verifyProof`](../../reference.md#ssz.verifyproof) function to verify the proposer's reward eligibility based on the beacon root of a specific timestamp.
>     * A revert occurs if verification fails.
>
>     ```solidity
>     if (!SSZ.verifyProof(proposerIndexProof, beaconBlockRoot, proposerIndexRoot, proposerIndexGIndex)) {
>       InvalidProof.selector.revertWith();
>     }
>     ```

#### Best Practice

[`Distributor.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/pol/rewards/Distributor.sol#L100-L121)

{% code overflow="wrap" fullWidth="false" %}
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

### Threat 2: Exploitation of the Operator Change Process <a href="#id-2" id="id-2"></a>

If the operator set by a validator is maliciously changed or their authority is hijacked, the BGT delegated to the validator could be managed improperly. This can lead to a loss of trust and reputation among delegators, resulting in a decrease in BGT delegation.

#### Impact

`Low`

The damage from a malicious operator is limited to reputational damage and reduced future revenue from BGT delegation, rather than direct loss of delegated assets. Therefore, it is rated as `Low`.

#### Guideline

> * **Prevent abrupt changes during operator changes through a** [**queue mechanism and time delay**](../../reference.md#beacondeposit)
>   * Insert an operator change request into a queue by setting key = pubkey, value = new operator.
>   * An operator change is only possible after a 1-day delay (currently implemented in the contract code).
> * **Mechanism for forced operator change/cancellation through governance or a trusted third party**
>   * Verify that `msg.sender` of `cancelOperatorChange` is the operator or governance.
>   * Impose penalties for actions like intentional and sudden increases or decreases in commission by the operator.
> * **During an operator change, establish a** [**lock-up period and gradual transfer of authority**](../../reference.md#beacondeposit) **for existing deposits**
>   * Initially, grant only reward distribution rights to allow boosters to evaluate the operator → After providing time to unboost (unboost delay = 2000 blocks), grant the authority to change the commission.
> * **Prevent the operator address from being set to the zero address**

#### Best Practice

[`BeaconDeposit.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/pol/BeaconDeposit.sol#L84-L128)

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

### Threat 3: Funds Frozen Until Validator Exits Cap Due to Non-existent Withdrawal Logic <a href="#id-3" id="id-3"></a>

Currently, Berachain does not have a logic for validators to voluntarily withdraw their deposited funds. Therefore, it is impossible to withdraw funds deposited on the chain in case of emergency or need.

#### Impact

`Low`

Funds are frozen due to the [absence of a voluntary withdrawal logic](../../reference.md#undefined-1), but they can be recovered upon forced exit according to Berachain's [ValidatorSetCap](../../reference.md#validatorsetcap). This has a potential impact on network stability rather than asset loss, so it is rated as `Low`.

#### Guideline

> * **Add and verify deposit/withdrawal logic, and set adjustable withdrawal limits and lock-up periods through governance**
>   *   **Withdrawal Waiting Period**
>
>       * Set to be the same as the governance timelock period (2 days).
>
>       ```solidity
>       uint256 public constant WITHDRAWAL_LOCK_PERIOD = 2 days;
>       ```
>   * **Verification during `requestWithdrawal`:**
>     * Whether the caller is a valid validator.
>     * Whether the requested amount exceeds the validator's withdrawable deposit (or the excess amount excluding the minimum deposit requirement).
>     * Whether it exceeds the active withdrawal request limit (number of times, total amount).
>   * **Verification during `claimWithdrawal`:**
>     * Whether the caller is the rightful recipient of the withdrawal request.
>     * Whether the withdrawal request status is `READY_FOR_CLAIM`.
>     * Whether the `unlockTime` has actually passed.
>   * **Considerations for Withdrawal Limits and Lock-up Periods**
>     * Network Stability: Prevents a sudden mass exit of validators that could weaken network security.
>     * Liquidity Management: Gives the protocol time to prepare for sudden liquidity outflows and manage funds stably.
>     * Decision Prudence: Provides validators with enough time to deliberate before making a withdrawal decision.
>     * Market Volatility Response: Can slow down chain reactions of fund withdrawals caused by panic selling during sharp market fluctuations.
> * **Implement a step-by-step withdrawal process using a queue system**
>   * **`requestWithdrawal` (called by validator/user):**
>     * When a validator requests a withdrawal, immediately deduct the requested amount from the validator's deposit, or switch it to a withdrawal pending state to exclude it from additional staking reward calculations.
>   * **`processWithdrawal` (called by system/operator):**
>     * Identifies withdrawal requests whose `unlockTime` has arrived and processes the funds to a state where they can be actually withdrawn.
>   * **`claimWithdrawal` (called by validator/user):**
>     * The validator (or designated recipient) finally withdraws the funds, which have become withdrawable through `processWithdrawal`, to their own wallet.
>   * **Lifecycle:**
>     * **Request (PENDING):** When `requestWithdrawal` is called, a `Withdrawal` struct is created, and the `unlockTime` is calculated and stored.
>     * **Processing Wait:** Remains in the `PENDING` state while `block.timestamp < unlockTime`.
>     * **Ready for Claim (READY\_FOR\_CLAIM):** Becomes `READY_FOR_CLAIM` when `block.timestamp >= unlockTime` and the state is changed via `processWithdrawal` (or similar system logic).
>     * **Completed (COMPLETED):** The state changes when the validator calls `claimWithdrawal` to receive the funds.
>   * **Basis for Setting Penalties:**
>     * **Opportunity Cost and System Stability Contribution Reward:**
>       * Other validators who follow the normal withdrawal procedure contribute to network stability and provide liquidity during that period. An emergency withdrawal breaks this implicit agreement, so a cost is paid for it.
>     * **Preventing Abuse of Emergency Withdrawals:**
>       * If there were no penalty, everyone would use the emergency withdrawal, so this encourages its use only when absolutely necessary.
>     * **Penalty Level:**
>       * A base penalty + additional penalty is imposed in proportion to the remaining lock-up period.
>         * `Base_Penalty_Rate`: The basic minimum penalty rate (e.g., 5%).
>         * `Time_Remaining_In_Lock`: The time remaining in the normal lock-up period.
>         * `Total_Lock_Period`: The total lock-up period originally set.
>         * `Additional_Penalty_Factor`: A penalty coefficient that is additionally imposed the earlier the lock-up period is broken (e.g., 10%).

{% hint style="danger" %}
**Apply a penalty mechanism when using the emergency withdrawal function**

**Example Penalty Calculation Formula:**

* Penalty\_Amount = Withdrawal\_Amount \* Penalty\_Rate
* Penalty\_Rate = Base\_Penalty\_Rate + (Time\_Remaining\_In\_Lock / Total\_Lock\_Period) \* Additional\_Penalty\_Factor
{% endhint %}

#### Best Practice

{% code overflow="wrap" %}
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
{% endcode %}
