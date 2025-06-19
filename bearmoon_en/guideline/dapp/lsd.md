---
icon: d-and-d
---

# dApp Security Guidelines: LSD

<table><thead><tr><th width="594.08203125">Threat</th><th align="center">Impact</th></tr></thead><tbody><tr><td><a data-mention href="lsd.md#id-1-ibera-bera">#id-1-ibera-bera</a></td><td align="center"><code>Medium</code></td></tr><tr><td><a data-mention href="lsd.md#id-2">#id-2</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="lsd.md#id-3-bribe">#id-3-bribe</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="lsd.md#id-4">#id-4</a></td><td align="center"><code>Informational</code></td></tr></tbody></table>

### Threat 1: Manipulation of iBERA/BERA Exchange Rate through Mass Deposits and Withdrawals <a href="#id-1-ibera-bera" id="id-1-ibera-bera"></a>

If an attacker momentarily manipulates the iBERA/BERA exchange rate with a large transaction, they can gain unfair profits while other users suffer losses.\
This ultimately reduces the protocol's assets and undermines user trust, harming system stability.

#### Impact

`Medium`

It is rated as **`Medium`** because it can directly affect system stability by reducing protocol assets and undermining trust.

#### Guideline

> * **To prevent the settlement of unreflected profits when calculating the exchange rate, a procedure that pre-applies accumulated rewards, similar to the Lido protocol, should be implemented by** [**calling the `compound()` function before processing deposit/withdrawal transactions**](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Infrared/src/core/libraries/RewardsLib.sol#L80)**.**
> * **To prevent the exchange rate from being distorted when funds flow in directly from external contracts or when internal accounting is not** [**synchronized in real-time**](../../reference.md#id-57.-real-time-asset-synchronization)<sub>**57**</sub>**, apply a mechanism for real-time reflection in internal accounting, similar to the** [**Uniswap V2 contract code**](https://github.com/Uniswap/v2-core/blob/ee547b17853e71ed4e0101ccfd52e70d5acded58/contracts/UniswapV2Pair.sol#L185)**.**
> * **To prevent the exchange rate from being distorted by a very small deposit when there is no initial liquidity, deposit a minimum stake at the contract deployment stage to** [**prevent zero total supply and zero division issues**](../../reference.md#id-56.-initial-liquidity-deposit-protection)<sub>**56**</sub>**.**

#### Best Practice

[`InfraredBERA.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Infrared/src/staking/InfraredBERA.sol#L213-L232)

{% code overflow="wrap" %}
```solidity
function mint(address receiver) public payable returns (uint256 shares) {
    compound(); // Settle and reflect unrealized profits

    uint256 d = deposits;
    uint256 ts = totalSupply();

    uint256 amount = msg.value;
    // Synchronize external fund inflow by calling the BeaconDeposit contract via the queue function in the InfraredBERADepositor contract
    _deposit(amount);

    // Process at 1:1 during initialization, then proportionally to the deposit ratio
    shares = (d != 0 && ts != 0) ? (ts * amount) / d : amount;
    // Handle exceptions during initialization attempts
    if (shares == 0) revert Errors.InvalidShares();
    _mint(receiver, shares);

    emit Mint(receiver, amount, shares);
}
```
{% endcode %}

***

### Threat 2: Malicious Actor Profit Maximization through Mass Harvesting Before/After Fee Changes <a href="#id-2" id="id-2"></a>

If a malicious actor exploits the timing of a protocol fee change to harvest a large amount of rewards just before or after the change, they can distort the fair reward distribution system, gaining unfair profits for themselves while causing losses to other users or the protocol's treasury.\
This ultimately undermines the fairness and trustworthiness of the system.

#### Impact

`Low`

Exploiting the timing of fee changes to harvest large rewards can lead to some users gaining unfair profits and causing losses to other users or the protocol's treasury. However, the impact on the overall stability or security of the system is limited, so it is rated `Low`.

#### Guideline

> * **To settle existing rewards before a fee change, automatically distribute all unsettled rewards at the first step of the smart contract function execution by** [**running the `compound()` function before processing deposit/withdrawal transactions**](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Infrared/src/core/libraries/RewardsLib.sol#L80)**, similar to the Lido protocol, to preemptively block reward theft.**
> * **To prevent an external contract from exploiting the system by executing a fee change and reward harvesting function simultaneously, minimize permissions to restrict unauthorized execution and** [**do not allow transactions that execute both functions at the same time**](../../reference.md#id-54.-guaranteeing-atomic-transactions-for-pool-state-updates)<sub>54</sub>**.**

#### Best Practice

[`InfraredV1_2.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Infrared/src/core/upgrades/InfraredV1_2.sol#L517-L524)

```solidity
function updateFee(ConfigTypes.FeeType _t, uint256 _fee)
    external
    onlyGovernor // Restrict fee change authority
{
    // Settle for the previous fee
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
        // Limit reward harvesting to Keeper role
        address sender = msg.sender;
        if (!hasRole(KEEPER_ROLE, sender) && sender != user) {
            revert Errors.Unauthorized(sender);
        }
        // ... (omitted) ...
    }
```

***

### Threat 3: Contamination of the Bribe System through Tokens Susceptible to Malicious Behavior <a href="#id-3-bribe" id="id-3-bribe"></a>

Using tokens with the potential for malicious behavior as reward tokens in the Bribe system undermines the reliability and fairness of the Bribe system.\
This ultimately weakens the competitiveness of honest protocols and disrupts the healthy incentive flow of the ecosystem.

#### Impact

`Low`

The system's reliability and fairness are undermined, which can weaken the competitiveness of honest protocols. However, the damage is limited to incentive distortion and operational issues, so it is rated `Low`.

#### Guideline

> * **Regarding the whitelist of reward tokens used in the Bribe system,** [**include a verification process similar to the Lido protocol's case**](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Infrared/src/core/upgrades/BribeCollectorV1_2.sol#L90-L92) **to prevent system contamination and loss of trust.**
> * **To prevent an attacker from disrupting the system by attempting multiple small bribes,** [**set a minimum bribe amount limit**](../../reference.md#id-59.-bribe-system-token-verification)<sub>59</sub> **to prevent abuse.** > **\[Source:** [Blockchain Bribing Attacks and the Efficacy of Counterincentives](https://arxiv.org/pdf/2402.06352) **| page 11 \~ 12]**
> *   **Since granting excessive authority to the BribeCollector can lead to misuse, apply the principle of least privilege. For the use of this contract,** **as in the case of Uniswap,** [**apply a 2-day timelock period**](https://docs.uniswap.org/concepts/governance/process#phase-3-governance-proposal)**.**
>
>     $$\scriptsize \text{Execute Time} = \text{Request Time} + \text{2 days} \text{ (UniswapV2 Example)}$$

#### Best Practice

[`RewardLib.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Infrared/src/core/libraries/RewardsLib.sol#L569-L600)

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
        // Verify if the token is whitelisted
        if (!whitelisted[i]) continue;
        // ... (omitted) ...
    }
}
```

[`BribeCollectorV1_3.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Infrared/src/core/upgrades/BribeCollectorV1_3.sol#L56-L105)

```solidity
function claimFees(
        address _recipient,
        address[] calldata _feeTokens,
        uint256[] calldata _feeAmounts
    ) external onlyKeeper // Limit reward collection execution authority to Keeper
```

***

### Threat 4: Reward Imbalance and Centralization Due to Fund Concentration in Specific Validators <a href="#id-4" id="id-4"></a>

If funds are excessively concentrated in a few validators, they will monopolize most of the rewards, discouraging other validators from participating and making it difficult for new ones to enter.\
This ultimately leads to the concentration of decision-making power in the network in the hands of a few, undermining decentralization and harming the overall stability and fairness of the system.

#### Impact

`Informational`

Most of the rewards could be monopolized by a few validators, and the network's decision-making power could become concentrated, undermining decentralization and system fairness. However, this is considered a structural and operational issue that affects network decentralization and participation incentives rather than a direct security threat, so it is rated `Informational`.

#### Guideline

> * **To address the concentration of funds in large validators, an issue raised in major PoS chains like Ethereum and Solana, prevent reward imbalance and centralization by setting a maximum** [**staking limit**](../../reference.md#id-60.-validator-staking-limit-restriction)<sub>60</sub> **per validator.**
> * **To prevent network instability caused by a validator's long-term abnormal behavior, it is necessary to introduce a** [**real-time status tracking**](../../reference.md#id-20.-dynamic-reward-calculation-parameters)<sub>20</sub> **and automatic forced exit system.**
> * **To prevent the possibility of centralization and reward imbalance if restaking or new delegations are concentrated on a few validators, apply a delegation policy that** [**automatically distributes**](../../reference.md#id-61.-automated-delegated-fund-distribution)<sub>61</sub> **funds to multiple validators.**
> * **To prevent the weakening of network decentralization and liquidity due to low user participation, provide activity rewards similar to** [**Curve Finance's LP token rewards**](https://github.com/curvefi/curve-dao-contracts/blob/fa127b1cb7bf83e4f3d605f7244b7b4ed5ebe053/contracts/gauges/LiquidityGaugeV2.vy#L205-L254) **to promote participation and fund distribution.**

#### Best Practice

[`InfraredBERADepositor.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Infrared/src/staking/InfraredBERADepositor.sol#L76-L159)

```solidity
function execute(bytes calldata pubkey, uint256 amount)
    external
    onlyKeeper
{
    // ... (omitted) ...
    address withdrawor = IInfraredBERA(InfraredBERA).withdrawor();
    // Prioritize processing funds from force-exited validators
    if (withdrawor.balance >= InfraredBERAConstants.INITIAL_DEPOSIT) {
        revert Errors.HandleForceExitsBeforeDeposits();
    }
    // Verify that current validator balance + deposit amount <= max staking limit
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

    // ... (omitted) ...

    emit Execute(pubkey, amount);
}
```
