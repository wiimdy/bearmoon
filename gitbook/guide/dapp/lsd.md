---
icon: d-and-d
---

# dApp 보안 가이드라인: LSD

<table><thead><tr><th width="594.08203125">위협</th><th align="center">영향도</th></tr></thead><tbody><tr><td><a data-mention href="lsd.md#id-1-ibera-bera">#id-1-ibera-bera</a></td><td align="center"><code>Medium</code></td></tr><tr><td><a data-mention href="lsd.md#id-2">#id-2</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="lsd.md#id-3-bribe">#id-3-bribe</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="lsd.md#id-4">#id-4</a></td><td align="center"><code>Informational</code></td></tr></tbody></table>

### 위협 1: 대량 예치, 인출을 통한 iBERA/BERA 교환 비율 조작

공격자가 iBERA/BERA 교환 비율을 대량 거래로 순간 조작하면 부당이득을 취하고 다른 사용자들은 손실을 보게 된다.\
이는 결국 프로토콜의 자산을 감소시키고 사용자 신뢰를 저해하여 시스템 안정성을 해친다.

#### 영향도&#x20;

`Medium`&#x20;

프로토콜 자산 감소와 신뢰 저하로 시스템 안정성에 직접적 영향을 미칠 수 있기 때문에 **`Medium`**&#xC73C;로 평가한다.

#### 가이드라인

