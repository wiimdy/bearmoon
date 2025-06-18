---
description: >-
  Complex DeFi strategies that combine the functions of multiple dApps in a
  chain offer high-yield opportunities. However, this dApp chaining can create
  new interaction risks that were not apparent when
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

# dApp Security Guidelines: Chaining

<table><thead><tr><th width="595">Threat</th><th align="center">Impact</th></tr></thead><tbody><tr><td><a data-mention href="chain.md#id-1-dex-erc-4626">#id-1-dex-erc-4626</a></td><td align="center"><code>Medium</code></td></tr><tr><td><a data-mention href="chain.md#id-2-honey-permissionlesspsm-sol">#id-2-honey-permissionlesspsm-sol</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="chain.md#id-3">#id-3</a></td><td align="center"><code>Informational</code></td></tr><tr><td><a data-mention href="chain.md#id-4-dex">#id-4-dex</a></td><td align="center"><code>Informational</code></td></tr></tbody></table>

### Threat 1: ERC-4626 Inflation Attack due to DEX Pool Imbalance and Cascading Liquidations <a href="#id-1-dex-erc-4626" id="id-1-dex-erc-4626"></a>

BeraBorrow is tightly integrated with Berachain's PoL mechanism and uses Infrared's iBGT, iBERA tokens, and DEX LP tokens from Kodiak, BEX, etc., as collateral. This complex interdependence can lead to severe systemic risks when combined with the ERC-4626 inflation attack vulnerability in the LSP.

**Attack Scenario**

