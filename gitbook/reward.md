---
icon: sack-dollar
---

# PoL 보안 가이드라인: 보상 분배

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

컨트랙트 초기 배포 과정에서 영(0) 주소 입력 등 필수 검증 절차와 필터링 기능 누락 시 잘못된 설정으로 인한 시스템 오류 발생 가능성이 존재한다.

#### 가이드라인

> * **모든 컨트랙트 초기화 시 영주소 검증 및 필수 매개변수 검증**
> * **초기 설정 매개변수들의 합리적 범위 검증**
> * **초기 예치 루트 설정 등 초기 상태의 무결성 보장**
> * **초기화 함수의 멱등성 보장 및 재초기화 방지 메커니즘**
> * **주요 파라미터 변경을 위한 롤백 메커니즘**

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

### 위협 3: BGT 리딤 시 네이티브 토큰 부족으로 인한 유동성 위기

BGT 리딤 시 대상 컨트랙트가 현재 보유하고 있는 네이티브 토큰의 수량이 부족할 경우 일부 사용자는 보상을 받지 못하고 유동성 위기가 발생한다.

#### 가이드라인

> * **BGT 리딤 시 컨트랙트 잔액 검증 및 충분한 네이티브 토큰 보유량 확보**
> * **초과 토큰 보유량 관리 및 적절한 버퍼 유지**
> * **BGT 예상 발행량 계산 시 블록 버퍼 크기와 블록당 BGT 발행량 등 고려한 정확한 예상량 산출**

#### Best Practice&#x20;

&#x20;[`BGT.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/pol/BGT.sol#L369)

```solidity
function redeem(
    address receiver,
    uint256 amount
)
    external
    invariantCheck
    // 사용자 잔액 검증
    checkUnboostedBalance(msg.sender, amount)
{
    // ...
}

function burnExceedingReserves() external {
    // ...
    // 잠재적 민팅량 계산
    uint256 potentialMintableBGT = HISTORY_BUFFER_LENGTH * br.getMaxBGTPerBlock();
    // ...
    // 현재 잔액과 요구량 비교
    if (currentReservesAmount <= outstandingRequiredAmount) return;
    // ...
}

// 컨트랙트 상태 일관성 검증
modifier invariantCheck() {
    _;

    _invariantCheck();
}

function _invariantCheck() private view {
    if (address(this).balance < totalSupply()) InvariantCheckFailed.selector.revertWith();
}
```

***

### 위협 4: 보상 분배 로직 오류로 인한 특정 사용자에게 과도한 보상 지급 또는 보상 누락

보상 분배 로직에 버그가 있어 특정 사용자에게 과도한 보상이 지급되거나, 일부 사용자가 보상을 받지 못하는 상황이 발생한다.

#### 가이드라인

> * **95% 코드 커버리지, Fuzz 테스트, 100명 이상 사용자 시뮬레이션 등 구체적 수치 제시**
> * **Python/JavaScript 기반 오프체인 검증 시스템 구현 방안**

#### Best Practice&#x20;

&#x20;[`StakingRewards.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/base/StakingRewards.sol#L107)

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

### 위협 6: 재진입 공격을 통해 보상 중복 청구

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

### 위협 7: 운영자들이 담합하여 특정 **보상 금고**에만 BGT 보상을 집중, 유동성 쏠림 및 타 프로토콜 유동성 고갈

운영자들이 담합하여 특정 보상 금고에만 BGT 보상을 몰아주면, 일부 보상 금고의 유동성이 고갈되고 타 프로토콜의 유동성도 줄어든다.

#### 가이드라인

> * **여러 종류 보상 금고에게 나눠 주도록 강제**
> * **운영자/검증자 보상 할당 변경 시 투명한 로그 기록 및 모니터링**
> * **담합 의심 시 거버넌스/커뮤니티 신고 및 감사 프로세스 마련**
> * **금고별 TVL, APR, 유동성 집중도 실시간 대시보드 제공**

#### Best Practice&#x20;

&#x20;[`BeraChef.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/pol/rewards/BeraChef.sol#L392-L394)