> * **교환 비율 계산 시 복리 효과 선적용으로 미반영된 수익이 정산되는 현상이 발생하지 않도록 누적 보상을 선반영하여 입/출금 트랜잭션 처리**
> * **외부에서 직접 컨트랙트로 자금이 유입되거나 내부 회계가** [**실시간 동기화**](../../reference.md#uniswap-v3-compound)**되지 않으면 교환 비율이 왜곡되는 현상을 방지하기 위해, 모든 자산에 대한 유입/유출이 컨트랙트 내부 회계 상 실시간 반영되도록 적용**
> * **최초 유동성이 없는 상태에서 극소량의 예치금을 통한 교환 비율 왜곡 현상을 방지하기 위해 컨트랙트 배포 단계에서 최소 지분을 예치하여** [**zero totalsupply, zero division 현상 방지**](../../reference.md#lido-zero-totalsupply)

#### Best Practice

[`InfraredBERA.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Infrared/src/staking/InfraredBERA.sol#L213-L232)

{% code overflow="wrap" %}
```solidity
function mint(address receiver) public payable returns (uint256 shares) {
    compound(); // 미반영 수익 정산 및 반영 절차 적용

    uint256 d = deposits;
    uint256 ts = totalSupply();

    uint256 amount = msg.value;
    // InfraredBERADepositor 컨트랙트 내 queue 함수로 BeaconDeposit 컨트랙트 호출하여 외부 자금 유입 동기화 실시
    _deposit(amount);

    // 초기화 시점에는 1:1, 이후에는 입금 비율에 비례하여 계산되도록 처리
    shares = (d != 0 && ts != 0) ? (ts * amount) / d : amount;
    // 초기화 시도 시 예외처리 실시
    if (shares == 0) revert Errors.InvalidShares();
    _mint(receiver, shares);

    emit Mint(receiver, amount, shares);
}
```
{% endcode %}

***

### 위협 2: 수수료 변경 전/후 대량 수확을 통한 악성 행위자 이익 극대화

악성 행위자가 프로토콜 수수료 변경 시점을 악용하여 변경 직전/직후에 보상을 대량으로 수확하면 정당한 보상 분배 시스템을 왜곡하여 자신은 부당 이익을 챙기고 다른 사용자나 프로토콜 재정에 손실을 입힐 수 있다. \
이는 결국 시스템의 공정성과 신뢰도를 저해하는 결과를 낳는다.

#### 영향도&#x20;

`Low`&#x20;

수수료 변경 시점을 악용해 대량 보상을 수확할 경우 일부 사용자가 부당이득을 얻고 다른 사용자나 프로토콜 재정에 손실이 발생할 수 있으나 시스템 전체의 안정성이나 보안에 미치는 영향이 제한적이기 때문에 `Low`로 평가한다.

#### 가이드라인

> * **수수료 변경 전 기존 보상 정산을 진행하기 위해 스마트 컨트랙트 함수 실행 첫 단계에서 모든 미정산 보상을 자동으로 분배하여 보상 갈취 사전 차단**
> * **외부 컨트랙트가 수수료 변경과 보상 수확 기능을 동시에 실행하여 시스템을 갈취할 수 없도록 권한을 최소화하여 무단 실행 제한하며, 두 기능을** [**동시에 실행하는 트랜잭션을 허용하지 않도록 조치**](../../reference.md#updatefee-keeper_role)

#### Best Practice

[`InfraredV1_2.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Infrared/src/core/upgrades/InfraredV1_2.sol#L517-L524)

```solidity
function updateFee(ConfigTypes.FeeType _t, uint256 _fee)
    external
    onlyGovernor // 수수료 변경 권한 제한
{
    // 이전 수수료에 대한 정산
    uint256 prevFee = fees(uint256(_t));
    _rewardsStorage().updateFee(_t, _fee);
    emit FeeUpdated(msg.sender, _t, prevFee, _fee);
}
```

[`InfraredV1_5.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Infrared/src/core/upgrades/InfraredV1_5.sol#L21-L41)

```solidity
function claimExternalVaultRewards(address _asset, address user)
        external
        whenNotPaused
    {
        // 보상 수확을 Keeper 권한 한정
        address sender = msg.sender;
        if (!hasRole(KEEPER_ROLE, sender) && sender != user) {
            revert Errors.Unauthorized(sender);
        }
        // ... 중략 ...
    }
```

***

### 위협 3: 악성행위 가능한 토큰을 통한 Bribe 시스템 오염

악성행위 가능성이 있는 토큰을 Bribe 시스템에 보상토큰으로 사용할 경우 Bribe 시스템의 신뢰성과 공정성이 훼손된다. \
이는 결국 정직한 프로토콜의 경쟁력을 약화시키고 생태계의 건전한 인센티브 흐름을 방해한다.

#### 영향도&#x20;

`Low`

시스템 신뢰성과 공정성이 훼손되어 정직한 프로토콜의 경쟁력이 약화될 수 있으나 인센티브 왜곡 및 운영상 문제로 손해가 제한되기 때문에 `Low`로 평가한다.

#### 가이드라인

> * **Curve, Balancer 등의 DeFi 플랫폼의 사례와 마찬가지로 Bribe 시스템에 사용하는 보상 토큰에 대한 화이트리스트 운영하여 시스템 오염 및 신뢰성 저해 방지**
> * **공격자가 소액으로 여러 번의 Bribe를 시도하여 시스템을 교란하는 행위를 방지하기 위해** [**최소 Bribe 금액 한도를 설정**](../../reference.md#bribe-bribe-bribecollector)**하여 남용 방지**\
>   **\[출처:** [Blockchain Bribing Attacks and the Efficacy of Counterincentives](https://arxiv.org/pdf/2402.06352)**]**&#x20;
> * **BribeCollector에 과도한 권한 부여 시 오남용 가능성이 있으므로 최소 권한 원칙을 적용하며, 해당 컨트랙트 사용에 대해 타임락 및 DAO 거버넌스 투표 또는 타임락 기능 적용**

#### Best Practice

[`RewardLib.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Infrared/src/core/libraries/RewardsLib.sol#L569-L600)

```solidity
function harvestBribes(
    RewardsStorage storage $,
    address collector,
    address[] memory _tokens,
    bool[] memory whitelisted
) external returns (address[] memory tokens, uint256[] memory amounts) {
    uint256 len = _tokens.length;
    amounts = new uint256[](len);
    tokens = new address[](len);

    for (uint256 i = 0; i < len; i++) {
        // 화이트리스트 토큰 여부 검증
        if (!whitelisted[i]) continue;
        // ... 중략 ...
    }
}
```

[`BribeCollectorV1_3.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Infrared/src/core/upgrades/BribeCollectorV1_3.sol#L56-L105)

```solidity
function claimFees(
        address _recipient,
        address[] calldata _feeTokens,
        uint256[] calldata _feeAmounts
    ) external onlyKeeper // 보상 수거 실행 권한 Keeper 한정
```

***

### 위협 4: 특정 검증자 자금 집중 현상으로 인한 보상 불균형과 중앙화 발생

소수의 검증자에게 자금이 과도하게 집중되면 이들이 대부분의 보상을 독점하여 다른 검증자들의 참여 의욕을 꺾고 신규 진입을 어렵게 만든다.\
이는 결국 네트워크의 의사결정 권한마저 소수에게 편중시켜 탈중앙성을 해치고 시스템 전체의 안정성과 공정성을 저해하는 결과를 초래한다.

#### 영향도&#x20;

`Informational`&#x20;

소수의 검증자에게 대부분의 보상이 독점되고 네트워크의 의사결정 권한이 편중되어 탈중앙성과 시스템 공정성이 저해될 수 있으나 해당 문제는 구조적·운영상 문제로 직접적인 보안 위협보다는 네트워크 분산성과 참여 유인 저하에 영향을 미치기 때문에 `Informational`로 평가한다.

#### 가이드라인

> * **이더리움, 솔라나 등 주요 PoS 체인에서 제기된 대형 검증자에 대한 자금 집중을 해결하기 위한 검증자 별 최대** [**스테이킹 한도 설정**](../../reference.md#max_effective_balance)**을 통한 보상 불균형 및 중앙화 발생 방지**
> * **검증자의 장기간 비정상 행위로 인한 네트워크 안정성 저해를 방지하기 위해** [**실시간 상태 추적**](../../reference.md#undefined-4)**과 자동 강제 종료 시스템 도입 필요**
> * **리스테이킹이나 신규 위임이 소수 검증자에게 집중될 경우 중앙화와 보상 불균형이 발생할 가능성을 방지하기 위해 자금이 여러 검증자에게** [**자동 분산**](../../reference.md#undefined-5)**되도록 위임 정책 적용**
> * **사용자 참여도 저조로 인한 네트워크 탈중앙성 및 유동성 약화를 방지하기 위해 다양한 활동에 추가 보상을 제공하여 참여와 자금 분산을 촉진**

#### Best Practice

[`InfraredBERADepositor.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Infrared/src/staking/InfraredBERADepositor.sol#L76-L159)

```solidity
function execute(bytes calldata pubkey, uint256 amount)
    external
    onlyKeeper
{
    // ... 중략 ...
    address withdrawor = IInfraredBERA(InfraredBERA).withdrawor();
    // 강제 퇴출된 기존 validator의 자금을 우선 처리
    if (withdrawor.balance >= InfraredBERAConstants.INITIAL_DEPOSIT) {
        revert Errors.HandleForceExitsBeforeDeposits();
    }
    // 검증자 현재 잔액 + 입금 금액 <= 스테이킹 최대 한도 검증
    if (
        IInfraredBERA(InfraredBERA).stakes(pubkey) + amount
            > InfraredBERAConstants.MAX_EFFECTIVE_BALANCE
    ) {
        revert Errors.ExceedsMaxEffectiveBalance();
    }

    address operatorBeacon =
        IBeaconDeposit(DEPOSIT_CONTRACT).getOperator(pubkey);
    address operator = IInfraredBERA(InfraredBERA).infrared();
    if (operatorBeacon != address(0)) {
        if (operatorBeacon != operator) {
            revert Errors.UnauthorizedOperator();
        }
        if (!IInfraredBERA(InfraredBERA).staked(pubkey)) {
            revert Errors.OperatorAlreadySet();
        }
        operator = address(0);
    }

    // ... 중략 ...

    emit Execute(pubkey, amount);
}
```
