---
description: 📚 Reference Footnote List
---

# References

#### 1. history\_buf\_length

EIP-4788 standard's 8191 slot circular buffer, Berachain uses 2-second intervals instead of 12 seconds for faster proof processing

#### 2. Minimum 4.55 hours (8191 \* 2 seconds)

Minimum waiting time to prevent buffer overwriting, 8 times faster processing cycle than Ethereum standard

#### 3. SSZ.verifyProof

Simple Serialize based Merkle proof verification, transaction automatically fails if an incorrect proposer index is submitted

#### 4. BeaconDeposit Contract Operator Change Process (Queue/Timelock)

24-hour delayed execution to prevent governance attacks, securing time for community intervention in case of malicious changes

#### 5. Voluntary Withdrawal Not Supported

Currently unimplemented, increasing validator dependency; a queue system and 2-day timelock are planned for future introduction

#### 6. ValidatorSetCap, Forced Ejection Mechanism

Automatic ejection when validator count reaches the upper limit due to network stability priority policy, providing a fund recovery path for existing validators

#### &#x20;Operator Role - Regarding Reward Distribution, Commission Setting

Phased authority grant for new operator reliability verification, automatic penalty for sudden fee increases (>20%)

#### RewardVault Contract getReward()

Core reward claim function with onlyOperatorOrUser access control and updateReward modifier to ensure state synchronization

#### OZ ReentrancyGuard spec

OpenZeppelin standard re-entrancy prevention library, nonReentrant modifier blocks re-entrant calls during function execution

#### OZ access control

OpenZeppelin role-based access control system, checks and balances through separation of Factory Owner (add) and Vault Manager (remove) permissions

#### Berachain Rewardvault, whitelist

Prevents spam token registration by limiting incentive tokens to a maximum of 3 and verifying minIncentiveRate > 0

#### OZ Initializable.sol - Upgrade Initialization Standard

ERC-20 token standard compliance verification and use of SafeERC20 library for automatic rollback on transfer failure

#### Precision Vulnerability Case

Cumulative micro-loss issue due to division truncation, recommends using fixed-point math libraries like FixedPointMathLib

#### Error Margin 0.01% (Financial System Standard)

TradFi standard allowable error as Berachain reward calculation verification standard, ensuring a minimum value of 1 wei for user protection

#### Maximum Incentive Reward Claim Wait Time

Standardized MAX\_REWARD\_CLAIM\_DELAY of 3 hours in BGTIncentiveDistributor to protect users from sudden token removal

#### Berachain Incentive Management Process - Governance Proposal (Direct Token Removal Not Supported)

Checks and balances by separating FactoryVaultManager (remove) and FactoryOwner (add) permissions, policy prevents removal if balance exists

#### 30-day Cooldown Standard

Reward allocation delay policy via rewardAllocationBlockDelay, preventing concentration on specific vaults through consecutive transactions

#### Weight Structure Reward Vault Address Management

Composed of receiver and percentageNumerator, forces reward distribution with maxWeightPerVault limit of 3000 (30%)

#### Whitelist Governance Proposal Management

Blocks duplicate allocations with isWhitelistedVault verification and \_checkForDuplicateReceivers, forces total of 100%

#### Dynamic Reward Calculation Parameters

Prevents excessive inflation through collusion by real-time monitoring and parameter adjustment of BGT inflation

#### minimumIncentiveThreshold State Variable Spec

Mechanism to block reward allocation to depleted vaults by setting a minimum incentive token holding threshold

#### **De-pegging Thresholds (0.1%, 0.2%, 0.5%) Rationale**

0.1% = Minimum arbitrage profit margin vs. gas fees, 0.2% = Honey system DEFAULT\_PEG\_OFFSET value, 0.5% = Chainlink oracle deviation tolerance upper limit

#### **Market Volatility Data**

1 minute duration = 2 consecutive block confirmations to prevent single block manipulation, 1 hour = 180 block stability verification for price recovery reliability

#### isPegged Implementation

Pegging state verification logic that aggregates multiple oracles and references only active ones for reliable price judgment

#### Oracles Used by Berachain (Chainlink, etc.)

Mandatory reference to 3+ oracles and automatic exclusion of disabled/emergency-stopped oracles to enhance manipulation resistance

