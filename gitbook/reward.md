---
icon: sack-dollar
---

# PoL 보안 가이드라인: 보상 분배

<table><thead><tr><th width="617.40625">위협</th><th align="center">영향도</th></tr></thead><tbody><tr><td><a data-mention href="reward.md#id-1">#id-1</a></td><td align="center"><code>High</code></td></tr><tr><td><a data-mention href="reward.md#id-2">#id-2</a></td><td align="center"><code>Medium</code></td></tr><tr><td><a data-mention href="reward.md#id-3">#id-3</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="reward.md#id-4">#id-4</a></td><td align="center"><code>Medium</code></td></tr><tr><td><a data-mention href="reward.md#id-5">#id-5</a></td><td align="center"><code>High</code></td></tr><tr><td><a data-mention href="reward.md#id-6">#id-6</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="reward.md#id-7">#id-7</a></td><td align="center"><code>High</code></td></tr><tr><td><a data-mention href="reward.md#id-8-lp-notifyrewardamount">#id-8-lp-notifyrewardamount</a></td><td align="center"><code>Medium</code></td></tr><tr><td><a data-mention href="reward.md#id-9">#id-9</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="reward.md#id-10-erc-20">#id-10-erc-20</a></td><td align="center"><code>Medium</code></td></tr></tbody></table>

### 위협 1: 권한 없는 사용자의 인센티브 토큰 조작 및 사용

권한이 없는 사용자가 인센티브 토큰을 임의로 추가하거나 중복 등록하여, 시스템에서 과도한 보상을 받는 상황이 발생할 수 있다. 화이트리스트와 토큰 개수 제한, 중복 방지 로직이 없다면 악의적 사용자가 인센티브 구조를 교란시킬 수 있다.

#### 가이드라인

> * **인센티브 토큰 화이트리스트 관리 시 인센티브 토큰 개수 제한 및 중복 등록 방지**
> * **보상 비율 설정 시 최대/최소 범위 검증 및 매니저 권한 제한**
> * **ERC20 토큰 회수 시 인센티브 토큰 및 예치 토큰을 제외하고 전송**

#### Best Practice&#x20;

[`RewardVault.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/pol/rewards/RewardVault.sol#L164-L174)&#x20;

```solidity
function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyFactoryOwner {
    //recoverERC20에서 인센티브 토큰과 예치 토큰 회수 방지
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
    // 인센티브 토큰 종류 상한선 제한 체크
    if (minIncentiveRate > MAX_INCENTIVE_RATE) IncentiveRateTooHigh.selector.revertWith();

    // ...
    // 인센티브 토큰 종류 상한선 제한 체크
    if (whitelistedTokens.length == maxIncentiveTokensCount || incentive.minIncentiveRate != 0) {
        TokenAlreadyWhitelistedOrLimitReached.selector.revertWith();
    }
    // ...
}
```

***

### 위협 2: 컨트랙트 초기화 시 잘못된 구성으로 인한 시스템 오류

컨트랙트 초기 배포 과정에서 필수 검증 절차와 필터링 기능 누락 시 잘못된 설정으로 인한 시스템 오류 발생 가능성이 존재한다.

#### 가이드라인

> * **모든 컨트랙트 초기화 시 zero address 검증 및 필수 매개변수 검증**
> * **초기 설정 매개변수들의 합리적 범위 검증**
> * **초기 예치 루트 설정 등 초기 상태의 무결성 보장**
> * **초기화 함수의 불변성 보장 및 재초기화 방지 메커니즘**
> * **주요 파라미터 변경을 위한 롤백 메커니즘**&#x20;

#### Best Practice&#x20;

&#x20;[`BlockRewardController.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/pol/rewards/BlockRewardController.sol#L71-L88)&#x20;

```solidity
function initialize(
    address _bgt,
    address _distributor,
    address _beaconDepositContract,
    address _governance
)
    external
    initializer
{
    // 초기화 과정에서 모든 주소 매개변수 설정 검증
    // _governance 주소 설정
    __Ownable_init(_governance);
    __UUPSUpgradeable_init();
    // _bgt 주소 설정
    bgt = BGT(_bgt);
    emit SetDistributor(_distributor);
    // _distributor 주소 설정
    distributor = _distributor;
    // _beaconDepositContract 주소 설정
    beaconDepositContract = IBeaconDeposit(_beaconDepositContract);
}
```

&#x20;[`BGT.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/pol/BGT.sol#L117-L123)

```solidity
function initialize(address _owner) external initializer {
    // 부스트 딜레이 초기값을 BOOST_MAX_BLOCK_DELAY로 설정
    // ...
    activateBoostDelay = BOOST_MAX_BLOCK_DELAY;
    dropBoostDelay = BOOST_MAX_BLOCK_DELAY;
}
```

&#x20;[`BeaconDeposit.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/pol/BeaconDeposit.sol#L57)

```solidity
// 초기 루트 상태 정의
bytes32 public genesisDepositsRoot;
```

***

### 위협 3: 보상 분배 로직 오류로 인한 특정 사용자에게 과도한 보상 지급 또는 보상 누락

보상 분배 로직에 버그가 있어 특정 사용자에게 과도한 보상이 지급되거나, 일부 사용자가 보상을 받지 못하는 상황이 발생한다.

#### 가이드라인

> * **95% 코드 커버리지, Fuzz 테스트 등 구체적 수치 제시**
> * **Python/JavaScript 기반 오프체인 검증 시스템 구현 방안**

#### Best Practice&#x20;

&#x20;[`StakingRewards.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/base/StakingRewards.sol#L107)

```solidity
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

### 위협 4: 잘못된 접근 제어로 인한 권한 없는 보상 인출 또는 조작

컨트랙트 접근 제어를 정확하게 처리하지 못할 경우 의도하지 않은 악성 사용자의 접근으로 인한 보상 인출 또는 조작 발생 가능성이 존재한다.

#### 가이드라인

> * **각 함수 및 중요 데이터에 대해 명확한 역할(Owner, Admin, User 등)을 정의, 역할에 따른 접근 권한을 엄격히 부여**
> * **`onlyOwner`, `onlyRole`등의 modifier를 명확히 사용**&#x20;
> * **관리자 활동(권한 변경, 중요 함수 호출 등)에 대한 이벤트 로깅**

#### Best Practice&#x20;

&#x20;[`RewardVault.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/pol/rewards/RewardVault.sol#L373)

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
    // 보상 비율 변동은 manager 권한만 가능
    if (msg.sender != manager) NotIncentiveManager.selector.revertWith();
    // ...
}

