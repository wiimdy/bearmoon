---
description: >-
  여러 dApp의 기능을 연쇄적으로 조합하여 사용하는 복합 DeFi 전략은 고수익 기회를 제공한다.  하지만 이러한 dApp 체이닝은 개별
  dApp 사용 시에는 드러나지 않았던 새로운 상호작용 위험을 발생시키고 기존 위험을 증폭시킬 수 있다.
icon: link
layout:
  title:
    visible: true
  description:
    visible: true
  tableOfContents:
    visible: true
  outline:
    visible: true
  pagination:
    visible: true
---

# dApp 보안 가이드라인: 체이닝

<table><thead><tr><th width="595">위협</th><th align="center">영향도</th></tr></thead><tbody><tr><td><a data-mention href="chain.md#id-1-dex-erc-4626">#id-1-dex-erc-4626</a></td><td align="center"><code>Medium</code></td></tr><tr><td><a data-mention href="chain.md#id-2-honey-permissionlesspsm.sol">#id-2-honey-permissionlesspsm.sol</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="chain.md#id-3">#id-3</a></td><td align="center"><code>Informational</code></td></tr></tbody></table>

### 위협 1: DEX 풀 불균형 연쇄청산으로 인한 ERC-4626 인플레이션 공격

BeraBorrow는 베라체인의 PoL 메커니즘과 긴밀하게 통합되어 있으며, Infrared의 iBGT, iBERA 토큰과 Kodiak, BEX 등의 DEX LP 토큰을 담보로 사용한다. 이러한 복잡한 상호의존성은 LSP의 ERC-4626 인플레이션 공격 취약점과 연쇄적으로 결합될 때 심각한 시스템 위험을 초래할 수 있다.

**공격 시나리오**

1. 공격자가 베라체인 DEX에서 대량 거래를 통해, Beraborrow에서 담보로 사용되는 LP를 발행하는 유동성 풀(예: kodiak의 HONEY-BERA)의 불균형을 유발한다.&#x20;
2. LP 토큰 가치 하락으로 담보비율(ICR)이 최소담보비율(MCR) 이하로 떨어지면서 대량 청산이 시작된다. 청산 규모가 LSP의 NECT 잔액을 초과하면서 LSP 예치자들의 대량 인출 러시가 발생한다.
3. 연쇄 청산과 인출 러시로 LiquidStabilityPool(LSP)의 totalSupply가 거의 0에 가까운 상태에 도달한다. Beraborrow LSP는 BaseCollateralVault와 달리 virtual accounting 메커니즘을 구현하지 않았으며, deposit/mint 함수에서 totalSupply=0 보호장치가 없다.
4. 공격자가 1 wei의 NECT를 예치하여 100% 지분을 획득한 후, NECT 토큰을 LSP 컨트랙트로 직접 대량 전송한다. DebtToken의 \_requireValidRecipient 함수는 LSP 주소를 차단하지 않으며, LSP의 totalAssets() 함수는 도네이션된 NECT를 자산 계산에 포함하지 않는다.
5. 후속 예치자가 NECT를 예치할 때 ERC-4626의 convertToShares 계산에서 Solidity 반올림으로 인해 0 shares를 받게 되고, 공격자는 전체 잔액을 인출하여 이익을 실현한다.

**시스템적 위험**

* 이 연쇄적 공격은 베라체인의 PoL 메커니즘과 Beraborrow 다중 담보 대출 시스템 간 상호의존성을 악용하여 단일 취약점을 시스템 전체 위험으로 확대시킨다. Infrared의 iBGT, iBERA 토큰들이 주요 담보로 사용되어 DEX 풀 불균형이 Infrared 스테이킹 플랫폼, Beraborrow 대출 시스템, LSP에 걸쳐 도미노 효과를 일으킬 수 있다. 따라서 LSP의 ERC-4626 인플레이션 공격 취약점은 단순한 스마트 컨트랙트 버그를 넘어 베라체인 생태계 전반의 시스템적 위험으로 평가되어야 한다.

#### 영향도

`Medium`&#x20;

