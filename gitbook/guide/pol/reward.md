---
icon: sack-dollar
---

# PoL 보안 가이드라인: 보상 분배

<table><thead><tr><th width="617.40625">위협</th><th align="center">영향도</th></tr></thead><tbody><tr><td><a data-mention href="reward.md#id-1">#id-1</a></td><td align="center"><code>Medium</code></td></tr><tr><td><a data-mention href="reward.md#id-2">#id-2</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="reward.md#id-3-erc-20">#id-3-erc-20</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="reward.md#id-4">#id-4</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="reward.md#id-5">#id-5</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="reward.md#id-6">#id-6</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="reward.md#id-7-lp-notifyrewardamount">#id-7-lp-notifyrewardamount</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="reward.md#id-8">#id-8</a></td><td align="center"><code>Low</code></td></tr></tbody></table>

### 위협 1: 재진입 공격을 통해 보상 중복 청구

컨트랙트 함수 중 토큰의 흐름을 제어하는 함수에 대한 재진입을 허용할 경우 재진입 공격에 의한 토큰 무단 인출 문제로 시스템 전체의 손해로 이어질 수 있다.

#### 영향도

`Medium`&#x20;

재진입 공격 성공 시 특정 사용자가 정당한 보상 이상을 중복으로 인출하여 프로토콜 또는 다른 사용자들에게 직접적인 재정적 손실을 야기할 수 있기 때문에`Medium`으로 평가한다.

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

### 위협 2: 권한 없는 사용자의 인센티브 토큰 조작 및 사용

권한이 없는 사용자가 인센티브 토큰을 임의로 추가하거나 중복 등록하여, 시스템에서 과도한 보상을 받는 상황이 발생할 수 있다. 화이트리스트와 토큰 개수 제한, 중복 방지 로직이 없다면 악의적 사용자가 인센티브 구조를 교란시킬 수 있다.

#### 영향도

`Low`

공격자가 악의적인 토큰을 인센티브 토큰에 추가하면 검증자 및 사용자의 보상을 가로채거나 인센티브율을 증가시켜 프로토콜의 인센티브 토큰을 빠르게 감소 시킬 수 있다. 그러나 토큰 등록은 거버넌스를 통한 과정이기 때문에`Low`로 평가한다.

#### 가이드라인

> * **인센티브 토큰 화이트리스트 관리 시 인센티브 토큰 개수 제한 및 중복 등록 방지**
>   * **인센티브 토큰 추가 권한:** Factory Owner
>   * **인센티브 토큰 제거 권한:** Factory Vault Manager
>   * 현재 인센티브 토큰 최대 3개 등록 가능
> *   **보상 비율 설정 시 최대/최소 범위 검증 및 매니저 권한 제한**
>
>     * 인센티브 토큰 추가 시 `minIncentive > 0`  검증 진행
>
>     ```solidity
>     // validate `minIncentiveRate` value
>     if (minIncentiveRate == 0) MinIncentiveRateIsZero.selector.revertWith();
>     if (minIncentiveRate > MAX_INCENTIVE_RATE) IncentiveRateTooHigh.selector.revertWith();
>     ```
>
>     * 인센티브 비율 변경시 최소 비율보다 높게 설정
>
>     ```solidity
>     // The incentive amount should be equal to or greater than the `minIncentiveRate` to avoid spamming.
>     if (amount < minIncentiveRate) AmountLessThanMinIncentiveRate.selector.revertWith();
>
>     // The incentive rate should be greater than or equal to the `minIncentiveRate`.
>     if (incentiveRate < minIncentiveRate) InvalidIncentiveRate.selector.revertWith();
>     ```
>
>     * 현재 incentive manager 권한
>       * `addIncentive()`, `accountIncentives()` 으로 인센티브 토큰 물량 추가 가능
> * **ERC20 토큰 회수 시 인센티브 토큰 및 예치 토큰을 제외하고 전송**

#### Best Practice&#x20;