function getReward(
    address account,
    address recipient
)
    external
    nonReentrant
    // 보상 수령은 운영자 혹은 운영자가 설정한 사용자만 실행 가능
    onlyOperatorOrUser(account)
    returns (uint256)
{
    // ...
}
```

***

### 위협 5: 재진입 공격을 통해 보상 중복 청구

컨트랙트 함수 중 토큰의 흐름을 제어하는 함수에 대한 재진입을 허용할 경우 재진입 공격에 의한 토큰 무단 인출 문제로 시스템 전체의 손해로 이어질 수 있다.

#### 가이드라인

> * **체크-효과-상호작용(Checks-Effects-Interactions) 패턴을 준수**
> * **nonReentrant 가드 사용**

#### Best Practice&#x20;

&#x20;[`RewardVault.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/pol/rewards/RewardVault.sol#L336)

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

&#x20;[`StakingRewards.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/base/StakingRewards.sol#L139)

```solidity
function _getReward(address account, address recipient)
    internal
    virtual
    updateReward(account) 
    returns (uint256)
{
    // ...
    // 미수령된 보상을 초기화 하고 전송 진행
    uint256 reward = info.unclaimedReward;
    // ...
}
```

***

### 위협 6: 보상 분배 계산 과정 중 나눗셈 연산 정밀도 오류 발생 시 사용자 보상 미세 손실 누적 가능

보상 분배 계산 중 나눗셈 정밀도 오류로 인해, 일부 사용자의 보상이 소수점 이하로 계속 손실되어 누적된다.

#### 가이드라인

> * **보상 수령 대상 및 금액의 정확성을 교차 검증하는 로직 추가**
> * **최소 수량 or 최대 수량 설정으로 나눗셈 연산 오류 방지**
> * **사용자 유리한 반올림 정책**

#### Best Practice&#x20;

`커스텀 코드`