이 공격은 LiquidStabilityPool(LSP)의 총 공급량(totalSupply)이 0에 가까워지는 특수한 조건 하에서만 실행 가능하다. 하지만 성공할 경우 LSP 예치자의 자금을 직접적으로 탈취할 수 있으므로 **`Medium`**&#xC73C;로 평가한다. 영향도 평가는 다음 근거에 기반한다.

1. **제한된 공격 표면:** 이 공격 시나리오는 BeraBorrow에서 담보로 허용된 모든 자산이 아닌, **특정 DEX의 LP 토큰**에서 시작된다. 공격자는 BeraBorrow가 담보로 사용하는 LP 토큰 중에서도 상대적으로 유동성이 낮아 가격 조작이 용이한 풀을 타겟으로 해야 하므로 공격의 전제 조건이 제한적이다. 또한, 인플레이션 공격 자체도 BeraBorrow 내의 **모든 볼트가 아닌  LiquidStabilityPool과 같이 virtual accounting 방어 로직이 부족한 특정 볼트**에 한정된다.
2. **조건부 공격 가능성 (LSP 고갈 상황):** 공격의 핵심 단계는 LSP의 totalSupply가 거의 0으로 수렴하는 것이다. 이는 정상적인 프로토콜 상태가 아니며, 대규모 연쇄 청산과 예치자들의 대량 인출이라는 **극단적인 시장 스트레스 상황**에서만 발생할 수 있다. 따라서 공격자는 시장을 원하는 방향으로 움직일 막대한 자본이 필요하며, 공격 시점이 매우 제한적이다.
3. [취약점 패턴 레퍼런스](https://docs.openzeppelin.com/contracts/5.x/erc4626)**:** LSP의 totalSupply가 0에 가까워졌을 때 1 wei 예치를 통해 지분을 독점하고, 이후 자산 기부로 share의 가치를 부풀려 후속 예치자의 자금을 탈취하는 방식은 잘 알려진 **ERC-4626 인플레이션 공격** 벡터다. OpenZeppelin 등 다수의 보안 감사 보고서에서는 이러한 공격의 위험성을 경고하고 방어 기법 적용을 권장하고 있어, 이 공격이 BeraBorrow의 LSP에 이론적으로 적용 가능하다는 점은 무시할 수 없는 위험이다.

#### 가이드라인

> * **Dex 풀의 불균형 발생 시 LP 토큰을 담보로 하는  Lending 프로토콜에 경고 시스템 제작**
> * **Virtual Accounting 시스템 구현**
> * **LiquidStabilityPool(LSP) 컨트랙트에 BaseCollateralVault와 동일한 virtual accounting 메커니즘 도입내부 balance 추적과 실제 토큰 잔액 분리를 통한 도네이션 공격 차단**
> * **최소 예치금 임계값 설정**
>   * LSP deposit/mint 함수에 최소 예치금 요구사항 추가&#x20;
>   * 초기 예치 시 더 높은 최소 금액 설정으로 공격 비용 증가
> * **totalSupply=0 상태 보호 강화**
>   * 모든 예치 함수에 ZeroTotalSupply 체크 확장 적용 linearVestingExtraAssets 함수에만 존재하는 보호를 전체 시스템으로 확산
> * **부트스트랩 기간 보호 메커니즘**
>   * 초기 24-48시간 동안 예치 제한 및 추가 검증 절차 적용
>   * 부트스트랩 기간 중 관리자 승인 없이는 대량 예치 차단
> * **LSP-DenManager 간 실시간 청산 모니터링**
>   * 대량 청산 발생 시 LSP 인출 임시 제한 및 경고 시스템 작동연쇄 청산으로 인한 LSP 고갈 상황 사전 감지
> * **비정상적 예치/인출 패턴 감지**
>   * 단일 트랜잭션에서 극소량 예치 후 대량 자산 전송 패턴 모니터링
>   * 플래시론과 연계된 복합 공격 시나리오 실시간 탐지
> * **LSP-DEX 간 유동성 상관관계 추적**
>   * 베라체인 DEX 풀 불균형이 LSP 안정성에 미치는 영향 실시간 분석

#### Best Practice&#x20;

`커스텀 코드`

```solidity
// LP 토큰의 건정성을 확인하는 함수
function updateLpTokenRisk(address _lpToken, bool _isHighRisk) external onlyOwner {
// owner의 권한 분산을 위해 실제 구현 시에는 onlyOwner를 Multi-Sig, Timelock 등으로 변경이 필요하다.
    require(_lpToken != address(0), "LP token: zero address"); 
    if (lpTokenIsHighRisk[_lpToken] != _isHighRisk) {
        lpTokenIsHighRisk[_lpToken] = _isHighRisk;
        emit LpTokenRiskStatusUpdated(_lpToken, _isHighRisk);
        // 이 이벤트는 오프체인 경고 시스템에 의해 감지되어 사용자에게 알림을 보낼 수 있다.
    }
}
```

```solidity
// 1. Virtual accounting 추가
mapping(address => uint) internal virtualAssetBalance;

function totalAssets() public view override returns (uint) {
    return virtualAssetBalance[asset()]; 
}

// 2. deposit 함수에 보호 로직 추가
function _depositAndMint(/*...*/) private {
    if (totalSupply() == 0) {
        require(assets >= 1000e18, "LSP: Minimum initial deposit");
    }
    
    _provideFromAccount(msg.sender, assets);
    virtualAssetBalance[asset()] += assets; // Virtual balance 추적
    
    // 기존 로직...
}
```

***

### 위협 2: HONEY 디페깅과 PermissionlessPSM.sol을 이용한 프로토콜 자산 탈취

HONEY의 시장 가격이 폭락했음에도  Beraborrow의`PermissionlessPSM.sol`이  1:1로 NECT를 민팅할 경우, 공격자는 저렴해진 HONEY로 대량의 NECT를 확보한다.  이후 이 NECT를 대출 프로토콜에서 고정된 가치로 담보 상환에 악용하여 프로토콜의 자산을 고갈시킨다.

**핵심 취약점**

NECT의 가격 결정 메커니즘: \_whitelistStable 함수 내에서 `wadOffset = (10 ** (nect.decimals() - stable.decimals())`로 HONEY와 NECT 간의 교환 비율 오프셋을 설정한다. 이는 단순히 두 토큰의 소수점 자릿수 차이를 보정하는 역할만 하며, HONEY의 실제 시장 가격을 반영하는 오라클과 연동되어 있지 않는다. 따라서 HONEY의 외부 시장 가격이 폭락하더라도 Beraborrow의 PermissionlessPSM.sol은 여전히 고정된 오프셋인 1:1로 NECT를 민팅해준다.

[PermissionlessPSM](https://berascan.com/address/0xb2f796fa30a8512c1d27a1853a9a1a8056b5cc25#readContract) 컨트랙트와 [HONEY](https://berascan.com/address/0xFCBD14DC51f0A4d49d5E53C2E0950e0bC26d0Dce) 토큰 주소의 온체인 데이터를 직접 분석한 결과, HONEY를 이용한 NECT 발행 한도(**mintCap**)는 **15,000,000 NECT**로 설정되어 있음을 확인할 수 있었다.

이는 프로토콜이 **최대 1천 5백만 달러 규모의 잠재적 위험에 직접적으로 노출되어 있음**을 의미한다. 해당 취약점은 단순한 이론적 가능성이 아니라 컨트랙트에 명시된 한도만큼 실제 자산 유출로 이어질 수 있는 명백하고 매우 심각한 위협이다.

**시뮬레이션: 현재 mintCap(15M) 기반의 손실 규모 분석**

* **상황 가정**: 외부 요인으로 HONEY의 시장 가치가 **$0.50으로 폭락**
* **공격 실행**
  * 공격자는 외부 시장에서 **$7,500,000**를 투입하여 mintCap 한도인 15,000,000 HONEY를 전량 매집
  * 공격자는 PermissionlessPSM.sol의 deposit 함수를 호출하여 15,000,000 HONEY를 입금하고, 가격 오라클이 없는 시스템의 허점을 이용해 약 **15,000,000 NECT** (수수료 제외 시 약 14,955,000)를 발행
* **프로토콜 손실 규모**
  * 프로토콜의 금고에는 실제 가치 **$7,500,000**의 자산(HONEY)이 들어옴
  * 프로토콜의 부채는 시스템 내에서 $1로 취급되는 **$15,000,000** 만큼 증가함
  * 결과적으로, 이 공격이 성공할 경우 프로토콜은 **약 $7,500,000의 자산을 즉시 상실**

#### 영향도

`Low`

디페깅 시 공격자가 저가 HONEY로 NECT를 민팅해 차익을 실현할 수 있으며, 프로토콜은 자산 손실 위험에 노출됨. 영향도는 HONEY 디페깅 정도와 프로토콜 자산 규모에 따라 `Low`에서 `Medium`으로 조정될 수 있으며, 차익 거래로 HONEY 가치 회복 가능성은 제한적일 수 있음.

#### 가이드라인

> * **신뢰할 수 있는 가격 오라클 연동**
>   * deposit 및 mint 함수 로직을 수정하여 NECT 발행량을 계산할 때 반드시 외부 가격 오라클을 통해 HONEY/USD 가격을 조회하도록 변경해야 한다.
>   * 다중 오라클 시스템을 도입하여 가격 데이터의 조작이나 일시적인 장애에 대응해야 한다.
> * **동적 수수료 및 발행량 제한 메커니즘 도입**
>   * 오라클 가격이 단기간에 급락하는 경우, deposit에 대한 수수료를 동적으로 인상하는 로직을 추가한다. 이를 통해 소규모 디페깅 상황에서 차익 거래 공격의 유인을 감소시키는 효과가 있다.
> * **거버넌스 및 비상 대응 프로토콜 강화**
>   * 다중 서명을 주체가 HONEY를 이용한 NECT 신규 발행을 즉시 중지시킬 수 있는 pauseDeposit과 같은 함수를 permissionlessPSM.sol에 구현해야 한다.

#### Best Practice

`커스텀 코드`

```solidity
// Best Practice가 적용될 컨트랙트: PermissionlessPSM.sol

// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// --- 기존 import 구문 ---
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {FeeLib} from "src/libraries/FeeLib.sol";
import {IMetaBeraborrowCore} from "src/interfaces/core/IMetaBeraborrowCore.sol";
import {IDebtToken} from "src/interfaces/core/IDebtToken.sol";
import {IFeeHook} from "src/interfaces/utils/integrations/IFeeHook.sol";
// --- 신규 import ---
import {IPriceFeed} from "src/interfaces/IPriceFeed.sol"; // Beraborrow의 가격 피드 인터페이스

/**
 * @title PermissionlessPSM
 * @author Beraborrow Team
 * @notice 가격 오라클과 연동되고, 스테이블코인별 입금 정지 기능이 추가된 PSM
 */
contract PermissionlessPSM {
    // --- 기존 상태 변수 ---
    using Math for uint;
    using SafeERC20 for IERC20;
    using FeeLib for uint;

    uint16 public constant DEFAULT_FEE = 30; // 0.3%
    uint16 constant BP = 1e4;

    IMetaBeraborrowCore public metaBeraborrowCore;
    IDebtToken public nect;
    IFeeHook public feeHook;
    address public feeReceiver;
    bool public paused; // 전체 컨트랙트 일시정지
    mapping(address stable => uint) public nectMinted;
    mapping(address stable => uint) public mintCap;
    mapping(address => uint64 wadOffset) public stables;
    
    // --- 신규/수정된 상태 변수 ---
    IPriceFeed public priceFeed;
    // 특정 스테이블코인의 입금 가능/불가능 상태 관리
    mapping(address stable => bool) public depositPausedFor; 

    // --- 기존 에러 및 이벤트 ---
    error OnlyOwner(address caller);
    error AddressZero();
    error AmountZero();
    error Paused();
    error NotListedToken(address token);
    error AlreadyListed(address token);
    error PassedMintCap(uint mintCap, uint minted);
    error SurpassedFeePercentage(uint feePercentage, uint maxFeePercentage);
    error DepositForTokenPaused(address stable); // 신규 에러

    // ... (기존 이벤트) ...
    event DepositForTokenPauseSet(address indexed stable, bool isPaused); // 신규 이벤트
    event PriceFeedSet(address newPriceFeed); // 신규 이벤트


    // --- 핵심 수정 함수: previewDeposit ---
    function previewDeposit(address stable, uint stableAmount, uint16 maxFeePercentage) public view returns (uint mintedNect, uint nectFee) {
        // 방어 로직
        if (depositPausedFor[stable]) revert DepositForTokenPaused(stable);
        
        uint64 wadOffset = stables[stable];
        if (wadOffset == 0) revert NotListedToken(stable);

        // --- 가격 오라클 연동 로직 ---
        uint stablePrice = priceFeed.fetchPrice(stable); // 1. 오라클에서 stable/USD 가격 조회
        require(stablePrice > 0, "Invalid price from oracle");

        // 2. 입금된 stable 토큰의 실제 USD 가치 계산 (토큰의 소수점 자리수 고려)
        uint stableValueInUSD = (stableAmount * stablePrice) / (10 ** IERC20Metadata(stable).decimals());
        
        // 3. NECT는 $1 가치를 가지므로, 계산된 USD 가치가 곧 발행될 NECT의 양이 됨
        uint grossMintedNect = stableValueInUSD;
        // --- ---

        uint fee = feeHook.calcFee(msg.sender, stable, grossMintedNect, IFeeHook.Action.DEPOSIT);
        fee = fee == 0 ? DEFAULT_FEE : fee;
        if (fee > maxFeePercentage) revert SurpassedFeePercentage(fee, maxFeePercentage);

        nectFee = grossMintedNect.feeOnRaw(fee);
        mintedNect = grossMintedNect - nectFee;
    }

    // --- 거버넌스용 신규/수정 함수 ---

    /**
     * @notice (기존 아이디어 구현) 특정 스테이블코인의 가격 불안정성을 설정하여 입금을 중단/재개
     * @dev onlyOwner: 거버넌스 또는 신뢰된 주체만이 호출 가능
     * @param stable 불안정성이 감지된 스테이블코인 주소 (예: HONEY)
     * @param isUnstable true로 설정 시 해당 토큰의 입금(deposit)이 중단됨
     */
    function setTokenPriceInstability(address stable, bool isUnstable) external onlyOwner {
        if (stables[stable] == 0) revert NotListedToken(stable); // 등록된 토큰인지 확인
        
        depositPausedFor[stable] = isUnstable;
        emit DepositForTokenPauseSet(stable, isUnstable);
    }
    
    /**
     * @notice 가격 피드 컨트랙트 주소 설정
     */
    function setPriceFeed(address _newPriceFeed) external onlyOwner {
        if (_newPriceFeed == address(0)) revert AddressZero();
        priceFeed = IPriceFeed(_newPriceFeed);
        emit PriceFeedSet(_newPriceFeed);
    }

    // ... deposit, mint, withdraw 등 다른 모든 함수는 그대로 유지 ...
}
```

***

### 위협 3: 개별 프로토콜 붕괴 시 연쇄 반응으로 인한 체인 역플라이휠 발생

인프라레드가 베라체인의 핵심 보상 분배 및 스테이킹 메커니즘을 상당 부분 담당하고 있으므로 만약 인프라레드 프로토콜이 붕괴된다면 스테이킹 보상 지급이 중단되거나 오류가 발생하고 검증인 및 위임자들의 신뢰가 급격히 하락할 것이다.

이는 결국 베라체인 네트워크 보안 약화로 이어질 수 있으며 다른 연계된 dApp들의 정상적인 작동을 방해하여 생태계 전반의 역플라이휠이 발생할 수 있다.

Infrared 프로토콜은 베라체인의 PoL 경제에서 사실상 보상 엔진 역할을 한다. 먼저 BGT와 BERA를 스테이킹한 뒤 iBGT·iBERA라는 1:1 액면가의 LST 토큰을 발행해 주고, Vault 내부에서는 자동 복리-스테이킹을 계속 돌려서 새로 나온 BGT 블록 보상과 거래 수수료를 실시간으로 적립·분배한다. 이 덕분에 이용자는 유동성을 잠그지 않고도 스테이킹 이자를 받을 수 있고, 다른 dApp에 iBGT 또는 iBERA를 담보나 LP 자산으로 자유롭게 넣을 수 있다. 실제로 Infrared의 TVL은 10억 달러 이상으로 베라체인 전체에서 1위이며, DeFiLlama 기준으로 전체 체인 TVL의 40 % 내외를 차지한다.

#### 공격 시나리오

1. **LST 즉시 디페그 → 가격 폭락**\
   해킹이든 컨트랙트 일시 중단이든 Infrared가 출금을 막으면, iBGT·iBERA는 더 이상 BGT 또는 BERA를 언제든 1:1로 바꿀 수 있는 토큰이 아니게 된다. 시장은 즉시 이를 가격에 반영해 iBGT, iBERA 프리미엄이 하락한다. 이런 급격한 하락은 Kodiak WETH:iBGT, WBERA:iBGT, BEX USDC:iBERA 같은 LST-기반 LP 풀을 불균형 상태로 만들고, 유동성 공급자들은 손실을 피하려고 LP 토큰을 회수하면서 풀의 유동성이 줄어든다.
2. **담보 가치 폭락 → Beraborrow 연쇄 청산**\
   Beraborrow의 DenManager는 iBGT·iBERA 가격을 Infrared 전용 TWAP 오라클로 가져온다. 시세가 30 %만 떨어져도 다수의 Den 포지션이 최소 담보 비율(MCR)을 밑돌아 자동 청산되기 시작한다다. 청산 과정에서 대량으로 쏟아져 나온 NECT가 시장에 매도되면, 네이티브 스테이블코인 페그에도 하방 압력이 가중된다.
3. **LSP 고갈 → 4626 인플레이션 취약점 노출**\
   Den 대량 청산으로 넘어온 NECT는 우선 LSP로 유입되는데, 이 잔액이 빠르게 소진되면 LSP의 totalSupply가 0 근처까지 줄어듭니다. LSP는 `totalSupply == 0` 가드와 virtual accounting이 없어 1 wei 예치 뒤 도네이션으로 지분 100 %를 차지하는 ERC-4626 인플레이션 공격이 가능해진다. 공격자가 LSP를 털어 가면 NECT 페그 회복에 쓰여야 할 유동성이 완전히 증발한다.
4. **검증자·위임자 신뢰 붕괴 → 네트워크 보안 약화**\
   Infrared는 자체적으로 검증자 노드를 운영하면서 스테이킹된 BGT를 다시 네트워크에 위임해 둔다. TVL 기준으로 전체 스테이킹 지분의 10 억 달러 이상이 Infrared Vault에 묶여 있으므로, Vault가 중단되면 해당 지분이 불능 상태가 된다. 결과적으로 유효 스테이크가 급감하고 검증자 세트 중 일부가 블록 제안에서 제외되면서 블록 인터벌이 늘어난다.
5. **PoL 인센티브 중단 → 생태계 역플라이휠**\
   Infrared가 보상 분배를 멈추면 BeraChef·RFRV Vault로부터 나오는 PoL 보상도 같이 멈춘다. 유동성 공급자는 돈이 안 되는 풀을 떠나고, TVL이 줄어든 dApp들은 다시 인센티브를 삭감하며 악순환이 시작된다.&#x20;

#### 영향도

`Informational`

대형 외부 프로토콜의 붕괴와 같은 이벤트는 체인 전반의 시스템 리스크로 작용할 수 있으며, 이는 본 프로토콜에도 간접적인 영향을 미칠 수 있다. 하지만 이는 본 프로토콜 자체의 직접적인 보안 취약점이라기보다는 외부 변화에 대응하기 위한 정책 및 방어 체계의 문제에 가까워 영향도를 `Informational` 로 평가한다.

#### 가이드라인

> * **모든 연계 프로토콜의 핵심 지표를 실시간 통합 모니터링**
> * **위협 발생 시 사람의 개입 없이 자동으로 방어 메커니즘 실행. 서킷 브레이커로 자동으로 시스템 일시 정지**
>   * 오라클 최신 가격이 1시간 이상 업데이트 되지 않을 시 정지
>   * &#x20;TVL이 20% 이상 급락시 정지&#x20;
>     * 심각하지만 아직은 회복 가능할 수 있는 경험적인 임계치로 20%설정
>   * 자동화 봇이 `checkAndTriggerPause` 함수를 주기적으로 호출하여 24시간 감시 체계를 구축, 조건 충족 시 즉시 시스템 정지
> * **프로토콜 간 상호 의존도 매핑 및 위험 전파 경로 사전 분석**

#### Best Practice

`커스텀 코드`

{% code overflow="wrap" %}
```solidity
constructor(
    address _multiSigAdmin,
    address _automationAgent,
    address _priceOracleAddress
) {
    // Multi-Sig에게 관리자 역할을 부여 (수동 제어)
    _grantRole(MULTI_SIG_ADMIN_ROLE, _multiSigAdmin);
    // 자동화 에이전트에게 자동화 역할을 부여
    _grantRole(AUTOMATION_ROLE, _automationAgent);

    priceOracle = AggregatorV3Interface(_priceOracleAddress);
    tvlDropThresholdPercentage = 20; // 기본값: TVL 20% 하락 시 위기
    currentSystemStatus = SystemStatus.Normal;
}

/**
 * @notice 자동화 에이전트가 주기적으로 호출하여 위기 상황을 감지하고 시스템을 중지시키는 함수
 * @dev 실제 구현에서는 여러 지표(TVL, 가격 변동성 등)를 복합적으로 판단해야 함
 */
function checkAndTriggerPause() external onlyRole(AUTOMATION_ROLE) {
    require(currentSystemStatus != SystemStatus.Paused, "System already paused");

    (bool isCrisis, string memory reason) = isCrisisCondition();

    if (isCrisis) {
        _pauseSystem(reason);
    }
}

/**
 * @notice Multi-Sig 관리자가 시스템을 수동으로 중지시키는 함수
 * @param _reason 수동으로 시스템을 중지시키는 사유
 */
function manualPause(string calldata _reason) external onlyRole(MULTI_SIG_ADMIN_ROLE) {
    require(currentSystemStatus != SystemStatus.Paused, "System already paused");
    _pauseSystem(_reason);
}

/**
 * @notice Multi-Sig 관리자가 시스템을 재개하는 함수
 */
function resumeSystem() external onlyRole(MULTI_SIG_ADMIN_ROLE) {
    require(currentSystemStatus == SystemStatus.Paused, "System is not paused");
    currentSystemStatus = SystemStatus.Normal;
    emit SystemResumed(msg.sender);
}


function _pauseSystem(string memory _reason) internal {
    currentSystemStatus = SystemStatus.Paused;
    emit SystemPaused(msg.sender, _reason);
}

/**
 * @dev 위기 상황을 판단하는 내부 로직. 다양한 조건을 여기에 추가할 수 있음
 * @return isCrisis 시스템을 중지해야 할 위기 상황인지 여부
 * @return reason 위기 상황으로 판단한 이유
 */
function isCrisisCondition() public view returns (bool, string memory) {
    // 조건 1: 오라클 가격 데이터가 오래되었거나 유효하지 않은 경우 (가장 기본적인 체크)
    (
        int price,
        uint updatedAt,
    ) = priceOracle.latestRoundData();

    // 오라클이 1시간 이상 업데이트되지 않았을 경우
    if (block.timestamp - updatedAt > 1 hours) {
        return (true, "Price oracle is stale");
    }
    // 오라클 가격이 0 이하일 경우
    if (price <= 0) {
        return (true, "Invalid price from oracle");
    }

    // 조건 2: TVL 급락 (개념적인 예시)
     uint256 currentTvl = IYourProtocol(monitoredProtocolAddress).totalValueLocked();
     if (currentTvl < lastMonitoredTvl * (100 - tvlDropThresholdPercentage) / 100) {
         return (true, "Significant TVL drop detected.");
     }

    // 모든 조건 통과 시 정상 상태 반환
    return (false, "");
}
```
{% endcode %}