```solidity
function _validateWeights(Weight[] calldata weights) internal view {
    // 보상 금고당 할당량 최대치 검증
    if (weights.length > maxNumWeightsPerRewardAllocation) {
        TooManyWeights.selector.revertWith();
    }
    
    // 중복 보상 금고 체크
    _checkForDuplicateReceivers(valPubkey, weights);
    // ...
}
```

***

### 위협 8: 보상 분배 계산 과정 중 나눗셈 연산 정밀도 오류 발생 시 사용자 보상 미세 손실 누적 가능

보상 분배 계산 중 나눗셈 정밀도 오류로 인해, 일부 사용자의 보상이 소수점 이하로 계속 손실되어 누적된다.

#### 가이드라인

> * **보상 수령 대상 및 금액의 정확성을 교차 검증하는 로직 추가**
> * **최소 수량 or 최대 수량 설정으로 나눗셈 연산 오류 방지**
> * **사용자 유리한 반올림 정책**

#### Best Practice&#x20;

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
            address token = whitelistedTokens[i];
            Incentive storage incentive = incentives[token];
            
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

### 위협 9: 보상 금고 팩토리 관리자가 악의적인 분배자 생성 시 사용자 보상 시스템 문제 발생

보상 금고 팩토리 관리자가 악의적으로 분배자를 변경할 경우 사용자 보상 시스템이 즉시 영향을 받아 보상 분배 흐름이 비정상적으로 바뀌어 피해가 발생할 수 있다&#x20;

#### 가이드라인

> * **악의적인 분배자 변경이 즉각 반영되는 것을 방지하기 위한 타임락 등의 추가 보안 절차 반영 필요**
> * **변경시 다중 서명 거버넌스 필요**

#### Best Practice&#x20;