```solidity
// 기존 RewardVault.sol의 _processIncentives 함수 개선
contract RewardVault is ... {
    // ... 기존 코드 ...
    
    // 가이드라인 2: 최소/최대 수량 설정
    uint256 private constant MIN_INCENTIVE_AMOUNT = 1e6; // dust 방지
    uint256 private constant MAX_INCENTIVE_RATE = 1e36; // 기존 코드에 이미 있음
    
    // 기존 _processIncentives 함수 개선
    function _processIncentives(bytes calldata pubkey, uint256 bgtEmitted) internal {
        // ... 기존 코드 ...
        
        for (uint256 i; i < whitelistedTokensCount; ++i) {
            // ...
            
            // 기존: uint256 amount = FixedPointMathLib.mulDiv(bgtEmitted, incentive.incentiveRate, PRECISION);
            // 개선: 정밀도 유지 + 최소값 보장
            uint256 amount = FixedPointMathLib.mulDiv(bgtEmitted, incentive.incentiveRate, PRECISION);
            
            // 가이드라인 2: 최소 수량 보장 (dust 방지)
            if (amount > 0 && amount < MIN_INCENTIVE_AMOUNT) {
                amount = MIN_INCENTIVE_AMOUNT;
            }
            
            uint256 amountRemaining = incentive.amountRemaining;
            amount = FixedPointMathLib.min(amount, amountRemaining);
            
            // 가이드라인 1: 교차 검증 추가
            uint256 validatorShare;
            if (amount > 0) {
                validatorShare = beraChef.getValidatorIncentiveTokenShare(pubkey, amount);
                
                // 검증: validator share가 전체 amount를 초과하지 않는지 확인
                require(validatorShare <= amount, "Invalid share calculation");
                
                amount -= validatorShare;
            }
            
            // ... 나머지 코드 ...
        }
    }
    
    // ... 기존 코드 ...
}
```

```solidity
// 기존 StakingRewards.sol의 earned 함수 개선
contract StakingRewards is ... {
    // ... 기존 코드 ...
    
    // 가이드라인 3: 사용자 유리한 반올림
    function earned(address account) public view virtual returns (uint256) {
        Info storage info = _accountInfo[account];
        // ... 기존 코드 ...
        
        // 기존: return unclaimedReward + FixedPointMathLib.fullMulDiv(balance, rewardPerTokenDelta, PRECISION);
        // 개선: 사용자에게 유리한 반올림 적용
        uint256 earnedAmount = FixedPointMathLib.fullMulDiv(balance, rewardPerTokenDelta, PRECISION);
        
        // 잔액이 있지만 계산 결과가 0인 경우 최소값 보장
        if (balance > 0 && earnedAmount == 0 && rewardPerTokenDelta > 0) {
            earnedAmount = 1; // 최소 1 wei 보장
        }
        
        return unclaimedReward + earnedAmount;
    }
    
    // 가이드라인 1: 보상 계산 검증 함수 추가
    function _verifyRewardCalculation(uint256 reward, uint256 totalSupply) internal pure {
        // 역계산으로 정확성 검증
        if (totalSupply > 0 && reward > 0) {
            uint256 reverseCalc = FixedPointMathLib.fullMulDiv(reward, PRECISION, totalSupply);
            // 오차가 0.01% 이내인지 확인
            require(reverseCalc <= rewardRate * 10001 / 10000, "Calculation error");
        }
    }
    
    // ... 기존 코드 ...
}
```

***

### 위협 7: 보상 금고 팩토리 관리자가 악의적인 분배자 생성 시 사용자 보상 시스템 문제 발생

보상 금고 팩토리 관리자가 악의적으로 분배자를 변경할 경우 사용자 보상 시스템이 즉시 영향을 받아 보상 분배 흐름이 비정상적으로 바뀌어 피해가 발생할 수 있다&#x20;

#### 가이드라인

> * **악의적인 분배자 변경이 즉각 반영되는 것을 방지하기 위한 타임락 등의 추가 보안 절차 반영 필요**
> * **변경시 다중 서명 거버넌스 필요**

#### Best Practice&#x20;

`커스텀 코드`

```solidity
// 기존 RewardVault.sol의 setDistributor 함수 개선
contract RewardVault is ... {
    // ... 기존 코드 ...
    
    // 가이드라인 1: 타임락 추가
    struct PendingDistributor {
        address newDistributor; // 신규 distributor
        uint256 executeAfter;   // Timelock 해제 시간 지정
    }
    
    PendingDistributor public pendingDistributor; // Timelock을 위한 구조체 변수
    uint256 constant TIMELOCK_DELAY = 2 days; // Timelock 기간
    
    // 기존 함수 수정: 즉시 변경 대신 타임락 적용
    /// @inheritdoc IRewardVault
    function setDistributor(address _rewardDistribution) external onlyFactoryOwner {
        if (_rewardDistribution == address(0)) ZeroAddress.selector.revertWith();
        
        // 기존: distributor = _rewardDistribution;  // 즉시 변경
        // 개선: 타임락 적용
        pendingDistributor = PendingDistributor({
            newDistributor: _rewardDistribution,
            executeAfter: block.timestamp + TIMELOCK_DELAY
        });
        
        emit DistributorChangeRequested(_rewardDistribution, block.timestamp + TIMELOCK_DELAY);
    }
    
    // 새로운 함수: 타임락 경과 후 실행
    function executeDistributorChange() external {
        require(pendingDistributor.executeAfter != 0, "No pending change");
        require(block.timestamp >= pendingDistributor.executeAfter, "Timelock active");
        
        distributor = pendingDistributor.newDistributor;
        emit DistributorSet(pendingDistributor.newDistributor);
        
        delete pendingDistributor;
    }
    
    // ... 나머지 코드 ...
}
```

