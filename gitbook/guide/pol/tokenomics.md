---
icon: coins
---

# PoL 보안 가이드라인: 토크노믹스

<table><thead><tr><th width="595.53515625">위협</th><th align="center">영향도</th></tr></thead><tbody><tr><td><a data-mention href="tokenomics.md#id-1-bgt">#id-1-bgt</a></td><td align="center"><code>High</code></td></tr><tr><td><a data-mention href="tokenomics.md#id-2-bgt">#id-2-bgt</a></td><td align="center"><code>Medium</code></td></tr><tr><td><a data-mention href="tokenomics.md#id-3-queue">#id-3-queue</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="tokenomics.md#id-4-boost-bgt">#id-4-boost-bgt</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="tokenomics.md#id-5">#id-5</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="tokenomics.md#id-6-apr">#id-6-apr</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="tokenomics.md#id-7-claimfees">#id-7-claimfees</a></td><td align="center"><code>Low</code></td></tr></tbody></table>

### 위협 1: BGT 리딤 시 네이티브 토큰 부족으로 인한 유동성 위기

BGT 리딤 시 대상 컨트랙트가 현재 보유하고 있는 네이티브 토큰의 수량이 부족할 경우 일부 사용자는 보상을 받지 못하고 보상 수령 트랜잭션이 revert 되어 유동성 위기가 발생한다.

#### 영향도

`High`

네이티브 토큰 부족으로 인해 다수 사용자의 리딤(보상 수령) 트랜잭션이 실패(revert)하면 신뢰도 하락과 대규모 자금 이탈, 시스템 전반의 유동성 위기로 직결될 수 있기 때문

#### 가이드라인

> * **BGT 리딤 시 유효성 검증**
>   * 컨트랙트 잔액 확인
>     * redeem 함수에서 BERA transfer시 safeTransferETH사용하여 잔액 부족 시 revert
>   * 리딤 요청량 검증
>     * checkUnboostedBalance 함수를 이용하여 사용자의 리딤 요청량이 unboost한 BGT 수량보다 적거나 같은지 검증
> * **컨트랙트 내 충분한 네이티브 토큰 보유량 확보**
>   * 리딤 이후 최종성 보장
>     * \_invariantCheck를 통해 리딤 과정이 종료된 뒤 현재 BGT 총 발행량과 보유 네이티브 토큰 수량을 비교하여 충분한 양의 네이티브 토큰을 보유하고 있는지 검증
>   *   체인 스펙 상 BERA발행 설정
>
>       ```toml
>       # Deneb1 value changes
>       # BGT 토큰 컨트랙트 주소로 블록당 5.75 BERA 발행
>       evm-inflation-address-deneb-one = "0x656b95E550C07a9ffe548bd4085c72418Ceb1dba"
>       evm-inflation-per-block-deneb-one = 5_750_000_000
>       ```
> * **초과 토큰 보유량 관리 및 적절한 버퍼 유지**
>   * **BGT 예상 발행량 계산 시 블록 버퍼 크기와 블록당 BGT 발행량 등 고려한 정확한 예상량 산출**
>     * BlockRewardController의 computeReward 함수에 boostPower로 100%를 입력하여 한 블록당 나올 수 있는 BGT 최대치를 계산
>     * EIP-4788에 맞게 HISTORY\_BUFFER\_LENGTH를 8191로 설정
>     * 위의 두 값으로 잠재적 BGT 발행량을 계산한 뒤, 현재 BGT 발행량에 더해 outstandingRequiredAmount를 계산
>     * 네이티브 토큰 잔액이 outstandingRequiredAmount값을 넘으면 burnExceedingReserves 함수를 통해 초과한 양 만큼 zero address로 보내 burn

#### Best Practice&#x20;

&#x20;[`BGT.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/pol/BGT.sol#L369)