#### calculateLoss Formula Reference

Calculates loss as De-pegging Ratio × Asset Value, requires user risk notification and acknowledgeRisk confirmation

```solidity
// Basic Loss Calculation:
Loss = AssetValueAtPeg × DepegRatio
// User Asset Amount to Receive:
UserAssetAmount = HoneyAmount × AssetWeight
// De-pegging Ratio:
DepegRatio = (PegPrice - CurrentPrice) / PegPrice
// Asset Value at Peg:
AssetValueAtPeg = UserAssetAmount × PegPrice
// Final Loss:
Loss = AssetValueAtPeg × DepegRatio
```

#### Quadratic Voting

Reduces influence of large holders by calculating voting power based on the square root of BGT holdings, 15% concentration warning system

#### Berachain Timelock (2 days), Guardian Intervention (5-of-9 multisig)

2-day delay and Guardian intervention to prevent governance proposal abuse, safety mechanism to block malicious proposals

#### Average DeFi Feedback Time (2-3 weeks)

Based on Uniswap RFC minimum of 7 days, with the entire process taking 14 days. Compound proposal intervals average 6.95 days. A multi-layered verification process including technical review, economic impact analysis, and security audit, requiring at least 2-3 weeks for complex protocol changes, is necessary to ensure sufficient review time at each stage from community discussion to voting and execution.

#### Independent Arbitration Committee Protocol Case

Ensures transparency in governance rejections and an appeal mechanism, limits foundation holdings to 30% through interest disclosure

#### Regarding Full Governance Implementation

Prevents sybil attacks with 5-minute forum vote snapshots and a 100 BGT minimum holding until on-chain migration

#### Average DeFi Notice Period (14 days)

Minimum 14-day notice period from governance proposal approval to actual implementation, extendable up to 30 days for changes affecting assets

**Liquity Stress Test Case (2021.05.19)**

* Over 300 Troves were liquidated during a 47% ETH price drop ($3,400 → $1,800)
* The Stability Pool fully absorbed 93.5M LUSD of debt, maintaining system solvency
* Demonstrated prevention of cascading liquidations by quickly entering and recovering from Recovery Mode

#### ERC-4626 Inflation Attack Prevention

Bootstrap protection by applying Virtual Shares and a 9-digit decimal offset, forcing a minimum of 69 shares

#### Recovery Mode Transition Stability Guarantee

Real-time TCR verification with checkRecoveryMode() and simultaneous ICR/TCR checks, bulk update of all positions upon mode transition to prevent state inconsistencies

#### Recovery Mode Status Judgment and Transition Mechanism

Automatic entry when TCR < CCR, prevents bad loans by blocking collateral withdrawal and performing simultaneous ICR/TCR verification

#### Wonderland DAO Governance Vulnerability Case

Founder's undisclosed history of rug pulls damaged governance credibility, proving the need for owner background checks and transparency

#### Preventing Owner Privilege Abuse

Limits changes to critical parameters with multisig + timelock, restricts MCR/CCR/interest rate change margins with a 7-day delay

#### Preventing Mass Liquidation Vicious Cycle

Mitigates chain reactions with time-based liquidation limits and additional Recovery Mode restrictions, automatically raises MCR during increased volatility

#### Preventing Token Price Manipulation and Flash Loan Attacks

Strengthens manipulation resistance with hard caps on price volatility, a 1% additional fee on flash loans, transaction rejection for oracle deviations over 1.5%, and TWAP

#### Synthetix Oracle Discrepancy Tolerance Standard