```solidity
// 기존 RewardVault.sol의 setDistributor 함수 개선
contract RewardVault is ... {
    // ... 기존 코드 ...
    
    // 가이드라인 1: 타임락 추가
    struct PendingDistributor {
        address newDistributor;
        uint256 executeAfter;
    }
    
    PendingDistributor public pendingDistributor;
    uint256 constant TIMELOCK_DELAY = 2 days;
    
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
    mapping(address => mapping(address => bool)) public distributorApprovals; // vault => governor => approved
    mapping(address => uint256) public approvalCount; // vault => count
    
    // 기존 AccessControl 역할 활용
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    uint256 constant REQUIRED_APPROVALS = 2;
    
    // RewardVault의 distributor 변경 승인
    function approveDistributorChange(address vault) external onlyRole(GOVERNOR_ROLE) {
        RewardVault rewardVault = RewardVault(vault);
        require(rewardVault.pendingDistributor().newDistributor != address(0), "No pending change");
        require(!distributorApprovals[vault][msg.sender], "Already approved");
        
        distributorApprovals[vault][msg.sender] = true;
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

### 위협 10: 인센티브 토큰이 고갈된 뒤에 추가 공급을 하지 않으면 검증자의 부스트 보상 감소

인센티브 토큰이 고갈된 후 추가 공급이 이뤄지지 않으면, 벨리데이터의 Boost Reward가 급격히 감소한다. vault의 인센티브 토큰 잔고를 실시간으로 확인할 수 없다면, 벨리데이터가 보상 감소를 사전에 인지하지 못한다.

#### 가이드라인

> * **보상 금고 내의 인센티브 토큰 최소 보유량을 제한**
> * **검증자의 경우 BGT를 분배할 보상 금고를 선택할때 인센티브 토큰이 충분히 남아있는지 확인**
> * **보상 금고에 인센티브 토큰 얼마나 남았는지 확인하는 대시보드 제작**

#### Best Practice&#x20;

```solidity
// 기존 RewardVault.sol 개선
contract RewardVault is ... {
    // ... 기존 코드 ...
    
    // 가이드라인 1: 최소 보유량 제한
    mapping(address => uint256) public minIncentiveReserve; // 토큰별 최소 보유량
    uint256 constant DEFAULT_MIN_RESERVE = 1000e18; // 기본 최소 보유량
    
    // 기존 addIncentive 함수 개선
    function addIncentive(
        address token,
        uint256 amount,
        uint256 incentiveRate
    ) external nonReentrant onlyWhitelistedToken(token) {
        // ... 기존 검증 로직 ...
        
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        incentive.amountRemaining = amountRemainingBefore + amount;
        
        // 가이드라인 1: 최소 보유량 경고
        uint256 minReserve = minIncentiveReserve[token] > 0 ? 
            minIncentiveReserve[token] : DEFAULT_MIN_RESERVE;
            
        if (incentive.amountRemaining < minReserve) {
            emit IncentiveLowReserveWarning(token, incentive.amountRemaining, minReserve);
        }
        
        // ... 나머지 코드 ...
    }
    
    // 가이드라인 2: 인센티브 충분성 확인 함수
    function isIncentiveSufficient(address token) external view returns (bool) {
        Incentive storage incentive = incentives[token];
        uint256 minReserve = minIncentiveReserve[token] > 0 ? 
            minIncentiveReserve[token] : DEFAULT_MIN_RESERVE;
            
        // 최소 7일치 인센티브가 있는지 확인
        uint256 estimatedDailyUsage = incentive.incentiveRate * 86400; // 일일 예상 사용량
        uint256 requiredAmount = estimatedDailyUsage * 7; // 7일치
        
        return incentive.amountRemaining >= Math.max(minReserve, requiredAmount);
    }
    
    // 가이드라인 3: 대시보드용 상세 정보 제공
    function getIncentiveStatus(address token) 
        external 
        view 
        returns (
            uint256 remaining,
            uint256 rate,
            uint256 estimatedDaysLeft,
            bool isHealthy
        ) 
    {
        Incentive storage incentive = incentives[token];
        remaining = incentive.amountRemaining;
        rate = incentive.incentiveRate;
        
        // 예상 소진 일수 계산
        if (rate > 0) {
            estimatedDaysLeft = remaining / (rate * 86400);
        } else {
            estimatedDaysLeft = type(uint256).max; // 무한대
        }
        
        // 건강 상태: 7일 이상 남았는지
        isHealthy = estimatedDaysLeft >= 7;
    }
    
    // 최소 보유량 설정 (관리자 전용)
    function setMinIncentiveReserve(address token, uint256 minReserve) 
        external 
        onlyFactoryOwner 
    {
        minIncentiveReserve[token] = minReserve;
        emit MinReserveUpdated(token, minReserve);
    }
    
    // ... 기존 코드 ...
}
```

```solidity
// BeraChef 또는 Validator 선택 로직 개선
contract ValidatorRewardSelection {
    // 가이드라인 2: 벨리데이터의 vault 선택 시 인센티브 확인
    function selectRewardVault(address[] calldata vaults) 
        external 
        view 
        returns (address bestVault) 
    {
        uint256 bestScore = 0;
        
        for (uint256 i = 0; i < vaults.length; i++) {
            IRewardVault vault = IRewardVault(vaults[i]);
            
            // 인센티브 토큰들의 상태 확인
            address[] memory tokens = vault.getWhitelistedTokens();
            uint256 healthyTokens = 0;
            
            for (uint256 j = 0; j < tokens.length; j++) {
                if (vault.isIncentiveSufficient(tokens[j])) {
                    healthyTokens++;
                }
            }
            
            // 건강한 인센티브가 많은 vault 선택
            uint256 score = healthyTokens * 1000 + vault.totalSupply() / 1e18;
            
            if (score > bestScore) {
                bestScore = score;
                bestVault = vaults[i];
            }
        }
    }
}
```

```solidity
// 가이드라인 3: 대시보드 데이터 집계
contract IncentiveDashboard {
    struct VaultIncentiveInfo {
        address vault;
        address token;
        uint256 remaining;
        uint256 estimatedDaysLeft;
        bool needsRefill;
    }
    
    function getAllVaultIncentiveStatus(address[] calldata vaults) 
        external 
        view 
        returns (VaultIncentiveInfo[] memory infos) 
    {
        // ... 모든 vault의 인센티브 상태 수집 ...
        
        for (uint256 i = 0; i < vaults.length; i++) {
            IRewardVault vault = IRewardVault(vaults[i]);
            address[] memory tokens = vault.getWhitelistedTokens();
            
            for (uint256 j = 0; j < tokens.length; j++) {
                (uint256 remaining, , uint256 daysLeft, bool isHealthy) = 
                    vault.getIncentiveStatus(tokens[j]);
                    
                // 7일 미만 남은 경우 리필 필요
                infos[index++] = VaultIncentiveInfo({
                    vault: vaults[i],
                    token: tokens[j],
                    remaining: remaining,
                    estimatedDaysLeft: daysLeft,
                    needsRefill: !isHealthy
                });
            }
        }
    }
}
```

***

### 위협 11: 인센티브 토큰가 고갈 된 후 보상 비율을 낮춰 해당 보상 금고를 선택한 검증자의 부스트 APR 감소

인센티브 토큰이 고갈된 후, 인센티브 비율이 낮아져 해당 vault를 선택한 벨리데이터의 Boost APR이 감소한다. 권한 관리가 미흡하면, 임의로 인센티브 비율이 조정되어 피해가 발생할 수 있다.

#### 가이드라인

> * **각 함수 및 중요 데이터에 대해 명확한 역할(Owner, Admin, User 등)을 정의, 역할에 따른 접근 권한을 엄격히 부여**
> * **`onlyOwner`, `onlyRole` 등의 modifier를 명확히 사용**
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

### 위협 12: LP 토큰 전량 인출 및 notifyRewardAmount 호출로 인한 보상 중복 누적 및 APR 급등

만약 epoch이 진행 중일 때 notifyRewardAmount 호출 후 모든 LP 토큰을 인출해 잔고를 0으로 만들면, 보상 잔액이 두 번 누적되어 보상 총액 기록이 비정상적으로 증가할 수 있다. 이후 스테이킹이 재개되면 APR이 급등하고, allowance가 부족할 경우 InsolventReward revert가 발생할 수 있다. 반대로 LP 토큰 잔고가 0인 상태에서 notifyRewardAmount가 먼저 실행되면, 보상 잔액이 다음 epoch으로 이월되지 않아 해당 epoch의 보상이 증발할 수 있다.

#### 가이드라인

> * **notifyRewardAmount 호출 시 LP 토큰 잔고가 0인 경우, 보상 누적 또는 이월을 제한하고 명확한 revert 사유를 제공해야 함.**
> * **보상 총액 기록이 중복 누적되지 않도록, notifyRewardAmount와 LP 인출 간의 상호작용에 대한 상태 검증 로직을 추가.**
> * **epoch 종료 전 LP 토큰 전량 인출 시, 보상 분배 및 이월 정책을 명확히 정의하고, 사용자에게 사전 안내.**
> * **APR 급등 및 InsolventReward revert 발생 가능성을 사전에 감지하여, 스테이킹 재개 시 보상 분배를 일시적으로 제한하거나 관리자 승인 절차를 거치도록 설계.**
> * **보상 분배 및 이월 관련 이벤트를 모두 기록하여, 이상 징후 발생 시 신속하게 감사 및 롤백이 가능하도록 시스템화.**

#### Best Practice&#x20;

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
    
    uint256 public immutable MIN_LP_THRESHOLD;
    address public initialLPProvider;
    
    // 초기화 시 최소 LP 설정
    function initialize(
        address _beaconDepositContract,
        address _bgt,
        address _distributor,
        address _stakingToken,
        uint256 _minLPThreshold
    ) external initializer {
        // ... 기존 초기화 로직 ...
        
        MIN_LP_THRESHOLD = _minLPThreshold;
    }
    
    // 초기 LP 예치 처리 (factory만 호출 가능)
    function depositInitialLP(uint256 amount) external {
        require(msg.sender == factory(), "Only factory");
        require(initialLPProvider == address(0), "Already initialized");
        
        initialLPProvider = tx.origin;
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

### 위협 13: 정상적인 인센티브 토큰 제거에 따른 보상 중단

정상적인 인센티브 토큰 제거 시 갑작스러운 사용자 보상 중단으로 인한 사용자 혼란이 발생할 수 있고 보상 구조의 변경으로 인한 문제 발생 가능성이 존재한다.

#### 가이드라인

> * **`removeIncentiveToken` 함수의 호출 조건에 제한 로직 추가**&#x20;
> * **인센티브 토큰 제거 또는 교체는 거버넌스 승인을 요구하도록 설계**
> * **인센티브 토큰 제거 전, 해당 보상 금고의 남은 분배량 및 종료 일정 공지**
> * **토큰 제거 시 이벤트 로그 기록 필수 및 대시보드 상 실시간 반영**
> * **보상 금고의 보상 구조 변경(토큰 추가/제거)은 사용자에게 사전 고지 및 명확한 UI 표시**
> * **보상 토큰 변경 이력은 감사 로그(audit trail) 로 저장, 분기별 커뮤니티 감사 진행**

#### Best Practice&#x20;

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

### 위협 14: claimFees() 프론트러닝에 따른 사용자의 수수료 보상 왜곡&#x20;

claimFees() 함수를 호출하는 사용자 앞에서 프론트러닝을 통한 트랜잭션 선점 시 수수료 보상 가로채기 또는 인센티브 왜곡이 발생할 수 있다.

#### 가이드라인

> * **`claimFees()` 호출 시 프론트러닝 방지를 위해 수수료 계산 기준이 되는 블록 넘버/타임스탬프를 내부 저장하고 호출자 기준으로 고정하여 외부 간섭 방지 or 클레임 대상 사용자 주소 명시 필드 활용**
> * **HONEY 등 수수료 잔고가 급변할 경우 이상 징후 탐지 및 임시 정지 로직(safeguard) 활성화**
> * **수수료 누적/청구/소진 과정은 이벤트 로그를 통한 추적이 가능해야 하며, 이상 징후 발생 시 자동 경고를 발생시키는 보상 모니터링 시스템 구축**
> * **클레임 가능한 수수료 토큰 종류는 허용된 화이트리스트기반으로 제한**

#### Best Practice&#x20;

```solidity
contract FeeCollector {
    // ... 기존 코드 ...

    // 가이드라인 1: 프론트러닝 방지를 위한 블록 넘버 기반 수수료 계산
    function claimFees(
        address recipient, 
        address[] calldata feeTokens,
        uint256 blockNumber  // 클레임 기준 블록
    ) external whenNotPaused {
        // ... 기존 코드 ...
        
        // 가이드라인 2: HONEY 등 수수료 잔고 급변 감지
        if (_isAbnormalBalanceChange(feeTokens)) {
            emit AbnormalBalanceChange(feeTokens);
            _pause();
            return;
        }

        // 가이드라인 4: 화이트리스트 기반 토큰 제한
        require(_isWhitelistedTokens(feeTokens), "Non-whitelisted token");

        // ... 기존 코드 ...

        // 가이드라인 3: 수수료 처리 이벤트 기록
        emit FeesProcessed(
            recipient,
            blockNumber,
            feeTokens
        );
    }
}
```

***

### 위협 15: dApp 프로토콜의 수수료 송금 누락에 따른 사용자 보상 실패

dApp 프로토콜의 수수료 송금 누락 시 사용자가 claimFees를 호출해도 정상적인 보상을 받을 수 없어 호출을 하지 않게 되면 BGT Staker의 HONEY 보유량 감소로 이어져 BGT 예치자의 보상이 정상적으로 분배되지 못할 수 있다.

#### 가이드라인

> * **FeeCollector와 dApp 간 수수료 정산 상태(누적/미정산)를 주기적으로 확인하는 오프체인 모니터링 시스템 도입**
> * **일정 기간 동안 수수료 송금이 누락된 dApp은 해당 보상 금고의 인센티브 대상에서 제외하거나 거버넌스를 통해 보상 삭감/정지 등의 제재가 가능하도록 설계**
> * **`claimFees()` 호출 시, 지급량이 200 HONEY(=1%) 이하일 경우 revert 및 UI 피드백 제공**

#### Best Practice&#x20;

```solidity
contract FeeCollector {
    // ... 기존 코드 ...
    
    // 가이드라인 2: dApp 상태 관리
    struct DAppInfo {
        uint256 lastFeeTimestamp;
        bool isActive;
        uint256 totalFeesAccumulated;
    }
    
    mapping(address => DAppInfo) public dappInfo;
    uint256 public constant MIN_HONEY_AMOUNT = 200e18; // 200 HONEY
    
    function claimFees(
        address _recipient, 
        address[] calldata _feeTokens
    ) external whenNotPaused {
        // 가이드라인 3: 최소 HONEY 수량 체크
        uint256 honeyBalance = IERC20(payoutToken).balanceOf(address(this));
        if (honeyBalance <= MIN_HONEY_AMOUNT) {
            revert InsufficientHoneyForClaim();
        }
        
        // ... 기존 코드 ...
        
        // 가이드라인 1: 수수료 정산 상태 기록
        _updateDAppFeeStatus(msg.sender);
        
        emit FeeSettlementUpdated(
            msg.sender,
            block.timestamp,
            honeyBalance
        );
    }
    
    // 가이드라인 2: 비활성 dApp 제재
    function penalizeDApp(address dapp) external onlyRole(MANAGER_ROLE) {
        DAppInfo storage info = dappInfo[dapp];
        if (block.timestamp - info.lastFeeTimestamp > 7 days) {
            info.isActive = false;
            emit DAppPenalized(dapp);
        }
    }
}
```

***

### 위협 16: 토큰 승인 검증 부재 및 ERC-20 표준 미검증으로 인한 위협

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

***

### 위협 17: 인센티브 분배 대상 선정 로직 오류

인센티브 분배기에서 분배 설정 시 누락 또는 미검증된 설정으로 인해 인센티브 분배 처리 과정에서 문제가 발생할 수 있다.

#### 가이드라인

> * **인센티브 분배기에 필요한 각종 기능에 대한 권한을 거버넌스 구조로 역할 분리**
> * **인센티브 분배 설정 변경 시 이중 검증 실시**
> * **설정 변경 후 실제 적용에 시간차를 두기 위한 시간 지연 로직 구현**

#### Best Practice&#x20;

&#x20;[`BGTIncentiveDistributor.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/pol/rewards/BGTIncentiveDistributor.sol#L34-L35)&#x20;

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