```solidity
/// @inheritdoc IBGT
function redeem(
    address receiver,
    uint256 amount
)
    external
    invariantCheck
    checkUnboostedBalance(msg.sender, amount)
{
    /// Burn the BGT token from the msg.sender account and reduce the total supply.
    super._burn(msg.sender, amount);
    /// Transfer the Native token to the receiver.
    SafeTransferLib.safeTransferETH(receiver, amount);
    emit Redeem(msg.sender, receiver, amount);
}


function _checkUnboostedBalance(address sender, uint256 amount) private view {
    if (unboostedBalanceOf(sender) < amount) NotEnoughBalance.selector.revertWith();
}


function unboostedBalanceOf(address account) public view returns (uint256) {
    UserBoost storage userBoost = userBoosts[account];
    (uint128 boost, uint128 _queuedBoost) = (userBoost.boost, userBoost.queuedBoost);
    return balanceOf(account) - boost - _queuedBoost;
}

/// @inheritdoc IBGT
function burnExceedingReserves() external {
    IBlockRewardController br = IBlockRewardController(_blockRewardController);
    uint256 potentialMintableBGT = HISTORY_BUFFER_LENGTH * br.getMaxBGTPerBlock();
    uint256 currentReservesAmount = address(this).balance;
    uint256 outstandingRequiredAmount = totalSupply() + potentialMintableBGT;
    if (currentReservesAmount <= outstandingRequiredAmount) return;

    uint256 excessAmountToBurn = currentReservesAmount - outstandingRequiredAmount;
    SafeTransferLib.safeTransferETH(address(0), excessAmountToBurn);

    emit ExceedingReservesBurnt(msg.sender, excessAmountToBurn);
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

[`BlockRewardController.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/pol/rewards/BlockRewardController.sol#L167-L210)

```solidity
/// @inheritdoc IBlockRewardController
function computeReward(
    uint256 boostPower,
    uint256 _rewardRate,
    uint256 _boostMultiplier,
    int256 _rewardConvexity
)
    public
    pure
    returns (uint256 reward)
{
    // On conv == 0, mathematical result should be max reward even for boost == 0 (0^0 = 1)
    // but since BlockRewardController enforces conv > 0, we're not adding code for conv == 0 case
    if (boostPower > 0) {
        // Compute intermediate parameters for the reward formula
        uint256 one = FixedPointMathLib.WAD;

        if (boostPower == one) {
            // avoid approx errors in the following code
            reward = FixedPointMathLib.mulWad(_rewardRate, _boostMultiplier);
        } else {
            // boost^conv ∈ (0, 1]
            uint256 tmp_0 = uint256(FixedPointMathLib.powWad(int256(boostPower), _rewardConvexity));
            // 1 + mul * boost^conv ∈ [1, 1 + mul]
            uint256 tmp_1 = one + FixedPointMathLib.mulWad(_boostMultiplier, tmp_0);
            // 1 - 1 / (1 + mul * boost^conv) ∈ [0, mul / (1 + mul)]
            uint256 tmp_2 = one - FixedPointMathLib.divWad(one, tmp_1);

            // @dev Due to splitting fixed point ops, [mul / (1 + mul)] * (1 + mul) may be slightly > mul
            uint256 coeff = FixedPointMathLib.mulWad(tmp_2, one + _boostMultiplier);
            if (coeff > _boostMultiplier) coeff = _boostMultiplier;

            reward = FixedPointMathLib.mulWad(_rewardRate, coeff);
        }
    }
}
// boostpower = 100%일 경우 발행되는 BGT양
/// @inheritdoc IBlockRewardController
function getMaxBGTPerBlock() public view returns (uint256 amount) {
    amount = computeReward(FixedPointMathLib.WAD, rewardRate, boostMultiplier, rewardConvexity);
    if (amount < minBoostedRewardRate) {
        amount = minBoostedRewardRate;
    }
    amount += baseRate;
}


```

***

### 위협 2: 운영자들이 담합하여 특정 **보상 금고**에만 BGT 보상을 집중, 유동성 쏠림 및 타 프로토콜 유동성 고갈

운영자들이 담합하여 특정 보상 금고에만 BGT 보상을 몰아주면, 일부 보상 금고의 유동성이 고갈되고 타 프로토콜의 유동성도 줄어든다.