1. The attacker causes an imbalance in a liquidity pool (e.g., kodiak's HONEY-BERA) that issues LP tokens used as collateral in Beraborrow, through large trades on a Berachain DEX.
2. The drop in LP token value causes the collateral ratio (ICR) to fall below the minimum collateral ratio (MCR), triggering mass liquidations. The scale of liquidations exceeds the NECT balance of the LSP, causing a mass withdrawal rush from LSP depositors.
3. The cascading liquidations and withdrawal rush cause the totalSupply of the LiquidStabilityPool (LSP) to approach near zero. Unlike the BaseCollateralVault, the Beraborrow LSP does not implement a virtual accounting mechanism and lacks a `totalSupply=0` safeguard in its deposit/mint functions.
4. The attacker deposits 1 wei of NECT to acquire 100% of the shares, then transfers a large amount of NECT tokens directly to the LSP contract. The `_requireValidRecipient` function of the DebtToken does not block the LSP address, and the LSP's `totalAssets()` function does not include the donated NECT in its asset calculation.
5. When a subsequent depositor deposits NECT, they receive 0 shares due to Solidity rounding in the ERC-4626 `convertToShares` calculation, and the attacker withdraws the entire balance to realize a profit.

**Systemic Risk**

* This chain attack exploits the interdependence between Berachain's PoL mechanism and the Beraborrow multi-collateral lending system, escalating a single vulnerability into a system-wide risk. Since Infrared's iBGT and iBERA tokens are used as major collateral, a DEX pool imbalance can cause a domino effect across the Infrared staking platform, the Beraborrow lending system, and the LSP. Therefore, the ERC-4626 inflation attack vulnerability in the LSP should be assessed not just as a smart contract bug but as a systemic risk to the entire Berachain ecosystem.

#### Impact

`Medium`

This attack is only feasible under the special condition where the LiquidStabilityPool's (LSP) total supply approaches zero. However, if successful, it can directly drain funds from LSP depositors, thus it is rated as **`Medium`**. The impact assessment is based on the following:

1. **Limited Attack Surface:** The attack scenario originates from a **specific DEX's LP token**, not all assets allowed as collateral in BeraBorrow. The attacker must target a pool with relatively low liquidity among the LP tokens used as collateral by BeraBorrow to facilitate price manipulation, making the preconditions for the attack limited. Furthermore, the inflation attack itself is confined to **specific vaults within BeraBorrow, like the LiquidStabilityPool, that lack virtual accounting defense logic**, not all vaults.
2. **Conditional Attack Feasibility (LSP Depletion):** The core of the attack is for the LSP's totalSupply to converge to almost zero. This is not a normal protocol state and can only occur under **extreme market stress conditions** like large-scale cascading liquidations and a mass exodus of depositors. Therefore, the attacker requires substantial capital to move the market in the desired direction, and the attack timing is very limited.
3. **Vulnerability Pattern Reference:** The method of monopolizing shares with a 1 wei deposit when the LSP's totalSupply is near zero, and then inflating the value of the shares through asset donation to steal subsequent depositors' funds, is a well-known **ERC-4626 inflation attack** vector. Numerous security audit reports, including from OpenZeppelin, warn of the risks of such attacks and recommend applying defense mechanisms. The theoretical applicability of this attack to BeraBorrow's LSP is a risk that cannot be ignored.

#### Guideline

> * **Create a warning system for the Lending protocol that uses LP tokens as collateral when an imbalance occurs in the Dex pool.**
> * **Implement a Virtual Accounting system.**
> * **Introduce the same virtual accounting mechanism to the LiquidStabilityPool (LSP) contract as in the BaseCollateralVault to block donation attacks by separating internal balance tracking from the actual token balance.**
> * **Set a minimum deposit threshold.**
>   * Add a minimum deposit requirement to the LSP deposit/mint function.
>   * Increase the attack cost by setting a higher minimum amount for the initial deposit.
> * **Strengthen protection for the totalSupply=0 state.**
>   * Extend the ZeroTotalSupply check to all deposit functions, expanding the protection that currently exists only in the `linearVestingExtraAssets` function to the entire system.
> * **Bootstrap period protection mechanism.**
>   * Apply deposit limits and additional verification procedures during the initial 24-48 hours.
>   * Block large deposits without admin approval during the bootstrap period.
> * **Real-time liquidation monitoring between LSP-DenManager.**
>   * Activate a temporary withdrawal limit and warning system for the LSP when mass liquidations occur, to preemptively detect LSP depletion situations due to cascading liquidations.
> * **Detect abnormal deposit/withdrawal patterns.**
>   * Monitor for patterns of depositing a tiny amount and then transferring a large amount of assets in a single transaction.
>   * Real-time detection of complex attack scenarios linked with flash loans.
> * **Track liquidity correlation between LSP-DEX.**
>   * Real-time analysis of the impact of Berachain DEX pool imbalances on LSP stability.

#### Best Practice

`Custom Code`

{% code overflow="wrap" %}
```solidity
// Function to check the health of an LP token
function updateLpTokenRisk(address _lpToken, bool _isHighRisk) external onlyOwner {
// For actual implementation, onlyOwner should be changed to Multi-Sig, Timelock, etc. to distribute authority.
    require(_lpToken != address(0), "LP token: zero address");
    if (lpTokenIsHighRisk[_lpToken] != _isHighRisk) {
        lpTokenIsHighRisk[_lpToken] = _isHighRisk;
        emit LpTokenRiskStatusUpdated(_lpToken, _isHighRisk);
        // This event can be detected by an off-chain warning system to notify users.
    }
}
```
{% endcode %}

{% code overflow="wrap" %}
```solidity
// 1. Add virtual accounting
mapping(address => uint) internal virtualAssetBalance;

function totalAssets() public view override returns (uint) {
    return virtualAssetBalance[asset()];
}

// 2. Add protection logic to the deposit function
function _depositAndMint(/*...*/) private {
    if (totalSupply() == 0) {
        require(assets >= 1000e18, "LSP: Minimum initial deposit");
    }

    _provideFromAccount(msg.sender, assets);
    virtualAssetBalance[asset()] += assets; // Track virtual balance

    // ... existing logic
}
```
{% endcode %}

***

### Threat 2: Protocol Asset Drain via HONEY De-pegging and PermissionlessPSM.sol <a href="#id-2-honey-permissionlesspsm-sol" id="id-2-honey-permissionlesspsm-sol"></a>

If Beraborrow's `PermissionlessPSM.sol` mints NECT at a 1:1 ratio even when HONEY's market price has plummeted, an attacker can acquire a large amount of NECT with cheap HONEY. This NECT is then used to repay collateral at a fixed value in the lending protocol, draining the protocol's assets.

**Core Vulnerability**

NECT's price determination mechanism: Within the `_whitelistStable` function, the exchange rate offset between HONEY and NECT is set as `wadOffset = (10 ** (nect.decimals() - stable.decimals())`. This only serves to correct the difference in decimal places between the two tokens and is not linked to an oracle that reflects HONEY's actual market price. Therefore, even if HONEY's external market price plummets, Beraborrow's PermissionlessPSM.sol will still mint NECT at a fixed 1:1 offset.

Direct on-chain data analysis of the [PermissionlessPSM](https://berascan.com/address/0xb2f796fa30a8512c1d27a1853a9a1a8056b5cc25#readContract) contract and the [HONEY](https://berascan.com/address/0xFCBD14DC51f0A4d49d5E53C2E0950e0bC26d0Dce) token address confirms that the minting cap for NECT using HONEY (**mintCap**) is set to **15,000,000 NECT**.

This means the protocol is **directly exposed to a potential risk of up to $15 million**. This vulnerability is not just a theoretical possibility but a clear and very serious threat that could lead to an actual asset drain up to the limit specified in the contract.

**Simulation: Loss Scale Analysis Based on Current mintCap (15M)**

* **Scenario Assumption**: HONEY's market value plummets to **$0.50** due to external factors.
* **Attack Execution**
  * The attacker spends **$7,500,000** on the external market to acquire the full mintCap limit of 15,000,000 HONEY.
  * The attacker calls the `deposit` function of PermissionlessPSM.sol, deposits 15,000,000 HONEY, and exploits the system's lack of a price oracle to mint approximately **15,000,000 NECT** (around 14,955,000 after fees).
* **Protocol Loss Scale**
  * The protocol's treasury receives assets (HONEY) with an actual value of **$7,500,000**.
  * The protocol's debt increases by **$15,000,000**, as NECT is treated as $1 within the system.
  * Consequently, if this attack succeeds, the protocol will **immediately lose approximately $7,500,000 in assets**.

#### Impact

`Low`

During a de-pegging event, an attacker can mint NECT with low-priced HONEY to realize a profit, exposing the protocol to asset loss risk. The impact could be adjusted from `Low` to `Medium` depending on the extent of the HONEY de-pegging and the size of the protocol's assets. The possibility of HONEY's value recovering through arbitrage may be limited.

#### Guideline

> * **Integrate a reliable price oracle.**
>   * The deposit and mint function logic must be modified to query the HONEY/USD price from an external price oracle when calculating the amount of NECT to be issued.
>   * A multi-oracle system should be introduced to counter price data manipulation or temporary outages.
> * **Introduce dynamic fees and issuance limit mechanisms.**
>   * Add logic to dynamically increase the fee for deposits if the oracle price drops sharply in a short period. This will have the effect of reducing the incentive for arbitrage attacks in minor de-pegging situations.
> * **Strengthen governance and emergency response protocols.**
>   * A function like `pauseDeposit` should be implemented in permissionlessPSM.sol, allowing a multi-sig entity to immediately halt new NECT issuance using HONEY.

#### Best Practice

`Custom Code`

{% code overflow="wrap" %}
```solidity
// Contract to apply Best Practice: PermissionlessPSM.sol

// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// --- Existing import statements ---
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {FeeLib} from "src/libraries/FeeLib.sol";
import {IMetaBeraborrowCore} from "src/interfaces/core/IMetaBeraborrowCore.sol";
import {IDebtToken} from "src/interfaces/core/IDebtToken.sol";
import {IFeeHook} from "src/interfaces/utils/integrations/IFeeHook.sol";
// --- New import ---
import {IPriceFeed} from "src/interfaces/IPriceFeed.sol"; // Beraborrow's price feed interface

/**
 * @title PermissionlessPSM
 * @author Beraborrow Team
 * @notice PSM integrated with a price oracle and with added functionality to pause deposits per stablecoin
 */
contract PermissionlessPSM {
    // --- Existing state variables ---
    using Math for uint;
    using SafeERC20 for IERC20;
    using FeeLib for uint;

    uint16 public constant DEFAULT_FEE = 30; // 0.3%
    uint16 constant BP = 1e4;

    IMetaBeraborrowCore public metaBeraborrowCore;
    IDebtToken public nect;
    IFeeHook public feeHook;
    address public feeReceiver;
    bool public paused; // Pauses the entire contract
    mapping(address stable => uint) public nectMinted;
    mapping(address stable => uint) public mintCap;
    mapping(address => uint64 wadOffset) public stables;

    // --- New/Modified state variables ---
    IPriceFeed public priceFeed;
    // Manages the deposit enabled/disabled state for specific stablecoins
    mapping(address stable => bool) public depositPausedFor;

    // --- Existing errors and events ---
    error OnlyOwner(address caller);
    error AddressZero();
    error AmountZero();
    error Paused();
    error NotListedToken(address token);
    error AlreadyListed(address token);
    error PassedMintCap(uint mintCap, uint minted);
    error SurpassedFeePercentage(uint feePercentage, uint maxFeePercentage);
    error DepositForTokenPaused(address stable); // New error

    // ... (existing events) ...
    event DepositForTokenPauseSet(address indexed stable, bool isPaused); // New event
    event PriceFeedSet(address newPriceFeed); // New event


    // --- Core modified function: previewDeposit ---
    function previewDeposit(address stable, uint stableAmount, uint16 maxFeePercentage) public view returns (uint mintedNect, uint nectFee) {
        // Defense logic
        if (depositPausedFor[stable]) revert DepositForTokenPaused(stable);

        uint64 wadOffset = stables[stable];
        if (wadOffset == 0) revert NotListedToken(stable);

        // --- Price oracle integration logic ---
        uint stablePrice = priceFeed.fetchPrice(stable); // 1. Fetch stable/USD price from oracle
        require(stablePrice > 0, "Invalid price from oracle");

        // 2. Calculate the actual USD value of the deposited stable token (considering token decimals)
        uint stableValueInUSD = (stableAmount * stablePrice) / (10 ** IERC20Metadata(stable).decimals());

        // 3. Since NECT has a value of $1, the calculated USD value is the amount of NECT to be minted
        uint grossMintedNect = stableValueInUSD;
        // --- ---

        uint fee = feeHook.calcFee(msg.sender, stable, grossMintedNect, IFeeHook.Action.DEPOSIT);
        fee = fee == 0 ? DEFAULT_FEE : fee;
        if (fee > maxFeePercentage) revert SurpassedFeePercentage(fee, maxFeePercentage);

        nectFee = grossMintedNect.feeOnRaw(fee);
        mintedNect = grossMintedNect - nectFee;
    }

    // --- New/Modified functions for governance ---

    /**
     * @notice (Implementation of existing idea) Pause/resume deposits by setting the price instability of a specific stablecoin
     * @dev onlyOwner: Can only be called by governance or a trusted entity
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
{% endcode %}

***

### Threat 3: Chain Reaction from Individual Protocol Collapse Leading to a Chain Reverse Flywheel <a href="#id-3" id="id-3"></a>

Since Infrared is responsible for a significant portion of Berachain's core reward distribution and staking mechanisms, a collapse of the Infrared protocol would halt or cause errors in staking reward payments, leading to a sharp decline in the trust of validators and delegators.

This could ultimately weaken Berachain's network security and disrupt the normal operation of other interconnected dApps, potentially triggering a reverse flywheel across the entire ecosystem.

The Infrared protocol essentially acts as the reward engine in Berachain's PoL economy. After staking BGT and BERA, it issues 1:1 face value LST tokens called iBGT and iBERA. Internally, the Vault continuously runs auto-compounding and staking to accumulate and distribute new BGT block rewards and transaction fees in real-time. This allows users to earn staking interest without locking up their liquidity and to freely use iBGT or iBERA as collateral or LP assets in other dApps. In fact, Infrared's TVL is over $1 billion, ranking first in the entire Berachain, and accounts for around 40% of the entire chain's TVL according to DeFiLlama.

#### Attack Scenario

1. **LST Instant De-peg → Price Collapse**\
   If Infrared blocks withdrawals, whether due to a hack or a contract pause, iBGT and iBERA would no longer be tokens that can be exchanged for BGT or BERA at a 1:1 ratio at any time. The market would immediately price this in, causing the iBGT and iBERA premiums to fall. Such a sharp drop would throw LST-based LP pools like Kodiak's WETH:iBGT, WBERA:iBGT, and BEX's USDC:iBERA into imbalance. As liquidity providers withdraw their LP tokens to avoid losses, the pool's liquidity would shrink.
2. **Collateral Value Collapse → Beraborrow Cascading Liquidations**\
   Beraborrow's DenManager sources iBGT and iBERA prices from a dedicated Infrared TWAP oracle. A mere 30% drop in the market price would cause many Den positions to fall below the Minimum Collateral Ratio (MCR), triggering automatic liquidations. The large amount of NECT dumped onto the market during the liquidation process would add downward pressure on the native stablecoin's peg.
3. **LSP Depletion → Exposure of 4626 Inflation Vulnerability**\
   The NECT from the mass Den liquidations flows into the LSP. If this balance is quickly depleted, the LSP's totalSupply will drop to near zero. Since the LSP lacks `totalSupply == 0` guards and virtual accounting, it becomes vulnerable to the ERC-4626 inflation attack, where an attacker can take 100% of the shares with a 1 wei deposit followed by a donation. If an attacker drains the LSP, the liquidity meant to restore the NECT peg would completely evaporate.
4. **Validator & Delegator Trust Collapse → Weakened Network Security**\
   Infrared operates its own validator nodes and re-delegates the staked BGT to the network. Since over $1 billion of the total staked value is tied up in the Infrared Vault (based on TVL), a halt in the Vault would render that stake inactive. Consequently, the effective stake would plummet, and some validators from the set would be excluded from block proposals, increasing the block interval.
5. **PoL Incentive Halt → Ecosystem Reverse Flywheel**\
   If Infrared stops distributing rewards, the PoL rewards from BeraChef and RFRV Vaults also stop. Liquidity providers would leave unprofitable pools, and dApps with reduced TVL would in turn cut their incentives, starting a vicious cycle.

#### Impact

`Informational`

Events like the collapse of a major external protocol can act as a system-wide risk for the entire chain, which can indirectly affect this protocol. However, this is more of an issue with policies and defense mechanisms to respond to external changes rather than a direct security vulnerability of the protocol itself. Therefore, the impact is rated as `Informational`.

#### Guideline

> * **Real-time integrated monitoring of all key metrics of linked protocols.**
> * **Automatic execution of defense mechanisms without human intervention when a threat occurs. Automatically pause the system with a circuit breaker.**
>   * Pause if the latest oracle price is not updated for more than 30 minutes.
>     * The standard was set based on the shortest oracle heartbeat of 30 minutes configured in beraborrow. [https://berascan.com/tx/0xfe8efae89bc2b0491f0b06d43d8f75c312616888e8790452ef0e2d1f52e371b2](https://berascan.com/tx/0xfe8efae89bc2b0491f0b06d43d8f75c312616888e8790452ef0e2d1f52e371b2)
>   * Pause if TVL drops by more than 20%.
>     * 20% is set as an empirical threshold that is serious but potentially recoverable.
>   * An automated bot periodically calls the `checkAndTriggerPause` function to establish a 24-hour monitoring system, immediately pausing the system if conditions are met.

#### Best Practice

`Custom Code`

{% code overflow="wrap" %}
```solidity
constructor(
    address _multiSigAdmin,
    address _automationAgent,
    address _priceOracleAddress
) {
    // Grant the admin role to the Multi-Sig (manual control)
    _grantRole(MULTI_SIG_ADMIN_ROLE, _multiSigAdmin);
    // Grant the automation role to the automation agent
    _grantRole(AUTOMATION_ROLE, _automationAgent);

    priceOracle = AggregatorV3Interface(_priceOracleAddress);
    tvlDropThresholdPercentage = 20; // Default: crisis if TVL drops by 20%
    currentSystemStatus = SystemStatus.Normal;
}

/**
 * @notice Function called periodically by the automation agent to detect a crisis and pause the system
 * @dev In a real implementation, multiple metrics (TVL, price volatility, etc.) should be considered complexly
 */
function checkAndTriggerPause() external onlyRole(AUTOMATION_ROLE) {
    require(currentSystemStatus != SystemStatus.Paused, "System already paused");

    (bool isCrisis, string memory reason) = isCrisisCondition();

    if (isCrisis) {
        _pauseSystem(reason);
    }
}

/**
 * @notice Function for the Multi-Sig admin to manually pause the system
 * @param _reason The reason for manually pausing the system
 */
function manualPause(string calldata _reason) external onlyRole(MULTI_SIG_ADMIN_ROLE) {
    require(currentSystemStatus != SystemStatus.Paused, "System already paused");
    _pauseSystem(_reason);
}

/**
 * @notice Function for the Multi-Sig admin to resume the system
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
 * @dev Internal logic to determine a crisis situation. Various conditions can be added here.
 * @return isCrisis Whether it is a crisis situation that requires pausing the system
 * @return reason The reason for judging it as a crisis situation
 */
function isCrisisCondition() public view returns (bool, string memory) {
    // Condition 1: Oracle price data is stale or invalid (most basic check)
    (
        , // roundId
        int256 price,
        , // startedAt
        uint256 updatedAt,
        // answeredInRound
    ) = priceOracle.latestRoundData();

    // If the oracle has not been updated for more than 1 hour
    if (block.timestamp - updatedAt > 1 hours) {
        return (true, "Price oracle is stale");
    }
    // If the oracle price is zero or less
    if (price <= 0) {
        return (true, "Invalid price from oracle");
    }

    // Condition 2: Sharp TVL drop (conceptual example)
     uint256 currentTvl = IYourProtocol(monitoredProtocolAddress).totalValueLocked();
     if (currentTvl < lastMonitoredTvl * (100 - tvlDropThresholdPercentage) / 100) {
         return (true, "Significant TVL drop detected.");
     }

    // Return normal state if all conditions pass
    return (false, "");
}
```
{% endcode %}

***

### Threat 4: Collateral Overvaluation/Cascading Liquidation Attack via DEX Pool Imbalance <a href="#id-4-dex" id="id-4-dex"></a>

Built on Berachain's PoL structure, Beraborrow accepts iBGT/iBERA (from Infrared) and Kodiak/BEX LP tokens as collateral, tightly intertwining liquidity pools with the lending system.

An attacker can repeatedly execute large swaps in an LP with low pool TVL and high sensitivity to price impact, distorting the reserve ratio to artificially inflate or deflate the LP price.

During the price inflation phase, they can deposit the same LP as collateral to comfortably meet the Minimum Collateral Ratio (MCR) and mint a large amount of NECT. Then, by immediately reverting the price to its original state, they can collapse the collateral value and induce cascading liquidations. Conversely, if they first crash the price, the ICR of other users' LP collateral will fall below the MCR, triggering mass liquidations and Recovery Mode, which can deplete the Stability Pool's NECT balance and even halt additional borrowing and repayment functions.

#### **Attack Scenario**

1.  **Pool Pumping Phase**

    The attacker temporarily injects ≈ 50K WBERA (approx. $128K) into the iBGT/WBERA v3 pool (liquidity ≈ $6.3M) to raise the price by +10%.

    (iBGT/WBERA v3 liquidity source: [dexscreener.com](https://dexscreener.com/berachain/0x12bf773f18cec56f14e7cb91d82984ef5a3148ee))
2.  **Over-borrowing Phase**

    Using the artificially inflated LP as collateral, they deposit collateral worth $1M to borrow $833K NECT based on Beraborrow's MCR of 120%.

    (Beraborrow MCR data source: [beraborrow.gitbook.io](https://beraborrow.gitbook.io/docs/borrowing/collateral-ratio-and-liquidation))
3.  **Price Reversion & Liquidation Trigger**

    By withdrawing the attack funds, the pool price reverts to its original state (-10%), reducing the collateral value to $900K. This drops the ICR to 108%, which is below the 120% MCR, triggering immediate liquidation.
4.  **Cascading Liquidation & Recovery Mode**

    As mass liquidations consume the Stability Pool's NECT balance, the Redistribute path is triggered, shifting the debt to other Dens. The TCR falls below the CCR (=120%), and the system enters Recovery Mode.\
    (Recovery Mode entry point source: [beraborrow.gitbook.io](https://beraborrow.gitbook.io/docs/borrowing/collateral-ratio-and-liquidation))

> **1-Block Attack Cost $128K ↔︎ Potential Debt $883K (≈ 6.5x Leverage)**

#### Impact

`Informational`

The DEX pool imbalance → collateral overvaluation/undervaluation → cascading liquidation chaining attack is a systemic risk that can shake the Beraborrow, Infrared, and PoL incentive lines like a domino effect even with a single pool manipulation. While the risk is real if an attack occurs, it has been classified as `Informational` because Beraborrow, the current lending protocol on Berachain, is aware of this threat and has defended against it by not reflecting single-block oracle price feeds.

* Simultaneously pressures NECT supply and Stability Pool solvency.
* Can spread to Berachain's core liquidity as Infrared's iBGT, PoL rewards, and Kodiak's TVL are interconnected.

#### Guideline

> * **Oracle & Price Input**
>   * Automatically halt collateral deposits and borrowing if the deviation between Chainlink + RedStone (+30 min TWAP) > 1%.
>   * Trigger `priceDeviationCircuitBreaker()` if the price fluctuates by more than ±1% in a single block.
> * **Borrowing Limits**
>   * Total debt limit for an LP with TVL ≤ $10M = TVL × 30%.
>   * NECT mint amount per collateral transaction ≤ Current supply × 0.5%.
> * **Stability Pool**
>   * Maintain NECT deposits ≥ 40% of the risky LP's TVL.
>   * Issue sNECT and activate the Back-stop DAO if deficient.
> * **Real-time Monitoring**
>   * Stream DEX price deviations and Stability Pool balance to a Dune/Superset dashboard.
>   * Implement a 1-block delay & warning on LSP withdrawals when a mass liquidation transaction occurs.
>
> **Parameters & Formulas**
>
> *   **Required Capital**
>
>     ΔWBERA ≈ _W_ (√1.10 – 1) → **50K WBERA ≈ $128K**
> *   **Borrowing Limit**
>
>     Borrowable = Collateral / MCR = $1M / 1.20 = **$833K**
> *   **Liquidation Threshold**
>
>     ICR < 120% ⇒ Liquidate → SP (or Redistribute)

#### Best Practice

[`WeightedMath.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Bex/contracts/WeightedMath.sol#L37-L44)