&#x20;[`BeraChef.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/pol/rewards/BeraChef.sol#L241-L243)&#x20;

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

// 허용된 인센티브 분배 대상을 분류하기 위한 화이트리스트 토큰, 보상 금고 주소 관리
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

인센티브 분배 비율, 분배 기간 설정 과정에서 비정상적인 계산이 적용될 경우 인센티브가 과도/과소 지급될 가능성이 있다.

#### 가이드라인

> * **시간 기반 분배 로직 처리 과정에서 블록 타임스탬프 의존성 최소화**
> * **인센티브 연산 과정에서 안전한 시간 연산을 위해 검증된 수학 계산 라이브러리 사용**

#### Best Practice&#x20;

&#x20;[`StakingRewards.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/base/StakingRewards.sol#L108-L112)

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
    uint256 _newRewardPerToken = 
    FixedPointMathLib.fullMulDiv(rewardRate, timeDelta, _totalSupply);
    return rewardPerTokenStored + _newRewardPerToken;
}
```

[`BeraChef.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/pol/rewards/BeraChef.sol#L241-L243)

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

&#x20;[`BGTIncentiveDistributor.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/pol/rewards/BGTIncentiveDistributor.sol#L204-L206)

```solidity
uint64 public constant MAX_REWARD_CLAIM_DELAY = 3 hours;

// ...

function _setRewardClaimDelay(uint64 _delay) internal {
    // 보상 획득 지연시간 지정을 통한 타임스탬프 기반 지연 시간 최소화
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

> * **인센티브 토큰과 연관된 스테이킹 토큰마다 별도의 보상 금고를 생성**
> * **검증된 보상 금고만 운영할 수 있는 별도의 관리 기준 운영**
> * **인센티브 토큰 보상 정보를 독립적으로 관리할 수 있는 로직 추가**
> * **인센티브 토큰 지급 보상 금고 별 분산된 권한 관리를 위한 계층적 권한 구조 적용**

#### Best Practice

&#x20;[`RewardVault.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/pol/rewards/RewardVault.sol#L54-L59)