```solidity
// 가이드라인 2: RewardVaultFactory에 다중서명 추가
contract RewardVaultFactory is ... {
    // ... 기존 코드 ...
    
    // 다중서명을 위한 추가 상태 변수
    // vault => governor => approved
    mapping(address => mapping(address => bool)) public distributorApprovals; 
    
    // vault => count
    mapping(address => uint256) public approvalCount; 
    
    // 기존 AccessControl 역할 활용
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    // 거버넌스 정족 수 확인
    uint256 constant REQUIRED_APPROVALS = 2;
    
    // RewardVault의 distributor 변경 승인
    function approveDistributorChange(address vault) external onlyRole(GOVERNOR_ROLE) {
        RewardVault rewardVault = RewardVault(vault);
        
        // distributor 주소 zero address 여부 확인
        require(rewardVault.pendingDistributor().newDistributor != address(0), "No pending change");
        // distributor 승인 여부 확인
        require(!distributorApprovals[vault][msg.sender], "Already approved");
        
        // distributor 승인 처리
        distributorApprovals[vault][msg.sender] = true;
        // 현재 보상 금고의 distributor 승인 수 증가
        approvalCount[vault]++;
        
        // 2/3 승인 달성 시 실행 가능
        if (approvalCount[vault] >= REQUIRED_APPROVALS) {
            emit DistributorChangeApproved(vault);
        }
    }
    
    // ... 나머지 코드 ...
}
```

***

### 위협 8: LP 토큰 전량 인출 및 notifyRewardAmount 호출로 인한 보상 중복 누적

`notifyRewardAmount` 호출 후 모든 LP 토큰을 인출해 잔고를 0으로 만들면 보상 잔액이 두 번 누적되어 보상 총액 기록이 비정상적으로 증가할 수 있다.&#x20;

이후 스테이킹이 재개되면 APR이 급등하고 allowance가 부족할 경우 InsolventReward revert가 발생할 수 있다. \
반대로 LP 토큰 잔고가 0인 상태에서 `notifyRewardAmount`가 먼저 실행되면 보상 잔액이 다음으로 이월되지 않아 해당 보상이 증발할 수 있다.

#### 가이드라인

> * **notifyRewardAmount 호출 시 LP 토큰 잔고가 0인 경우, 보상 누적 또는 이월을 제한하고 명확한 revert 사유를 제공해야 함.**
> * **보상 총액 기록이 중복 누적되지 않도록 `notifyRewardAmount`와 LP 인출 간의 상호작용에 대한 상태 검증 로직을 추가.**
> * **LP 토큰 전량 인출 시 보상 분배 및 이월 정책을 명확히 정의하고 사용자에게 사전 안내.**
> * **APR 급등 및 revert 발생 가능성을 사전에 감지하여 스테이킹 재개 시 보상 분배를 일시적으로 제한하거나 관리자 승인 절차를 거치도록 설계.**
> * **보상 분배 및 이월 관련 이벤트를 모두 기록하여 이상 징후 발생 시 신속하게 감사 및 롤백이 가능하도록 시스템화.**

#### Best Practice&#x20;

`커스텀 코드`

```solidity
// 최소 LP 토큰 예치 요구사항 적용
contract RewardVaultFactory {
    // ... 기존 코드 ...
    
    // 최소 LP 토큰 예치량 설정
    uint256 public constant MIN_INITIAL_LP_AMOUNT = 1e18; // 예: 1 LP 토큰
    
    // 초기 LP 예치 여부 추적
    mapping(address => bool) public initialLPDeposited;
    
    // 기존 createRewardVault 함수 수정
    function createRewardVault(
        address stakingToken,
        uint256 initialLPAmount
    ) external returns (address) {
        // ... 기존 검증 로직 ...
        
        // 최소 LP 토큰 예치량 검증
        require(initialLPAmount >= MIN_INITIAL_LP_AMOUNT, "Initial LP too low");
        
        // vault 생성
        address vault = LibClone.deployDeterministicERC1967BeaconProxy(beacon, salt);
        
        // ... vault 초기화 ...
        
        // 초기 LP 토큰 예치
        IERC20(stakingToken).safeTransferFrom(msg.sender, vault, initialLPAmount);
        RewardVault(vault).depositInitialLP(initialLPAmount);
        
        initialLPDeposited[vault] = true;
        emit InitialLPDeposited(vault, stakingToken, initialLPAmount);
        
        return vault;
    }
    
    // ... 기존 코드 ...
}
```

