---
icon: coins
---

# PoL 보안 가이드라인: 토크노믹스

<table><thead><tr><th width="617.40625">위협</th><th align="center">영향도</th></tr></thead><tbody><tr><td><a data-mention href="tokenomics.md#id-1-bgt">#id-1-bgt</a></td><td align="center"></td></tr><tr><td><a data-mention href="tokenomics.md#id-2-bgt">#id-2-bgt</a></td><td align="center"></td></tr><tr><td><a data-mention href="tokenomics.md#id-3">#id-3</a></td><td align="center"></td></tr><tr><td><a data-mention href="tokenomics.md#id-4-apr">#id-4-apr</a></td><td align="center"></td></tr><tr><td><a data-mention href="tokenomics.md#id-5-claimfees">#id-5-claimfees</a></td><td align="center"></td></tr><tr><td><a data-mention href="tokenomics.md#id-6-dapp">#id-6-dapp</a></td><td align="center"></td></tr><tr><td><a data-mention href="tokenomics.md#id-7">#id-7</a></td><td align="center"></td></tr><tr><td><a data-mention href="tokenomics.md#id-8">#id-8</a></td><td align="center"></td></tr><tr><td><a data-mention href="tokenomics.md#id-9-queue">#id-9-queue</a></td><td align="center"></td></tr><tr><td><a data-mention href="tokenomics.md#id-10-bgt">#id-10-bgt</a></td><td align="center"></td></tr></tbody></table>

### 위협 1: BGT 리딤 시 네이티브 토큰 부족으로 인한 유동성 위기

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

### 위협 2: 운영자들이 담합하여 특정 **보상 금고**에만 BGT 보상을 집중, 유동성 쏠림 및 타 프로토콜 유동성 고갈

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

### 위협 3: 인센티브 토큰이 고갈된 뒤에 추가 공급을 하지 않으면 검증자의 부스트 보상 감소

인센티브 토큰이 고갈된 후 추가 공급이 이뤄지지 않으면 검증자의 부스트 보상이 급격히 감소한다. \
보상금고의 인센티브 토큰 잔고를 실시간으로 확인할 수 없다면 검증자가 보상 감소를 사전에 인지하지 못한다.

#### 가이드라인

> * **보상 금고 내의 인센티브 토큰 최소 보유량을 제한**
> * **검증자의 경우 BGT를 분배할 보상 금고를 선택할때 인센티브 토큰이 충분히 남아있는지 확인**
> * **보상 금고에 인센티브 토큰 얼마나 남았는지 확인하는 대시보드 제작**

#### Best Practice&#x20;

`커스텀 코드`

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
        address vault;             // 보상 금고
        address token;             // 토큰 주소
        uint256 remaining;         // 남아있는 토큰 수
        uint256 estimatedDaysLeft; // 대시보드 재집계 주기
        bool needsRefill;          // 채워야 하는 토큰 수
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

### 위협 4: 인센티브 토큰가 고갈 된 후 보상 비율을 낮춰 해당 보상 금고를 선택한 검증자의 부스트 APR 감소

인센티브 토큰이 고갈된 후, 인센티브 비율이 낮아져 해당 보상금고를 선택한 검증자의 부스트 APR이 감소한다. 권한 관리가 미흡하면, 임의로 인센티브 비율이 조정되어 피해가 발생할 수 있다.

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

### 위협 5: claimFees() 프론트 러닝에 따른 사용자의 수수료 보상 왜곡&#x20;

`claimFees()`함수를 호출하는 사용자 앞에서 프론트 러닝을 통한 트랜잭션 선점 시 수수료 보상이 왜곡될 수 있다.

#### 가이드라인

> * **`claimFees()` 호출 시 프론트 러닝 방지를 위해 수수료 계산 기준이 되는 블록 넘버/타임스탬프를 내부 저장하고 호출자 기준으로 고정하여 외부 간섭 방지 or 클레임 대상 사용자 주소 명시 필드 활용**
> * **HONEY 등 수수료 잔고가 급변할 경우 이상 징후 탐지 및 임시 정지 로직 활성화**
> * **수수료 누적/청구/소진 과정은 이벤트 로그를 통한 추적이 가능해야 하며, 이상 징후 발생 시 자동 경고를 발생시키는 보상 모니터링 시스템 구축**
> * **클레임 가능한 수수료 토큰 종류는 허용된 화이트 리스트기반으로 제한**

#### Best Practice&#x20;

`커스텀 코드`

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

### 위협 6: dApp 프로토콜의 수수료 송금 누락에 따른 사용자 보상 실패

dApp 프로토콜의 수수료 송금 누락 시 사용자가 `claimFees`를 호출해도 정상적인 보상을 받을 수 없어 호출을 하지 않게 되면 BGT Staker의 HONEY 보유량 감소로 이어져 BGT 예치자의 보상이 정상적으로 분배되지 못할 수 있다.

#### 가이드라인

> * **FeeCollector와 dApp 간 수수료 정산 상태(누적/미정산)를 주기적으로 확인하는 오프체인 모니터링 시스템 도입**
> * **일정 기간 동안 수수료 송금이 누락된 dApp은 해당 보상 금고의 인센티브 대상에서 제외하거나 거버넌스를 통해 보상 삭감/정지 등의 제재가 가능하도록 설계**
> * **`claimFees()` 호출 시, 지급량이 200 HONEY(=1%) 이하일 경우 revert 및 UI 피드백 제공**

#### Best Practice&#x20;

`커스텀 코드`

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

### 위협 7: 인센티브 분배 대상 선정 로직 오류

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

### 위협 8: 분배 비율 또는 기간 설정 오류로 인한 과도/과소 인센티브 지급

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

### 위협 9: 검증자의 운영자의 인센티브 분배 직전 queue 조작을 통한 보상 탈취 및 사용자 분배 손실

검증자 운영자가 인센티브 분배 직전 인센티브 분배 queue를 조작하여 보상을 탈취하게 될 경우 분배될 사용자 인센티브에 대해 손해가 발생할 수 있다.

#### 가이드라인

> * **인센티브 분배 로그 분석을 통한 현황 추적**
> * **악의적인 검증자 슬래싱**

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

### 위협 10: BGT 토큰 배출량 계산 오류 및 가중치 조작을 통한 인플레이션 유발

BGT 토큰의 배출 계산식 자체에 결함이 발생하거나 보상 배출량 관련 수식 변수 요소에 대한 조작을 시도할 시 예상치를 벗어난 인플레이션 발생 가능성이 있다.

#### 가이드라인

> * **즉시 대응을 위한 긴급 조치 프로토콜 마련**
> * **모든 중요 파라미터 변경은 거버넌스 투표를 통해서만 가능하도록 제한**
> * **실시간 보상 배출량 모니터링 시스템 구축 및 이상 징후 감지 메커니즘 설정**
> * **보상 계산 파라미터 변경 시 점진적 변화만 허용하도록 상한선 및 하한선 설정**
> * **보상 계산식에 대한 명확한 문서화와 커뮤니티 이해를 위한 시각화 자료 제공**

#### Best Practice&#x20;

`커스텀 코드`

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
        emit EmissionRateChanged( ... );
    }
    
    // 가이드라인 4: 긴급 조치 프로토콜
    function emergencyPauseEmission() 
        external 
        onlyEmergencyCouncil         // 긴급 조치가 가능한 거버넌스 멤버 한정 실행
        whenAbnormalEmissionDetected // 비정상 BGT 분배 행위 탐지 시에만 동작
    {
        _pauseEmission();
        emit EmergencyPause(block.timestamp);
    }
}
```