```solidity
// 오프체인 거버넌스 포럼 검증을 통한 허가된 보상 금고만 인센티브 보상을 제공하는 방식 제공 (향후 온체인 구현 필요)
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
    // 보상 에 필요한 계층적 권한 구조를 지정하여 관리자 역할 구분
    __FactoryOwnable_init(msg.sender);
    __Pausable_init();
    __ReentrancyGuard_init();
    __StakingRewards_init(_stakingToken, _bgt, 3 days);
    // ...
}
```

***

### 위협 20: 검증자의 운영자의 인센티브 분배 직전 queue 조작을 통한 보상 탈취 및 사용자 분배 손실

검증자 운영자가 인센티브 분배 직전 인센티브 분배 큐를 조작하여 보상을 탈취하게 될 경우 분배될 사용자 인센티브에 대해 손해가 발생할 수 있다.

#### 가이드라인

> * **인센티브 분배 로그 분석을 통한 현황 추적**
> * **악의적인 검증자 slashing**

#### Best Practice&#x20;

&#x20;[`RewardVault.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/pol/rewards/RewardVault.sol#L485-L487)

```solidity
function _processIncentives(bytes calldata pubkey, uint256 bgtEmitted) internal {
    // ...
    // BGT 부스터와 검증자 몫에 대한 로깅을 이중으로 수행
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

&#x20;[`BeraChef.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/pol/rewards/BeraChef.sol#L290)