#### 영향도

`Medium`

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

### 위협 3: 검증자의 운영자의 인센티브 분배 직전 queue 조작을 통한 보상 탈취 및 사용자 분배 손실

검증자 운영자가 인센티브 분배 직전 인센티브 분배 queue를 조작하여 보상을 탈취하게 될 경우 분배될 사용자 인센티브에 대해 손해가 발생할 수 있다.

#### 영향도

`Low`

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

### 위협 4: 유동성 공급자들의 Boost 담합으로 인한 과도한 BGT 인플레이션

유동성 공급자들이 사전에 담합하여 BGT boost를 모든 Validator들에게 유사한 비율\
(Validator 69명을 기준으로 약 1.44%)로 하게된다면 프로토콜에서 설계한 인플레이션 비율을 훨씬 초과할 수 있다.

#### 영향도

`Low`

#### 가이드라인

> * **인플레이션에 대한 모니터링 필요**
> * **동적인 보상 계산 파라미터를 통해 인플레이션에 대해서 유동적 대응**
> * **BGT 흐름도 분석을 통한 인플레이션 비율 조정**
> * **실시간 보상 배출량 모니터링 시스템 구축 및 이상 징후 감지 메커니즘 설정**
> * **보상 계산식에 대한 명확한 문서화와 커뮤니티 이해를 위한 시각화 자료 제공**

#### Best Practice&#x20;

`커스텀 코드`

```solidity
// BGT 위임 시 순환 부스팅 방지
mapping(address => mapping(address => uint256)) public vaultOriginBGT;
mapping(address => uint256) public lastVaultRewardTime;

function delegateBGT(address validator, uint256 amount) external {
    // 30일 쿨다운 체크
    require(block.timestamp > lastVaultRewardTime[msg.sender] + 30 days, "Cooldown period");
    
    // 셀프 부스팅 금지
    address targetVault = validatorToVault[validator];
    require(vaultOriginBGT[msg.sender][targetVault] == 0, "No self-boosting");
    
    // 분산 위임 강제 (최대 20%)
    uint256 totalBGT = bgtToken.balanceOf(msg.sender);
    require(delegatedAmount[msg.sender][validator] + amount <= totalBGT * 20 / 100, "Max 20% per validator");
    
    _delegate(validator, amount);
}

// 인플레이션 제어
function checkInflationLimit() external view returns (bool) {
    uint256 weeklyInflation = calculateWeeklyInflation();
    uint256 targetWeekly = TARGET_ANNUAL_INFLATION / 52; // 10% / 52주
    
    return weeklyInflation <= targetWeekly * 130 / 100; // 30% 여유분
}
```

***

### 위협 5: 인센티브 토큰이 고갈된 뒤에 추가 공급을 하지 않으면 검증자의 부스트 보상 감소

인센티브 토큰이 고갈된 후 추가 공급이 이뤄지지 않으면 검증자의 부스트 보상이 급격히 감소한다. \
보상금고의 인센티브 토큰 잔고를 실시간으로 확인할 수 없다면 검증자가 보상 감소를 사전에 인지하지 못한다.

#### 영향도

`Low`

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

### 위협 6: 인센티브 토큰이 고갈 된 후 보상 비율을 낮춰 해당 보상 금고를 선택한 검증자의 부스트 APR 감소

인센티브 토큰이 고갈된 후, 인센티브 비율이 낮아져 해당 보상금고를 선택한 검증자의 부스트 APR이 감소한다. 권한 관리가 미흡하면, 임의로 인센티브 비율이 조정되어 피해가 발생할 수 있다.

#### 영향도

`Low`

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

### 위협 7: claimFees() 프론트 러닝에 따른 사용자의 수수료 보상 왜곡&#x20;

`claimFees()`함수를 호출하는 사용자 앞에서 프론트 러닝을 통한 트랜잭션 선점 시 수수료 보상이 왜곡될 수 있다.

#### 영향도

`Low`

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
