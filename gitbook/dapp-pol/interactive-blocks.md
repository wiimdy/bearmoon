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

[`InfraredBERA.sol`](https://github.com/wiimdy/bearmoon/blob/main/Infrared/src/staking/InfraredBERA.sol)

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

***

### 위협 2: 특정 검증자 자금 집중 현상으로 인한 보상 불균형과 중앙화 발생

#### 가이드라인

> * **검증자 별 최대 스테이킹 한도 설정을 통한 보상 불균형 및 중앙화 발생 방지**
> * **검증자 상태 추적 및 강제 종료 감지**
> * **리스테이킹 시 분산 정책 적용**
> * **서비스 내부의 사용자 활동에 따른 추가 보상 시스템을 바탕으로 서비스 참여도 증진 및 유동성 증진을 통한 탈중앙성 강화 유도**

#### Best Practice

[`InfraredBERADepositor.sol`](https://github.com/wiimdy/bearmoon/blob/main/Infrared/src/staking/InfraredBERADepositor.sol)

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

***

### 위협 3: 수수료 변경 전/후 대량 수확을 통한 악성 행위자 이익 극대화

#### 가이드라인

> * **수수료 변경 전 기존 보상 강제 정산을 진행하여 보상 갈취 사전 차단**
> * **수수료 변경과 보상 수확 기능을 실행할 수 있는 권한을 최소화하여 무단 실행 제한**

#### Best Practice

[`InfraredV1_2.sol`](https://github.com/wiimdy/bearmoon/blob/main/Infrared/src/core/upgrades/InfraredV1_2.sol)

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

### 위협 4: 악성행위 가능한 토큰을 통한 Bribe 시스템 오염

#### 가이드라인

> * **Bribe 시스템에 사용하는 보상 토큰에 대한 화이트리스트 운영**
> * **최소 Bribe 금액 한도 설정**
> * **BribeCollector에 대한 관련 권한 제한 처리**

#### Best Practice

[`RewardLib.sol`](https://github.com/wiimdy/bearmoon/blob/main/Infrared/src/core/libraries/RewardsLib.sol)

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

[`BribeCollectorV1_3.sol`](https://github.com/wiimdy/bearmoon/blob/main/Infrared/src/core/upgrades/BribeCollectorV1_3.sol)

```solidity
function claimFees(
        address _recipient,
        address[] calldata _feeTokens,
        uint256[] calldata _feeAmounts
    ) external onlyKeeper // 보상 수거 실행 권한 Keeper 한정
```

***

### 위협 5: 과도한 수수료 설정을 통한 사용자 이익 침해

#### 가이드라인

> * **수수료 변경 과정에서 수수료 한도 검증을 통한 최대 상한선 설정**

#### Best Practice

[`RewardLib.sol`](https://github.com/wiimdy/bearmoon/blob/main/Infrared/src/core/libraries/RewardsLib.sol)

```solidity
function updateFee(
        RewardsStorage storage $,
        ConfigTypes.FeeType _t,
        uint256 _fee
    ) external {
        // 최대 수수료 한도를 통해 급격한 수수료 변경 피해 최소화
        if (_fee > UNIT_DENOMINATOR) revert Errors.InvalidFee();
        $.fees[uint256(_t)] = _fee;
    }
```