[Synthetix 1% oracle discrepancy tolerance limit (SIP-32)](https://sips.synthetix.io/sips/sip-32/), temporarily halts trading if not updated for more than 3 minutes to prevent liquidity provider losses

#### LP Token Value Calculation Accuracy

18-decimal fixed-point precision and real-time oracle price reflection, 0.1% deviation threshold verification between LP token and pool asset value

#### Preventing Liquidity Removal Timing Attacks

Blocks MEV attacks with minimum liquidity threshold verification, TWAP price fixing, and minimum LP token holding period

#### Balancer Invariant Ratio Limit

Prevents drastic liquidity pool fluctuations by limiting increases to a maximum of 300% and decreases to a minimum of 70%

#### TWAP Calculation N-Block Average

Settlement based on an N-block average price to prevent temporary price manipulation, considering block number differences between protocols\
(Based on Uniswap V3, the N value is dynamically set according to time, typically specified between [30 minutes to 1 hour](https://github.com/Uniswap/v3-core/blob/d8b1c635c275d2a9450bd6a78f3fa2484fef73eb/contracts/UniswapV3Pool.sol#L246))

#### Curve LP Oracle Manipulation Prevention Case

LP token price manipulation vulnerability and countermeasures, independent oracle verification is essential

#### Curve Stableswap Formula Reference

x\*y=k curve and automatic rebalancing mechanism, algorithm for maintaining stable swap prices

#### Preventing Liquidity Pool Imbalance

Target ratio deviation threshold and automatic rebalancing, maintains balance with automatic swaps for single-token deposits

#### Slippage Tolerance Setting and Verification

Ensures transaction safety with user-defined slippage limits, real-time price monitoring, and prevention of minimum output calculation errors

#### Mass Trade Splitting

1inch-style execution splitting across multiple pools, minimizes MEV attacks and slippage with minimum block intervals between each split trade

#### Automated Fee Management

Prevents unpredictable mass withdrawals with automatic collection upon reaching a threshold and periodic distribution cycles ([Example of automated fee management based on Uniswap V2](https://github.com/Uniswap/v2-core/blob/ee547b17853e71ed4e0101ccfd52e70d5acded58/contracts/UniswapV2Pair.sol#L180-L181))

#### Applying Timelock to Fee Changes

Delays execution of sensitive admin functions and applies phased fees, similar to [Uniswap V2's 2-day timelock](https://docs.uniswap.org/concepts/governance/process#phase-3-governance-proposal)

#### Protecting Fee Change Governance

Ensures transparent distribution mechanism with permission verification, upper limits, and batch fee processing

#### Guaranteeing Atomic Transactions for Pool State Updates

All state changes are processed within a single transaction, and a Re-entrancy Guard like [Uniswap V2's lock mechanism](https://github.com/Uniswap/v2-core/blob/ee547b17853e71ed4e0101ccfd52e70d5acded58/contracts/UniswapV2Pair.sol#L31-L36) must be applied to prevent re-entry during state changes

#### Balancer WeightedMath Invariant Verification

Weight-based X\*Y=K invariant calculation and total supply conservation verification, ensures price consistency between pools

#### Initial Liquidity Deposit Protection

Lido-style minimum stake deposit to prevent zero total supply, [blocking exchange rate distortion through micro-deposits](https://github.com/lidofinance/core/blob/005b0876d6594b7f7864e0577cdaa44eff115b73/contracts/0.4.24/Lido.sol#L930-L936)

#### Real-time Asset Synchronization

Uniswap V3-style block-by-block updates and pre-reflection of compound() to settle outstanding earnings before processing trades

#### Preventing Fee Change Timing Exploitation

[Blocks simultaneous fee changes and reward harvesting](https://github.com/Uniswap/v3-core/blob/d8b1c635c275d2a9450bd6a78f3fa2484fef73eb/contracts/UniswapV3Factory.sol#L61-L72) by pre-reflecting outstanding rewards during updateFee() execution and restricting KEEPER\_ROLE permissions

#### Bribe System Token Verification

Prevents system contamination through whitelist operation, setting a minimum Bribe amount limit, and applying the principle of least privilege and timelocks to the BribeCollector\
(Example of applying a [4% Bribe rate](https://github.com/oo-00/Votium/blob/3993b7cb0d98cfc7a97d7a7ad8828ab6ce363ad1/contracts/Votium.sol#L25) from Votium, a Curve Finance-derived LSD platform)

#### Validator Staking Limit Restriction

Mitigates centralization by limiting individual validator's maximum stake with MAX\_EFFECTIVE\_BALANCE, preventing fund concentration and ensuring reward distribution

#### Automated Delegated Fund Distribution

Enhances decentralization by automatically distributing restaking and new delegations across multiple validators, preventing centralization and ensuring participation incentives ([Lido example](https://docs.terra.lido.fi/introduction/stake-distribution/))