```solidity
contract RewardVault is RewardVault {
    // ... 기존 코드 ...
    
    uint256 public immutable MIN_LP_THRESHOLD; // LP 토큰 최소 임계 수량 변수
    address public initialLPProvider; // 초기 LP 토큰 공급자 주소
    
    // 초기화 시 최소 LP 설정
    function initialize(
        address _beaconDepositContract,
        address _bgt,
        address _distributor,
        address _stakingToken,
        uint256 _minLPThreshold
    ) external initializer {
        // ... 기존 초기화 로직 ...
        
        MIN_LP_THRESHOLD = _minLPThreshold; // LP 토큰 최소 임계 수량 지정
    }
    
    // 초기 LP 예치 처리 (factory만 호출 가능)
    function depositInitialLP(uint256 amount) external {
        require(msg.sender == factory(), "Only factory");
        require(initialLPProvider == address(0), "Already initialized");
        
        initialLPProvider = tx.origin; // LP 토큰 공급자 주소 설
        _stake(address(this), amount); // vault 자체가 보유
        
        emit InitialLPDeposited(amount);
    }
    
    // withdraw 함수 수정
    function _withdraw(address account, uint256 amount) internal override {
        // ... 기존 코드 ...
        
        // LP 토큰이 최소 임계값 이상 유지되는지 확인
        require(
            totalSupply - amount >= MIN_LP_THRESHOLD,
            "Cannot withdraw below minimum LP"
        );
        
        // ... 나머지 withdraw 로직 ...
    }
    
    // 초기 LP 제공자만 초기 LP를 회수할 수 있음 (비상 상황용)
    function recoverInitialLP() external {
        require(msg.sender == initialLPProvider, "Not initial provider");
        require(totalSupply > MIN_LP_THRESHOLD * 2, "Insufficient total LP");
        
        uint256 initialStake = balanceOf(address(this));
        _withdraw(address(this), initialStake);
        stakeToken.safeTransfer(initialLPProvider, initialStake);
        
        emit InitialLPRecovered(initialStake);
    }
    
    // ... 기존 코드 ...
}
```

***

### 위협 9: 정상적인 인센티브 토큰 제거에 따른 보상 중단

정상적인 인센티브 토큰 제거 시 갑작스러운 사용자 보상 중단으로 인한 사용자 혼란이 발생할 수 있고 보상 구조의 변경으로 인한 문제 발생 가능성이 존재한다.

#### 가이드라인

> * **`removeIncentiveToken` 함수의 호출 조건에 제한 로직 추가**&#x20;
> * **인센티브 토큰 제거 또는 교체는 거버넌스 승인을 요구하도록 설계**
> * **인센티브 토큰 제거 전, 해당 보상 금고의 남은 분배량 및 종료 일정 공지**
> * **토큰 제거 시 이벤트 로그 기록 필수 및 대시보드 상 실시간 반영**
> * **보상 금고의 보상 구조 변경(토큰 추가/제거)은 사용자에게 사전 고지 및 명확한 UI 표시**
> * **보상 토큰 변경 이력은 감사 로그로 저장, 분기별 커뮤니티 감사 진행**

#### Best Practice&#x20;

`커스텀 코드`

```solidity
contract RewardVault {
    // ... 기존 코드 ...

    // 가이드라인 1: 토큰 제거 조건 제한
    function removeIncentiveToken(address token) 
        external 
        onlyFactoryVaultManager 
        onlyWhitelistedToken(token) 
        onlyAfterTimelock 
        requiresGovernanceApproval 
    {
        // ... 기존 코드 ...
        
        // 가이드라인 3,4: 토큰 제거 이벤트 기록
        emit IncentiveTokenRemovalScheduled(
            token,
            incentives[token].amountRemaining,
            block.timestamp + REMOVAL_NOTICE_PERIOD
        );
        
        // ... 기존 코드 ...
    }

    // 가이드라인 6: 토큰 변경 이력 기록
    event IncentiveTokenAuditLog(
        address indexed token,
        string action,
        uint256 timestamp,
        address initiator
    );
}
```

***

### 위협 10: 토큰 승인 검증 부재 및 ERC-20 표준 미검증으로 인한 위협

화이트리스트 토큰에 대한 ERC20 표준 준수 여부 등의 검증 절차 누락 시 네트워크 보상 처리 과정에서 승인량 불일치나 전송 실패로 인해 자산 손실이 발생할 수 있다.

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