[`RewardVault.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/pol/rewards/RewardVault.sol#L164-L174)&#x20;

```solidity
function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyFactoryOwner {
    // incentive token 현재 활성화 상태 체크
    if (incentives[tokenAddress].minIncentiveRate != 0) CannotRecoverIncentiveToken.selector.revertWith();
    
    // stake token 체크
    if (tokenAddress == address(stakeToken)) {
        uint256 maxRecoveryAmount = IERC20(stakeToken).balanceOf(address(this)) - totalSupply;
        if (tokenAmount > maxRecoveryAmount) {
            NotEnoughBalance.selector.revertWith();
        }
    }
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

### 위협 3: 인센티브 토큰 ERC-20 표준 미검증으로 인한 위협

인센티브 토큰에 대한 ERC20 표준 준수 여부 등의 검증 절차 누락 시 네트워크 보상 처리 과정에서 승인량 불일치나 전송 실패로 인해 자산 손실이 발생할 수 있다.

#### 영향도

`Low`&#x20;

ERC-20 표준 미준수 토큰이나 승인 과정 오류는 특정 트랜잭션에서 의도치 않은 토큰 전송 실패, 수량 불일치 등을 유발하여 부분적인 자산 손실이나 기능 장애를 초래할 수 있기 때문에 `Low`로 평가한다.

**가이드라인**

> * **안전한 토큰 승인 및 전송**
>   * 거래별 정확한 승인량 계산 및 설정
>   * 승인량과 실제 사용량 일치 검증
>   * 모든 토큰 전송 후 반환값 검증 및 전송 실패 시 전체 롤백
> * **토큰 표준 호환성 검증**
>   * ERC-20 표준 준수 여부 사전 검증
> * **토큰 화이트리스트 관리**
>   * 지원 토큰 사전 심사 및 승인 절차
>   * 악성 토큰 블랙리스트 운영 및 실시간 업데이트

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

### 위협 4: 컨트랙트 초기화 시 잘못된 구성으로 인한 시스템 오류

컨트랙트 초기 배포 과정에서 필수 검증 절차와 필터링 기능 누락 시 잘못된 설정으로 인한 시스템 오류 발생 가능성이 존재한다

#### 영향도

`Low`&#x20;

잘못된 컨트랙트의 주소가 설정되어 배포가 된다면 정상적인 기능을 작동하지 않을 수 있다. 자산의 탈취보다는 일시적인 기능의 정지 가능성 때문에 `Low`로 평가되지만, 업그레이드 가능한 컨트랙트의 경우 재초기화 방지가 중요하며, Parity Wallet과 같은 사례에서 보았듯이 심각한 결과를 초래할 수 있다.

#### 가이드라인

> * **모든 컨트랙트 초기화 시 zero address 검증 및 필수 매개변수 검증**
> * **초기 설정 매개변수들의 합리적 범위 검증**
> * **초기 예치 루트 설정 등 초기 상태의 무결성 보장**
> * **초기화 함수의 불변성 보장 및 재초기화 방지 메커니즘(예: \_\_disableInitializers() 사용)**
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

### 위협 5: 잘못된 접근 제어로 인한 권한 없는 보상 인출 또는 조작

컨트랙트 접근 제어를 정확하게 처리하지 못할 경우 의도하지 않은 악성 사용자의 접근으로 인한 보상 인출 또는 조작 발생 가능성이 존재한다

#### 영향도

`Low`&#x20;

공격자가 다른 유저의 보상을 탈취하는 건 큰 위협이지만 `onlyOperatorOrUser` modifier로 예치자 혹은 대리인만 수령 가능해 발생 가능성이 낮아 `Low`로 평가한다.

#### 가이드라인

> * **관리자 활동(권한 변경, 중요 함수 호출 등)에 대한 이벤트 로깅**
> * **`onlyOwner`, `onlyDistributor`등 modifier를 명확히 사용**&#x20;
> * **각 주소, 역할 또는 컴포넌트에 최소 권한 원칙 준수**

<table><thead><tr><th width="135.546875" align="center">Role</th><th width="556.265625">Responsibilities &#x26; Permissions</th><th data-hidden>관련 함수 예시 (Example Functions)</th></tr></thead><tbody><tr><td align="center">Owner</td><td>- 컨트랙트의 전체 소유권 보유<br>- Admin 역할 임명 및 해임<br>- 컨트랙트의 가장 핵심적인 파라미터 설정 (예: 인센트브 토큰 추가, 일시 중지/재개 권한 위임 등)<br>- 컨트랙트 업그레이드 실행 (프록시 패턴 사용 시)</td><td>transferOwnership(address newOwner), addAdmin(address admin), removeAdmin(address admin), setProtocolFee(uint256 fee), pause(), unpause(), upgradeTo(address newImplementation)</td></tr><tr><td align="center">Operator </td><td>- 일상적인 시스템 운영 작업 수행 (Owner 보다 제한된, 특정 기능 실행 권한)<br>- 주기적인 프로세스 실행 (예: 보상 분배 로직 트리거, 오라클 가격 정보 업데이트)<br>- 시스템 상태 모니터링 및 관련 데이터 기록</td><td>triggerRewardDistribution(), updatePriceOracle(address asset, uint256 price), recordSystemMetrics()</td></tr><tr><td align="center">User </td><td>- 프로토콜의 핵심 기능 사용 (예: 자산 예치, 스왑, 대출, 상환)<br>- 자신의 계정 관련 정보 조회 및 관리 (예: 잔액 확인, 보상 청구)<br>- 거버넌스 참여 (토큰 홀더의 경우, 투표 등)</td><td>deposit(address asset, uint256 amount), withdraw(address asset, uint256 amount), claimRewards(), getBalance(address user, address asset), voteOnProposal(uint256 proposalId, bool support)</td></tr></tbody></table>

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

modifier onlyOperatorOrUser(address account) {
    if (msg.sender != account) {
        if (msg.sender != _operators[account]) NotOperator.selector.revertWith();
    }
    _;
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

### 위협 6: 보상 분배 계산 과정 중 나눗셈 연산 정밀도 오류 발생 시 사용자 보상 미세 손실 누적 가능

보상 분배 계산 중 나눗셈 정밀도 오류로 인해, 일부 사용자의 보상이 소수점 이하로 계속 손실되어 누적된다

#### 영향도

`Low`&#x20;

컨트랙트의 계산 정밀도 한계로 인해 사용자가 받아야 할 보상이 약속된 양보다 적게 지급될 수 있으나, 대부분의 금융 시스템에서의 허용(0.01%) 되는 미세한 차이고 의도적인 탈취가 아니기 때문에`Low`로 평가한다.

#### 가이드라인

> * **보상 수령 금액의 정확성을 검증하는 로직 추가**
>   * **`_verifyRewardCalculation`**  함수를 통해 계산 결과를 역연산하여 보상 금액 검증
>   * 오차 범위 0.01%로 설정 (대부분 금융에서 사용하는 오차 범위)
> *   **사용자 유리한 반올림 정책**
>
>     * 보상 받을 금액이 존재하지만 나눗셈 절삭되어 0이 된다면 최소값(1 wei) 으로 보장
>
>     ```solidity
>     if (balance > 0 && earnedAmount == 0 && rewardPerTokenDelta > 0) {
>         earnedAmount = 1; // 최소 1 wei 보장
>     }
>     ```

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
        
        unchecked {
            for (uint256 i; i < whitelistedTokensCount; ++i) {
                // ...
                
                uint256 amount = FixedPointMathLib.mulDiv(bgtEmitted, incentive.incentiveRate, PRECISION);
                
                uint256 amountRemaining = incentive.amountRemaining;
                amount = FixedPointMathLib.min(amount, amountRemaining);
                
                uint256 validatorShare;
                if (amount > 0) {
                    validatorShare = beraChef.getValidatorIncentiveTokenShare(pubkey, amount);
                    
                    // 검증: validator share가 전체 amount를 초과하지 않는지 확인
                    require(validatorShare <= amount, "Invalid share calculation");
                    
                    amount -= validatorShare;
                }
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
            require((reverseCalc <= rewardRate * 10001) / (10000 && rewardRate * 10001 / 10000 <= reverseCalc), "Calculation error");
        }
    }
    
    // ... 기존 코드 ...
}
```

***

### 위협 7: LP 토큰 전량 인출 및 notifyRewardAmount 호출로 인한 보상 중복 누적

`notifyRewardAmount` 호출 후 모든 LP 토큰을 인출해 잔고를 0으로 만들면 보상 잔액이 두 번 누적되어 보상 총액 기록이 비정상적으로 증가할 수 있다

이후 스테이킹이 재개되면 APR이 급등하고 allowance가 부족할 경우 InsolventReward revert가 발생할 수 있다 \
반대로 LP 토큰 잔고가 0인 상태에서 `notifyRewardAmount`가 먼저 실행되면 보상 잔액이 다음으로 이월되지 않아 해당 보상이 증발할 수 있다

#### 영향도

`Low`&#x20;

보상 분배 로직의 일시적인 계산 오류나 보상 증발/중복을 발생할 수 있으나 totalsupply가 0이 될 발생 가능성이 낮아 `Low`로 평가한다.

#### 가이드라인

> * **리워드 볼트 생성시 최소 LP 토큰 예치로 totalsupply가 0이 되는 것을 방지**

#### Best Practice&#x20;

`커스텀 코드`

```solidity
// 최소 LP 토큰 예치 요구사항 적용
contract RewardVaultFactory {
    // ... 기존 코드 ...
    
    // 최소 LP 토큰 예치량 설정
    uint256 public constant MIN_INITIAL_LP_AMOUNT = 1e6; // 예: LP 토큰
    
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

### 위협 8: 정상적인 인센티브 토큰 제거에 따른 보상 중단

정상적인 인센티브 토큰 제거 시 갑작스러운 사용자 보상 중단으로 인한 사용자 혼란이 발생할 수 있고 보상 구조의 변경으로 인한 문제 발생 가능성이 존재한다.

#### 영향도

`Low`&#x20;

보상을 받을 사용자가 남아있는 상황에서 관리자가 인센티브 제거를 할 경우 사용자는 보상을 잃게 된다. 하지만 관리자는 거버넌스에 의해 정해지기에 발생 가능성이 낮기 때문에 `Low`로 평가한다.

#### 가이드라인

> * **인센티브 토큰 제거 또는 교체는 큐를 이용하여 딜레이(3 hours) 이후 반영**
>   *   BGTIncentiveDistributor에서 인센티브 보상 청구 대기시간의 최대치인 MAX\_REWARD\_CLAIM\_DELAY를 3시간으로 통일하기 위함
>
>       ```solidity
>       // BGTIncentiveDistributor.sol
>       uint64 public constant MAX_REWARD_CLAIM_DELAY = 3 hours;
>       ```
>   * 큐에 넣기 위해서는 검증 로직 통과해야 함
>     * 인센티브 토큰 제거
>       * 현재 해당 인센티브 토큰의 잔액이 없어야 함
>       * FactoryVaultManager 여야 함
>       * 제거할 토큰이 화이트리스트에 등록되어있는 토큰이어야 함
>     * 인센티브 토큰 추가
>       * FactoryOwner만 추가가능
>   * 제거 큐에 들어가있는 토큰에는 addIncentive 불가
> * **보상 금고의 보상 구조 변경(토큰 추가/제거)은 사용자에게 사전 고지 및 명확한 UI 표시**
>   * IncentiveTokenWhitelisted와 IncentiveTokenRemoved 이벤트를 읽어오는 봇을 만들어 변화가 생기면 프로토콜 사이트에 팝업 표시

#### Best Practice&#x20;

`커스텀 코드`

```solidity
// 1. 상태변수 및 구조체 선언
// 추가 요청 구조체
struct AddIncentiveTokenRequest {
    uint256 minIncentiveRate;
    address manager;
    uint256 requestTimestamp;
    bool exists;
}

// 제거 요청 구조체
struct RemoveIncentiveTokenRequest {
    uint256 requestTimestamp;
    bool exists;
}

// 각각의 큐(매핑)
mapping(address => AddIncentiveTokenRequest) public addIncentiveTokenQueue;
mapping(address => RemoveIncentiveTokenRequest) public removeIncentiveTokenQueue;

// 딜레이 기간(3시간)
uint256 public constant INCENTIVE_TOKEN_REQUEST_DELAY = 3 hours;

// 큐에 넣는 함수들
// 인센티브 토큰 추가 요청
function queueAddIncentiveToken(address token, uint256 minIncentiveRate, address manager) external onlyFactoryOwner {
    require(!addIncentiveTokenQueue[token].exists, "RewardVault: Add request already queued");
    require(!removeIncentiveTokenQueue[token].exists, "RewardVault: Remove request pending");
    addIncentiveTokenQueue[token] = AddIncentiveTokenRequest({
        minIncentiveRate: minIncentiveRate,
        manager: manager,
        requestTimestamp: block.timestamp,
        exists: true
    });
    emit IncentiveTokenAddQueued(token, minIncentiveRate, manager, block.timestamp);
}

// 인센티브 토큰 제거 요청
function queueRemoveIncentiveToken(address token) external onlyFactoryVaultManager onlyWhitelistedToken(token) {
    require(!removeIncentiveTokenQueue[token].exists, "RewardVault: Remove request already queued");
    require(incentives[token].amountRemaining == 0, "RewardVault: Incentive token has remaining balance");
    removeIncentiveTokenQueue[token] = RemoveIncentiveTokenRequest({
        requestTimestamp: block.timestamp,
        exists: true
    });
    emit IncentiveTokenRemoveQueued(token, block.timestamp);
}

// 3. 실행 함수
// 추가 요청 실행
function executeAddIncentiveToken(address token) external {
    AddIncentiveTokenRequest storage req = addIncentiveTokenQueue[token];
    require(req.exists, "RewardVault: No add request");
    require(block.timestamp >= req.requestTimestamp + INCENTIVE_TOKEN_REQUEST_DELAY, "RewardVault: Delay not passed");

    _whitelistIncentiveToken(token, req.minIncentiveRate, req.manager);

    delete addIncentiveTokenQueue[token];
}

// 제거 요청 실행
function executeRemoveIncentiveToken(address token) external {
    RemoveIncentiveTokenRequest storage req = removeIncentiveTokenQueue[token];
    require(req.exists, "RewardVault: No remove request");
    require(block.timestamp >= req.requestTimestamp + INCENTIVE_TOKEN_REQUEST_DELAY, "RewardVault: Delay not passed");

    _removeIncentiveToken(token);

    delete removeIncentiveTokenQueue[token];
}

// 4. 내부 실제 처리함수
function _whitelistIncentiveToken(address token, uint256 minIncentiveRate, address manager) internal {
    // 기존 whitelistIncentiveToken 내용
}

function _removeIncentiveToken(address token) internal {
    // 기존 removeIncentiveToken 내용
}

// 5. addIncentive에서 제거 큐 체크
function addIncentive(
    address token,
    uint256 amount,
    uint256 incentiveRate
)
    external
    nonReentrant
    onlyWhitelistedToken(token)
{
    // 제거 큐에 들어간 토큰은 인센티브 추가 불가
    require(!removeIncentiveTokenQueue[token].exists, "RewardVault: Token is pending removal");
    // ... 이하 기존 로직 ...
}


```