```solidity
function activateQueuedValCommission(bytes calldata valPubkey) external {
    // ...
    // 악의적인 검증자 탐지를 위한 ValCommissionSet 등의 이벤트 처리기로 이력 추적 진행    
    emit ValCommissionSet(valPubkey, oldCommission, commissionRate);
    // ...
}

function _getOperatorCommission(bytes calldata valPubkey) internal view returns (uint96) {
    // 검증자의 공개키로 인센티브 수량 계산 전 수령 유효성 확인
    CommissionRate memory operatorCommission = valCommission[valPubkey];
    // ...
}
```

***

### 위협 21: $BGT 토큰 배출량 계산 오류 및 가중치 조작을 통한 인플레이션 유발

$BGT 토큰의 배출 계산식 자체에 결함이 발생하거나 보상 배출량 관련 수식 변수 요소에 대한 조작을 시도할 시 예상치를 벗어난 의도하지 않은 인플레이션 발생 가능성이 있다.

#### 가이드라인

> * **모든 중요 파라미터 변경은 거버넌스 투표를 통해서만 가능하도록 제한**
> * **보상 계산 파라미터 변경 시 점진적 변화만 허용하도록 상한선 및 하한선 설정**
> * **실시간 보상 배출량 모니터링 시스템 구축 및 이상 징후 감지 메커니즘 설정**
> * **심각한 계산 오류 발생 시 즉시 대응하기 위한 긴급 조치 프로토콜 마련**
> * **보상 계산식에 대한 명확한 문서화와 커뮤니티 이해를 위한 시각화 자료 제공**

#### Best Practice&#x20;

```solidity
contract BlockRewardController {
    // ... 기존 코드 ...
    
    // 가이드라인 2: 파라미터 변경 제한
    struct ParamLimits {
        uint256 maxChangePerUpdate;  // 한 번에 변경 가능한 최대 크기
        uint256 minUpdateInterval;   // 최소 업데이트 간격
        uint256 lastUpdateTime;      // 마지막 업데이트 시간
    }
    
    mapping(bytes32 => ParamLimits) public parameterLimits;
    
    // 가이드라인 1: 거버넌스 투표 필수
    function setBaseRate(uint256 _baseRate) 
        external 
        onlyGovernance 
        validateParamChange("baseRate", _baseRate) 
    {
        // ... 기존 코드 ...
        
        // 가이드라인 3: 배출량 모니터링을 위한 이벤트
        emit EmissionRateChanged(
            "baseRate",
            baseRate,
            _baseRate,
            block.timestamp
        );
    }
    
    // 가이드라인 4: 긴급 조치 프로토콜
    function emergencyPauseEmission() 
        external 
        onlyEmergencyCouncil 
        whenAbnormalEmissionDetected 
    {
        _pauseEmission();
        emit EmergencyPause(block.timestamp);
    }
}
```
