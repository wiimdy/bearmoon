---
icon: sack-dollar
---

# PoL 보안 가이드라인: 보상 분배

### 위협 1: 권한 없는 사용자의 인센티브 토큰 조작 및 사용

인센티브 토큰 관련 권한이 없는 사용자가 토큰 화이트리스트 내용을 조작할 경우 토큰 화이트리스트 내용이 무력화되어 사용자 보상 처리 과정에서 문제가 발생할 수 있다.

#### 가이드라인

> * **인센티브 토큰 화이트리스트 관리 시 `maxIncentiveTokensCount` 제한 및 중복 등록 방지**
> * **incentive rate 설정 시 MIN/MAX 범위 검증 및 매니저 권한 제한**
> * **ERC20 토큰 회수 시 인센티브 토큰 및 예치 토큰을 제외하고 전송**

#### Best Practice&#x20;

[`RewardVault.sol`](https://github.com/berachain/contracts/blob/a405d00920f5b328c69a73b4c2ed4ef3b13adc0d/src/pol/rewards/RewardVault.sol)&#x20;

```solidity
function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyFactoryOwner {
    //recoverERC20에서 incentive token과 staked token 회수 방지
    if (tokenAddress == address(stakeToken)) CannotRecoverStakingToken.selector.revertWith();

    // ...
}

function whitelistIncentiveToken(
    address token,
    uint256 minIncentiveRate,
    address manager
)
    external
    onlyFactoryOwner
{
    // ...
    // MAX_INCENTIVE_RATE 상한선 설정
    if (minIncentiveRate > MAX_INCENTIVE_RATE) IncentiveRateTooHigh.selector.revertWith();

    // ...
    // whitelistedTokens.length == maxIncentiveTokensCount 제한 체크
    if (whitelistedTokens.length == maxIncentiveTokensCount || incentive.minIncentiveRate != 0) {
        TokenAlreadyWhitelistedOrLimitReached.selector.revertWith();
    }
    // ...
}
```

***

### 위협 2: 컨트랙트 초기화 시 잘못된 구성으로 인한 시스템 오류

컨트랙트 초기 배포 과정에서 영(0) 주소 입력 등 필수 검증 절차와 필터링 기능 누락 시 잘못된 설정으로 인한 시스템 오류 발생 가능성이 존재한다.

#### 가이드라인

> * **모든 컨트랙트 초기화 시 zero address 검증 및 필수 매개변수 검증**
> * **초기 설정 매개변수들의 합리적 범위 검증**
> * **genesis deposits root 설정 등 초기 상태의 무결성 보장**
> * **초기화 함수의 멱등성 보장 및 재초기화 방지 메커니즘**
> * **critical parameter 변경을 위한 롤백 메커니즘**

#### Best Practice&#x20;

&#x20;[`BlockRewardController.sol`](https://github.com/berachain/contracts/blob/a405d00920f5b328c69a73b4c2ed4ef3b13adc0d/src/pol/rewards/BlockRewardController.sol)&#x20;

```solidity
// contracts/src/pol/rewards/BlockRewardController.sol
function initialize(
    address _bgt,
    address _distributor,
    address _beaconDepositContract,
    address _governance
)
    external
    initializer
{
    // initialize에서 모든 주소 매개변수 설정 검증
    // _governance 주소에 대한 검증
    __Ownable_init(_governance);
    __UUPSUpgradeable_init();
    // _bgt 주소에 대한 검증
    bgt = BGT(_bgt);
    emit SetDistributor(_distributor);
    // _distributor 주소에 대한 검증
    distributor = _distributor;
    // _beaconDepositContract 주소에 대한 검증
    beaconDepositContract = IBeaconDeposit(_beaconDepositContract);
}
```

&#x20;[`BGT.sol`](https://github.com/berachain/contracts/blob/a405d00920f5b328c69a73b4c2ed4ef3b13adc0d/src/pol/BGT.sol)

```solidity
function initialize(address _owner) external initializer {
    // initialize에서 boost delay를 BOOST_MAX_BLOCK_DELAY로 설정
    // ...
    activateBoostDelay = BOOST_MAX_BLOCK_DELAY;
    dropBoostDelay = BOOST_MAX_BLOCK_DELAY;
}
```

&#x20;[`BeaconDeposit.sol`](https://github.com/berachain/contracts/blob/a405d00920f5b328c69a73b4c2ed4ef3b13adc0d/src/pol/BeaconDeposit.sol)

```solidity
// genesisDepositsRoot 설정으로 초기 상태 정의
/// @dev The hash tree root of the genesis deposits.
/// @dev Should be set in deployment (predeploy state or constructor).
bytes32 public genesisDepositsRoot;
```

***

### 위협 3: BGT redeem 시 Native token 부족으로 인한 유동성 위기

BGT redeem 시 redeem 대상 컨트랙트가 현재 보유하고 있는 Native 토큰의 수량이 부족할 경우 네트워크의 유동성 위기를 초래할 수 있다.

#### 가이드라인

> * **BGT redeem 시 컨트랙트 잔액 검증 및 충분한 native token 보유량 확보**
> * **`burnExceedingReserves` 함수를 통한 초과 reserves 관리 및 적절한 버퍼 유지**
> * **BGT 예상 발행량 계산 시 블록 버퍼 크기와 블록당 BGT 발행량 등 고려한 정확한 예상량 산출**

#### Best Practice&#x20;

&#x20;[`BGT.sol`](https://github.com/berachain/contracts/blob/a405d00920f5b328c69a73b4c2ed4ef3b13adc0d/src/pol/BGT.sol)

```solidity
function redeem(
    address receiver,
    uint256 amount
)
    external
    invariantCheck
    // redeem 함수에서 checkUnboostedBalance modifier로 사용자 잔액 검증
    checkUnboostedBalance(msg.sender, amount)
{
    // ...
}

function burnExceedingReserves() external {
    // ...
    // HISTORY_BUFFER_LENGTH * br.getMaxBGTPerBlock()로 잠재적 민팅량 계산
    uint256 potentialMintableBGT = HISTORY_BUFFER_LENGTH * br.getMaxBGTPerBlock();
    // ...
    // 현재 reserves와 outstanding amount 비교
    if (currentReservesAmount <= outstandingRequiredAmount) return;
    // ...
}

// invariantCheck modifier를 통한 컨트랙트 상태 일관성 검증
/// @notice check the invariant of the contract after the write operation
modifier invariantCheck() {
    /// Run the method.
    _;

    /// Ensure that the contract is in a valid state after the write operation.
    _invariantCheck();
}

function _invariantCheck() private view {
    if (address(this).balance < totalSupply()) InvariantCheckFailed.selector.revertWith();
}
```

***

### 위협 4: 보상 분배 로직 오류로 인한 특정 사용자에게 과도한 보상 지급 또는 보상 누락

#### 가이드라인

> * **95% 코드 커버리지, Fuzz 테스트, 100명 이상 사용자 시뮬레이션 등 구체적 수치 제시**
> * **Python/JavaScript 기반 오프체인 검증 시스템 구현 방안**

#### Best Practice&#x20;

&#x20;[`StakingRewards.sol`](https://github.com/berachain/contracts/blob/a405d00920f5b328c69a73b4c2ed4ef3b13adc0d/src/base/StakingRewards.sol)

```solidity
// contracts/src/pol/rewards/StakingRewards.sol
// -> contracts/base/StakingRewards.sol
function _notifyRewardAmount(uint256 reward)
    internal
    virtual
    // 보상이 추가 될 경우 rewardRate 계산
    _updateReward(address(0))
{
    // ...
}
```

***

### 위협 5: 잘못된 접근 제어로 인한 권한 없는 보상 인출 또는 조작

컨트랙트 접근 제어를 정확하게 처리하지 못할 경우 의도하지 않은 악성 사용자의 접근으로 인한 보상 인출 또는 조작 발생 가능성이 존재한다.

#### 가이드라인

> * **각 함수 및 중요 데이터에 대해 명확한 역할(Owner, Admin, User 등)을 정의, 역할에 따른 접근 권한을 엄격히 부여**
> * **`onlyOwner`, `onlyRole` 등의 modifier를 명확히 사용**&#x20;
> * **관리자 활동(권한 변경, 중요 함수 호출 등)에 대한 이벤트 로깅**

#### Best Practice&#x20;

&#x20;[`RewardVault.sol`](https://github.com/berachain/contracts/blob/a405d00920f5b328c69a73b4c2ed4ef3b13adc0d/src/pol/rewards/RewardVault.sol)

```solidity
function addIncentive(
    address token,
    uint256 amount,
    uint256 incentiveRate
)
    external
    nonReentrant
    onlyWhitelistedToken(token)
{
    // ...
    // incentive rate 변동은 manager 권한만 가능
    if (msg.sender != manager) NotIncentiveManager.selector.revertWith();
    // ...
}

function getReward(
    address account,
    address recipient
)
    external
    nonReentrant
    // reward 수령은 사용자 혹은 사용자가 설정한 operator만 실행 가능
    onlyOperatorOrUser(account)
    returns (uint256)
{
    // ...
}
```

***

### 위협 6: 재진입 공격을 통해 보상 중복 청구

컨트랙트 함수 중 토큰의 흐름을 제어하는 함수에 대한 재진입을 허용할 경우 재진입 공격에 의한 토큰 무단 인출 문제로 시스템 전체의 손해로 이어질 수 있다.

#### 가이드라인

> * **체크-효과-상호작용(Checks-Effects-Interactions) 패턴을 준수**
> * **nonReentrant 가드 사용**

#### Best Practice&#x20;

&#x20;[`RewardVault.sol`](https://github.com/berachain/contracts/blob/a405d00920f5b328c69a73b4c2ed4ef3b13adc0d/src/pol/rewards/RewardVault.sol)

```solidity
function getReward(
    address account,
    address recipient
)
    external
    // nonReentrant 가드 사용
    nonReentrant
    onlyOperatorOrUser(Account)
    returns (uint256)
{
    // ...
}
```

&#x20;[`StakingRewards.sol`](https://github.com/berachain/contracts/blob/a405d00920f5b328c69a73b4c2ed4ef3b13adc0d/src/base/StakingRewards.sol)

```solidity
function _getReward(address account, address recipient)
    internal
    virtual
    updateReward(account) 
    returns (uint256)
{
    // ...
    // unclaimed된 보상을 초기화 하고 trasnfer 진행
    uint256 reward = info.unclaimedReward; // get the rewards owed to the account
    // ...
}
```

***

### 위협 7: Operator들이 담합하여 특정 reward vault에만 BGT 보상을 집중, 유동성 쏠림 및 타 프로토콜 유동성 고갈

Operator들이 담합하여 특정 reward vault에만 BGT 보상을 집중, 유동성 쏠림 및 타 프로토콜 유동성 고갈

#### 가이드라인

> * **여러 종류  Reward vault에게 나눠 주도록 강제**
> * **Operator/Validator reward allocation 변경 시 투명한 로그 기록 및 모니터링**
> * **담합 의심 시 거버넌스/커뮤니티 신고 및 감사 프로세스 마련**
> * **vault별 TVL, APR, 유동성 집중도 실시간 대시보드 제공**

#### Best Practice&#x20;

&#x20;[`BeraChef.sol`](https://github.com/berachain/contracts/blob/a405d00920f5b328c69a73b4c2ed4ef3b13adc0d/src/pol/rewards/BeraChef.sol)

```solidity
function _validateWeights(Weight[] calldata weights) internal view {
    // reward vault당 최대 30% 까지 할당 가능
    if (weights.length > maxNumWeightsPerRewardAllocation) {
        TooManyWeights.selector.revertWith();
    }
    
    // 중복 vault 체크
    _checkForDuplicateReceivers(valPubkey, weights);
    // ...
}
```

***

### 위협 8: 보상 분배 계산 과정 중 나눗셈 연산 정밀도 오류 발생 시 사용자 보상 미세 손실 누적 가능



#### 가이드라인

> * **보상 수령 대상 및 금액의 정확성을 교차 검증하는 로직 추가**
> * **최소 수량 or 최대 수량 설정으로 나눗셈 연산 오류 방지**
> * **사용자 유리한 반올림 정책**

#### Best Practice&#x20;

```solidity
```

***

### 위협 9: Reward Vault Factory Owner가 악의적인 distributor 생성 시 사용자 보상 시스템 문제 발생



#### 가이드라인

> * **악의적인 distributor 변경이 즉각 반영되는 것을 방지하기 위한 타임락 등의 추가 보안 절차 반영 필요**
> * **변경시 다중 서명 거버넌스 (3명 중 2/3 승인) 필요**

#### Best Practice&#x20;

```solidity
```

***

### 위협 10: 인센티브 토큰이 고갈된 뒤에 추가 공급을 하지 않으면 벨리데이터의 Boost Reward 감소



#### 가이드라인

> * **RewardVault 내의 인센티브 토큰 최소 보유량을 제한**
> * **벨리데이터의 경우 BGT를 분배할 reward vault를 선택할때 인센티브 토큰이 충분히 남아있는지 확인**
> * **Reward vault에 인센티브 토큰 얼마나 남았는지 확인하는 대시보드 제작**

#### Best Practice&#x20;

```solidity
```

***

### 위협 11: Incentive token가 고갈 된 후 Incentive rate를 낮춰 해당 vault를 선택한 벨리데이터의 Boost APR 감소



#### 가이드라인

> * **각 함수 및 중요 데이터에 대해 명확한 역할(Owner, Admin, User 등)을 정의, 역할에 따른 접근 권한을 엄격히 부여**
> * **`onlyOwner`, `onlyRole` 등의 modifier를 명확히 사용**
> * **관리자 활동(권한 변경, 중요 함수 호출 등)에 대한 이벤트 로깅**

#### Best Practice&#x20;

&#x20;[`RewardVault.sol`](https://github.com/berachain/contracts/blob/a405d00920f5b328c69a73b4c2ed4ef3b13adc0d/src/pol/rewards/RewardVault.sol)

```solidity
function addIncentive(
    address token,
    uint256 amount,
    uint256 incentiveRate
)
    external
    nonReentrant
    onlyWhitelistedToken(token)
{
    // ...
    // incentive rate 변동은 manager 권한만 가능
    if (msg.sender != manager) NotIncentiveManager.selector.revertWith();
    // ...
}

function getReward(
    address account,
    address recipient
)
    external
    nonReentrant
    // reward 수령은 사용자 혹은 사용자가 설정한 operator만 실행 가능
    onlyOperatorOrUser(account)
    returns (uint256)
{
    // ...
}
```

***

### 위협 12: 보상 분배 중 모든 LP token을 인출하여 잔고를 0으로 만들면 해당 보상 증발



#### 가이드라인

> * **새로운 reward vault를 만들 때는 소량의 초기 LP token을 운영할 주체가 예치(LP가 0 이 되지 않도록) (최소 lp token 설정)**

#### Best Practice&#x20;

```solidity
```

***

### 위협 13: 정상적인 Incentive token 제거에 따른 보상 중단

정상적인 incentive token 제거 시 사용자 보상 중단으로 인한 보상 구조 임의 변경 영향으로 문제 발생 가능성이 존재한다.

#### 가이드라인

> * **`removeIncentiveToken` 함수의 호출 조건에 제한 로직 추가**&#x20;
> * **인센티브 토큰 제거 또는 교체는 거버넌스 승인을 요구하도록 설계**
> * **인센티브 토큰 제거 전, 해당 Vault의 남은 분배량 및 종료 일정 공지**
> * **토큰 제거 시 이벤트 로그 기록 필수 및 대시보드 상 실시간 반영**
> * **Vault의 보상 구조 변경(토큰 추가/제거)은 사용자에게 사전 고지 및 명확한 UI 표시**
> * **보상 토큰 변경 이력은 감사 로그(audit trail) 로 저장, 분기별 커뮤니티 감사 진행**

#### Best Practice&#x20;

```solidity
```

***

### 위협 14: claimFees() 프론트러닝에 따른 사용자의 수수료 보상 왜곡&#x20;

claimFees() 함수를 호출하는 사용자 앞에서 프론트러닝을 통한 트랜잭션 선점 시 수수료 보상 가로채기 또는 인센티브 왜곡이 발생할 수 있다.

#### 가이드라인

> * **`claimFees()` 호출 시 프론트러닝 방지를 위해 수수료 계산 기준이 되는 블록 넘버/타임스탬프를 내부 저장하고 호출자 기준으로 고정하여 외부 간섭 방지 or 클레임 대상 사용자 주소 명시 필드 활용**
> * **$HONEY 등 Fee Token 잔고가 급변할 경우 이상 징후 탐지 및 임시 정지 로직(safeguard) 활성화**
> * **수수료 누적/청구/소진 과정은 이벤트 로그를 통한 추적이 가능해야 하며, 이상 징후 발생 시 자동 경고를 발생시키는 보상 모니터링 시스템 구축**
> * **클레임 가능한 수수료 토큰 종류는 허용된 화이트리스트기반으로 제한**

#### Best Practice&#x20;

```solidity
```

***

### 위협 15: dApp 프로토콜의 Fee Token 송금 누락에 따른 사용자 보상 실패

dApp 프로토콜의 Fee Token 송금 누락 시 user가 claimFees를 호출해도 정상적인 Fee를 받을 수 없어 BGT Staker의 $HONEY 보유량 감소로 BGT 예치자의 보상 수령 과정에서 문제가 발생할 수 있다.

#### 가이드라인

> * **FeeCollector와 dApp 간 수수료 정산 상태(누적/미정산)를 주기적으로 확인하는 오프체인 모니터링 시스템 도입**
> * **일정 기간 동안 수수료 송금이 누락된 dApp은 해당 vualt의 인센티브 대상에서 제외하거나 거버넌스를 통해 보상 삭감/정지 등의 제재가 가능하도록 설계**
> * **`claimFees()` 호출 시, payoutAmount가 200 HONEY(=1%) 이하일 경우 명확한 revert 사유 및 UI 피드백 제공**

#### Best Practice&#x20;

```solidity
```

***

### 위협 16: 토큰 승인 검증 부재 및 ERC-20 표준 미검증으로 인한 위협

화이트리스트 토큰에 대한 ERC20 표준 준수 여부 등의 검증 절차 누락 시 네트워크 보상 처리 과정에서 의도하지 않은 악성 행위로 인해 문제가 발생할 수 있다.

**가이드라인**

> * **안전한 토큰 승인 및 전송**
>   * **거래별 정확한 승인량 계산 및 설정**
>   * **승인량과 실제 사용량 일치 검증**
>   * **모든 토큰 전송 후 반환값 검증 및 전송 실패 시 전체 롤백**
> * **토큰 표준 호환성 검증**
>   * **ERC-20 표준 준수 여부 사전 검증**
> * **토큰 화이트리스트 관리**
>   * **지원 토큰 사전 심사 및 승인 절차**
>   * **악성 토큰 블랙리스트 운영 및 실시간 업데이트**

#### Best Practice&#x20;

&#x20;[`RewardVault.sol`](https://github.com/berachain/contracts/blob/a405d00920f5b328c69a73b4c2ed4ef3b13adc0d/src/pol/rewards/RewardVault.sol)

```solidity
// 토큰 화이트리스트 관리
address[] public whitelistedTokens;

// ...
// 인센티브 토큰 보상해야하는 로직에서 보상 대상 토큰이 화이트리스트에 포함되어있는지 제한자로 확인
modifier onlyWhitelistedToken(address token) {
    if (incentives[token].minIncentiveRate == 0) TokenNotWhitelisted.selector.revertWith();
    _;
}

function addIncentive(
    address token,
    uint256 amount,
    uint256 incentiveRate
)
    external
    nonReentrant
    onlyWhitelistedToken(token)
{
    // ...
    // 토큰 전송 처리를 안전하게 수행할 수 있는 SafeERC20 라이브러리 함수 사용
    IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    // ...
}
```

***

### 위협 17: 인센티브 분배 대상 선정 로직 오류

인센티브 분배기에서 분배 설정 시 누락 또는 미검증된 설정으로 인해 인센티브 분배 처리 과정에서 문제가 발생할 수 있다.

#### 가이드라인

> * **인센티브 분배기에 필요한 각종 기능에 대한 권한을 거버넌스 구조로 역할 분리**
> * **인센티브 분배 설정 변경 시 이중 검증 실시**
> * **설정 변경 후 실제 적용에 시간차를 두기 위한 시간 지연 로직 구현**

#### Best Practice&#x20;

&#x20;[`BGTIncentiveDistributor.sol`](https://github.com/berachain/contracts/blob/a405d00920f5b328c69a73b4c2ed4ef3b13adc0d/src/pol/rewards/BGTIncentiveDistributor.sol)&#x20;

```solidity
// 인센티브 분배기 역할별 권한 분리
bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

// ...
function initialize(address _governance) external initializer {
    __AccessControl_init();
    __Pausable_init();
    __ReentrancyGuard_init();
    __UUPSUpgradeable_init();
    if (_governance == address(0)) ZeroAddress.selector.revertWith();
    _grantRole(DEFAULT_ADMIN_ROLE, _governance);
    // ...
}
```

&#x20;[`BeraChef.sol`](https://github.com/berachain/contracts/blob/a405d00920f5b328c69a73b4c2ed4ef3b13adc0d/src/pol/rewards/BeraChef.sol)&#x20;

```solidity
function queueNewRewardAllocation(
    bytes calldata valPubkey,
    uint64 startBlock,
    Weight[] calldata weights
)
    external
    onlyOperator(valPubkey)
{
    // 인센티브 분배 설정 변경 후 실제 지연에 시간차를 두기 위한 시간 지연 로직 구현
    if (startBlock <= block.number + rewardAllocationBlockDelay) {
        InvalidStartBlock.selector.revertWith();
    }
    // ...
}

// 허용된 인센티브 분배 대상을 분류하기 위한 화이트리스트 토큰, 볼트 주소 관리
function setVaultWhitelistedStatus(
    address receiver,
    bool isWhitelisted,
    string memory metadata
)
    external
    onlyOwner
{
    // ...
}
```

***

### 위협 18: 분배 비율 또는 기간 설정 오류로 인한 과도/과소 인센티브 지급

인센티브 분배 비율, 분배 기간 설정 과정에서 미흡한 설정이 적용될 경우 인센티브가 과도/과소 지급될 가능성이 있다.

#### 가이드라인

> * **시간 기반 분배 로직 처리 과정에서 블록 타임스탬프 의존성 최소화**
> * **인센티브 연산 과정에서 안전한 시간 연산을 위해 검증된 수학 계산 라이브러리 사용**

#### Best Practice&#x20;

&#x20;[`StakingRewards.sol`](https://github.com/berachain/contracts/blob/a405d00920f5b328c69a73b4c2ed4ef3b13adc0d/src/base/StakingRewards.sol)

```solidity
function _notifyRewardAmount(uint256 reward) internal virtual updateReward(address(0)) {
    reward = reward * PRECISION;
    
    // 조건부 시간 계산을 위해 안전성이 보장된 상황에서만 시간 차이를 계산
    if (totalSupply != 0 && block.timestamp < periodFinish) {
        reward += _computeLeftOverReward();
    }
    
    // ...
}

function rewardPerToken() public view virtual returns (uint256) {
    //...
    // 리워드 최솟값과 토큰 계산 과정에서 안전한 연산을 위한 FixedPointMathLib 라이브러리 사용
    // computes reward per token by rounding it down to avoid reverting '_getReward' with insufficient rewards
    uint256 _newRewardPerToken = 
    FixedPointMathLib.fullMulDiv(rewardRate, timeDelta, _totalSupply);
    return rewardPerTokenStored + _newRewardPerToken;
}
```

[`BeraChef.sol`](https://github.com/berachain/contracts/blob/a405d00920f5b328c69a73b4c2ed4ef3b13adc0d/src/pol/rewards/BeraChef.sol)

```solidity
function queueNewRewardAllocation(
    bytes calldata valPubkey,
    uint64 startBlock,
    Weight[] calldata weights
)
    external
    onlyOperator(valPubkey)
{
    // 블록 번호 기반 지연 처리를 이용한 타임스탬프 조작 공격 방지
    if (startBlock <= block.number + rewardAllocationBlockDelay) {
        InvalidStartBlock.selector.revertWith();
    }
    // ...
}
```

&#x20;[`BGTIncentiveDistributor.sol`](https://github.com/berachain/contracts/blob/a405d00920f5b328c69a73b4c2ed4ef3b13adc0d/src/pol/rewards/BGTIncentiveDistributor.sol)

```solidity
uint64 public constant MAX_REWARD_CLAIM_DELAY = 3 hours;

// ...

function _setRewardClaimDelay(uint64 _delay) internal {
    // MAX_REWARD_CLAIM_DELAY 지정을 통한 타임스탬프 기반 지연 시간 최소화
    if (_delay > MAX_REWARD_CLAIM_DELAY) {
        InvalidRewardClaimDelay.selector.revertWith();
    }
    rewardClaimDelay = _delay;
    emit RewardClaimDelaySet(_delay);
}
```

***

### 위협 19: 권한 없는 사용자의 인센티브 풀 무단 인출&#x20;

인센티브 분배 관련 권한이 없는 사용자가 인센티브 풀을 무단으로 인출할 경우 사용자 인센티브 처리 과정에 문제가 발생할 수 있다.

#### 가이드라인

> * **인센티브 토큰과 연관된 스테이킹 토큰마다 별도의 RewardVault를 생성 및 검증된 Reward Vault만 운영할 수 있는 별도의 관리 기준 운영**
> * **인센티브 토큰 보상 정보를 독립적으로 관리할 수 있는 로직 추가**
> * **인센티브 토큰 지급 Vault 별 분산된 권한 관리를 위한 계층적 권한 구조 적용**

#### Best Practice

&#x20;[`RewardVault.sol`](https://github.com/berachain/contracts/blob/a405d00920f5b328c69a73b4c2ed4ef3b13adc0d/src/pol/rewards/RewardVault.sol)

```solidity
// 오프체인 거버넌스 포럼 검증을 통한 허가된 Vault만 인센티브 보상을 제공하는 방식 제공 (향후 온체인 구현 필요)
// 각 인센티브 토큰 정보를 별도의 구조체(struct Incentive)로 관리
struct Incentive {
    uint256 minIncentiveRate;
    uint256 incentiveRate;
    uint256 amountRemaining;
    address manager; // 인센티브 토큰 별 정확한 잔액 추적과 관리자 지정을 위한 구조체 내 변수 지정
}

// ...

function initialize(
    address _beaconDepositContract,
    address _bgt,
    address _distributor,
    address _stakingToken
)
    external
    initializer
{
    // Vault에 필요한 계층적 권한 구조를 지정하여 관리자 역할 구분
    __FactoryOwnable_init(msg.sender);
    __Pausable_init();
    __ReentrancyGuard_init();
    __StakingRewards_init(_stakingToken, _bgt, 3 days);
    // ...
}
```

***

### 위협 20: Validator operator의 인센티브 분배 직전 queue 조작을 통한 commission 탈취 및 사용자 분배 손실

validator 운영자가 인센티브 분배 직전 인센티브 분배 큐를 조작하여 commission을 탈취하게 될 경우 분배될 사용자 인센티브에 대해 손해가 발생할 수 있다.

#### 가이드라인

> * **인센티브 분배 로그 분석을 통한 현황 추적**
> * **악의적인 validator slashing**

#### Best Practice&#x20;

&#x20;[`RewardVault.sol`](https://github.com/berachain/contracts/blob/a405d00920f5b328c69a73b4c2ed4ef3b13adc0d/src/pol/rewards/RewardVault.sol)

```solidity
function _processIncentives(bytes calldata pubkey, uint256 bgtEmitted) internal {
    // ...
    // BGT Booster와 Validator 몫에 대한 로깅을 이중으로 수행
    // 인센티브 처리 성공/실패 이력 모두 로깅 수행
    unchecked {
        // ...
            if (validatorShare > 0) {
                // ...
                
                if (success) {
                    // ... 
                    emit IncentivesProcessed(pubkey, token, bgtEmitted, validatorShare);
                } else {
                    emit IncentivesProcessFailed(pubkey, token, bgtEmitted, validatorShare);
                }
            }
        // ...
            if (amount > 0) {
                // ...
                if (success) {
                    // ...
                    if (success) {
                        amountRemaining -= amount;
                        emit BGTBoosterIncentivesProcessed(pubkey, token, bgtEmitted, amount);
                    } else {
                        // ...
                        emit BGTBoosterIncentivesProcessFailed(pubkey, token, bgtEmitted, amount);
                    }
                }
                else {
                    emit BGTBoosterIncentivesProcessFailed(pubkey, token, bgtEmitted, amount);
                }
            }
        / /...
    }
    
    // ...
}
```

&#x20;[`BeraChef.sol`](https://github.com/berachain/contracts/blob/a405d00920f5b328c69a73b4c2ed4ef3b13adc0d/src/pol/rewards/BeraChef.sol)

```solidity
function activateQueuedValCommission(bytes calldata valPubkey) external {
    // ...
    // 악의적인 validator 탐지를 위한 ValCommissionSet 등의 이벤트 처리기로 이력 추적 진행    
    emit ValCommissionSet(valPubkey, oldCommission, commissionRate);
    // ...
}

function _getOperatorCommission(bytes calldata valPubkey) internal view returns (uint96) {
    // validator의 공개키로 인센티브 수량 계산 전 수령 유효성 확인
    CommissionRate memory operatorCommission = valCommission[valPubkey];
    // ...
}
```

***

### 위협 21: $BGT 토큰 배출량 계산 오류 및 가중치 조작을 통한 인플레이션 유발

$BGT 토큰의 배출 계산식 자체에 결함이 발생하거나 emission 관련 수식 변수 요소에 대한 조작을 시도할 시 예상치를 벗어난 의도하지 않은 인플레이션 발생 가능성이 있다.

#### 가이드라인

> * **모든 중요 파라미터 변경은 거버넌스 투표를 통해서만 가능하도록 제한**
> * **보상 계산 파라미터 변경 시 점진적 변화만 허용하도록 상한선 및 하한선 설정**
> * **실시간 보상 배출량 모니터링 시스템 구축 및 이상 징후 감지 메커니즘 설정**
> * **심각한 계산 오류 발생 시 즉시 대응하기 위한 긴급 조치 프로토콜 마련**
> * **보상 계산식에 대한 명확한 문서화와 커뮤니티 이해를 위한 시각화 자료 제공**

#### Best Practice&#x20;

```solidity
```
