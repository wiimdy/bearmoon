---
icon: square-poll-vertical
---

# PoL Security Guidelines: Governance

<table><thead><tr><th width="591.765625">Threat</th><th align="center">Impact</th></tr></thead><tbody><tr><td><a data-mention href="gov.md#id-1">#id-1</a></td><td align="center"><code>High</code></td></tr><tr><td><a data-mention href="gov.md#id-2">#id-2</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="gov.md#id-3">#id-3</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="gov.md#id-4">#id-4</a></td><td align="center"><code>Informational</code></td></tr><tr><td><a data-mention href="gov.md#id-5">#id-5</a></td><td align="center"><code>Informational</code></td></tr></tbody></table>

### Threat 1: Governance Manipulation through BGT Monopoly <a href="#id-1" id="id-1"></a>

If users flock to a large-scale LSD protocol, it can accumulate a large amount of BGT. If a single protocol holds a large amount of BGT, it can manipulate votes to force policies favorable to itself.

#### Impact

`High`

A single protocol could cause manipulation, making governance meaningless. Due to its high feasibility and impact, it is rated as `High`.

#### Guideline

> * **Introduce a warning mechanism when a single entity or protocol holds more than a certain percentage (15%) of the total BGT.**
>   * The 15% threshold is set at 3/4 of the 20% required to submit a proposal.
> * **Reduce the influence of large holders by diminishing the power of BGT held above a certain ratio, instead of linear voting power.**
>   * Apply the square root-based [**Quadratic Voting**](../../reference.md#id-27.-quadratic-voting)<sub>27</sub> method to reduce the influence of large holders.

#### Best Practice

[`BerachainGovernance.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Core/src/gov/BerachainGovernance.sol#L84-L95)

{% code overflow="wrap" %}
```solidity
function _voteSucceeded(uint256 proposalId) internal view virtual override returns (bool) {
    (uint256 againstVotes, uint256 forVotes,) = proposalVotes(proposalId);
    uint256 threshold = (forVotes + againstVotes) * 51 / 100;
    return forVotes >= threshold;
}
```
{% endcode %}

`Custom Code`

{% code overflow="wrap" %}
```solidity
// Continuous voting system based on logarithmic function
contract ConcentrationWarning {
    event ConcentrationWarning(address indexed user, uint256 concentration);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    
    function calculateLogWeight(uint256 bgtAmount) public view returns (uint256) {
        uint256 totalSupply = getTotalBGTSupply();
        uint256 userPercentage = bgtAmount * 1e18 / totalSupply; // 18 decimals
        
        // 0% gets 0 voting power
        if (userPercentage == 0) return 0;
        
        // Log scaling: percentage * log(percentage + 1) / log(101)
        // +1 prevents log(0), 101 normalizes maximum value
        uint256 logFactor = ln(userPercentage + 1e18) * 1e18 / ln(101e18);
        
        return bgtAmount * logFactor / 1e18;
    }
    
    function calculateSqrtLogWeight(uint256 bgtAmount) public view returns (uint256) {
        uint256 totalSupply = getTotalBGTSupply();
        uint256 userPercentage = bgtAmount * 1e18 / totalSupply;
        
        if (userPercentage == 0) return 0;
        
        // Square root + log combination: sqrt(amount) * log_scaling
        uint256 sqrtAmount = sqrt(bgtAmount);
        uint256 logScale = ln(userPercentage + 1e18) * 1e18 / ln(101e18);
        
        return sqrtAmount * logScale / 1e18;
    }
    
    function calculateAdvancedLogWeight(uint256 bgtAmount) public view returns (uint256) {
        uint256 totalSupply = getTotalBGTSupply();
        uint256 userPercentage = bgtAmount * 1e18 / totalSupply;
        
        if (userPercentage == 0) return 0;
        
        // Smoother curve: amount * (log(percentage + 1) / log(101))^2
        uint256 logFactor = ln(userPercentage + 1e18) * 1e18 / ln(101e18);
        uint256 squaredLogFactor = logFactor * logFactor / 1e18;
        
        return bgtAmount * squaredLogFactor / 1e18;
    }
    
    function castLogVote(uint256 proposalId, bool support) external {
        uint256 weight = calculateLogWeight(getBGTBalance(msg.sender));
        uint256 concentration = getConcentration(msg.sender);
        
        // Warning for concentration above 15% (monitoring purpose)
        if (concentration > 15e16) {
            emit ConcentrationWarning(msg.sender, concentration);
        }
        
        emit VoteCast(proposalId, msg.sender, support, weight);
    }
    
    // Gas-efficient natural logarithm approximation function
    function ln(uint256 x) internal pure returns (uint256) {
        require(x > 0, "ln: zero input");
        
        uint256 result = 0;
        uint256 y = x;
        
        // Simple natural logarithm approximation
        while (y >= 2e18) {
            result += 693147180559945309; // ln(2) * 1e18
            y = y / 2;
        }
        
        // Taylor series approximation for ln(1+x) where x is small
        if (y > 1e18) {
            uint256 z = y - 1e18;
            result += z - (z * z) / (2e18) + (z * z * z) / (3e36);
        }
        
        return result;
    }
    
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
}
```
{% endcode %}

***

### Threat 2: Inadequate Governance Proposal Verification <a href="#id-2" id="id-2"></a>

There is a risk that malicious reward vaults or incentive tokens could be approved through governance. This could allow an attacker to steal funds or compromise system stability.

#### Impact

`Low`

Whitelisting a vulnerable token or vault in governance could threaten the protocol's entire assets, but the probability is low due to Berachain's timelock (2 days) and Guardian intervention (5-of-9 multisig). Therefore, it is rated `Low`.

#### Guideline

> * **Mandate a multi-layered verification process for reward vault and incentive token proposals, including technical review, economic impact analysis, and security audits, and assign independent reviewer groups for each stage.**
>   * Appoint reviewer groups for each stage.
>     * Reviewers are selected through a governance vote and are designated for technical and economic fields.
>     * Verification of conflicts of interest with the protocol is also conducted during the governance process.
> * **Only allow proposals based on pre-verified contract templates or standards, and require new types of components to undergo additional security audits and testnet verification.**
>   * **Standard Template:** Basic review procedure.
>   * **Improved and Innovative Template:** In addition to the basic review procedure, expand the audit and review procedures.
> * **Deploy new components by starting on a limited scale and gradually expanding to minimize potential damage.**
>   * A phased verification process through TVL limits and participant count restrictions for whitelisted tokens and vaults.
>   * Register as an official token and vault after a [**minimum period (2-3 weeks, based on the average feedback time in DeFi)**](../../reference.md#id-29.-average-defi-feedback-time-2-3-weeks)<sub>29</sub> to gather opinions from ecosystem participants.
> * **Passed proposals require a** [**timelock period**](../../reference.md#id-28.-berachain-timelock-2-days-guardian-intervention-5-of-9-multisig)<sub>28</sub> **for verification by the Guardians.**

#### Best Practice

[`BerachainGovernance.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Core/src/gov/BerachainGovernance.sol#L84-L95)

{% code overflow="wrap" %}
```solidity
function _voteSucceeded(uint256 proposalId) internal view virtual override returns (bool) {
    (uint256 againstVotes, uint256 forVotes,) = proposalVotes(proposalId);
    uint256 threshold = (forVotes + againstVotes) * 51 / 100;
    return forVotes >= threshold;
}
```
{% endcode %}

`Custom Code`

{% code overflow="wrap" %}
```solidity
// A system where proposals are divided into technical review -> economic review -> security audit stages, with approvers for each stage verifying sequentially.

contract ComponentValidator {
    enum ValidationStage { TECHNICAL, ECONOMIC, SECURITY, APPROVED }
    mapping(uint256 => ValidationStage) public proposalStage;
    mapping(ValidationStage => mapping(address => bool)) public reviewers;

    function approveStage(uint256 proposalId, ValidationStage stage) external {
        require(reviewers[stage][msg.sender], "Unauthorized");
        if (stage == ValidationStage.SECURITY) {
            proposalStage[proposalId] = ValidationStage.APPROVED;
        } else {
            proposalStage[proposalId] = ValidationStage(uint(stage) + 1);
        }
    }
}
```
{% endcode %}

***

### Threat 3: Rejection Due to Conflict of Interest <a href="#id-3" id="id-3"></a>

There is a concern that the foundation or guardians may reject proposals that are disadvantageous to them, preventing governance from functioning fairly and leading to centralization.\
This can hinder the community's legitimate decision-making and undermine the system's decentralization.

#### Impact

`Low`

If the foundation pursues self-interest, it is likely to lead to user losses, but the probability of this happening is low due to Berachain's timelock (2 days) and Guardian intervention (5-of-9 multisig). Therefore, it is rated `Low`.

#### Guideline

> * **When rejecting any proposal, disclose specific and objective reasons and provide a mechanism for the community to appeal.**
>   * **Appeal Mechanism:** Form an [**independent arbitration committee**](../../reference.md#id-30.-independent-arbitration-committee-protocol-case)<sub>30</sub> (same process as reviewer selection) and grant it the following powers:
>     * Independently review and propose replacements for decisions made by the foundation or guardians.
>     * Re-submit rejected proposals.
>     * Challenge unfair decisions and exercises of authority.
> * **Transparently disclose the interests of governance participants and restricㅋㅋt or weaken their voting participation in proposals where they have a direct interest.**
>   * Restrict the participation of protocol-related parties in votes concerning the protocol.
>   * Limit the BGT held by the foundation and its sponsored validators to 30% for votes concerning the core.
> * **Address concerns about centralization due to foundation-sponsored validators.**
>   * Disclose the amount of BGT received from the foundation by sponsored validators and provide a dashboard of the foundation's holdings.
>   * Transparently disclose the operating entity of each validator and their relationship with the foundation.

#### Best Practice

[`GovDeployer.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Core/src/gov/GovDeployer.sol#L56-L58)

```solidity
if (guardian != address(0)) {
    timelock.grantRole(timelock.CANCELLER_ROLE(), guardian);
}
```

`Custom Code`

{% code overflow="wrap" %}
```solidity
// A system that ensures transparency by recording specific reasons, rejecters, and times for proposal rejections, allowing the community to verify the reasons for rejection.

contract TransparentGovernance {
    struct RejectionRecord {
        string reason;
        address rejectedBy;
        uint256 timestamp;
    }

    mapping(uint256 => RejectionRecord) public rejections;

    function rejectProposal(uint256 proposalId, string memory reason) external onlyGuardian {
        require(bytes(reason).length > 0, "Reason required");
        rejections[proposalId] = RejectionRecord(reason, msg.sender, block.timestamp);
        emit ProposalRejected(proposalId, reason, msg.sender);
    }
}
```
{% endcode %}

***

### Threat 4: Limitations of Unimplemented On-Chain Governance Logic <a href="#id-4" id="id-4"></a>

Governance is not yet implemented on-chain and operates through forum-based voting, which makes it difficult to meet the voter turnout threshold (20%) and makes the decision-making process inefficient or susceptible to manipulation.

#### Impact

`Informational`

The protocol also plans to implement on-chain governance, but since it is [**currently not implemented**](../../reference.md#id-31.-regarding-full-governance-implementation)<sub>31</sub>, it is rated as `Informational`.

#### Guideline

> * **Ensure transparency and verifiability for forum voting until on-chain implementation is complete.**
>   * Collect forum voting data and put it on-chain so that anyone can view it.
>   * Use 5-minute snapshots of the voting process to reflect the results in real-time until the announcement.
> * **Introduce a Sybil attack prevention mechanism.**
>   * Introduce a minimum BGT requirement for voting (e.g. only users holding more than 100 BGT can vote).
>   * Track and block multiple accounts from the same IP/device.

#### Best Practice

[`BerachainGovernance.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Core/src/gov/BerachainGovernance.sol#L110-L127)

{% code overflow="wrap" %}
```solidity
function _countVote(
    uint256 proposalId,
    address account,
    uint8 support,
    uint256 totalWeight,
    bytes memory params
)
    internal
    override(GovernorUpgradeable, GovernorCountingSimpleUpgradeable)
    returns (uint256)
{
    // Avoid off-chain issues.
    if (totalWeight == 0) {
        GovernorZeroVoteWeight.selector.revertWith();
    }

    return GovernorCountingSimpleUpgradeable._countVote(proposalId, account, support, totalWeight, params);
}
```
{% endcode %}

[`GovDeployer.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Core/src/gov/GovDeployer.sol#L61-L66)

```solidity
InitialGovernorParameters memory params = InitialGovernorParameters({
    proposalThreshold: proposalThreshold * (10 ** IERC20Metadata(token).decimals()),
    quorumNumeratorValue: quorumNumeratorValue,
    votingDelay: uint48(votingDelay),
    votingPeriod: uint32(votingPeriod)
});
```

`Custom Code`

{% code overflow="wrap" %}
```solidity
// An on-chain verification system for forum vote transparency and Sybil resistance.
contract ForumVoteTracker {
    struct VoteSnapshot {
        uint256 timestamp;
        uint256 forVotes;
        uint256 againstVotes;
        bytes32 dataHash;
    }

    mapping(uint256 => VoteSnapshot[]) public proposalSnapshots;
    mapping(address => uint256) public minBGTRequired;

    function recordSnapshot(uint256 proposalId, uint256 forVotes, uint256 againstVotes) external {
        require(getBGTBalance(msg.sender) >= 100e18, "Insufficient BGT");

        proposalSnapshots[proposalId].push(VoteSnapshot({
            timestamp: block.timestamp,
            forVotes: forVotes,
            againstVotes: againstVotes,
            dataHash: keccak256(abi.encode(forVotes, againstVotes, block.timestamp))
        }));
    }
}
```
{% endcode %}

***

### Threat 5: Inadequate Advance Notice of Governance Changes <a href="#id-5" id="id-5"></a>

If users are not given sufficient advance notice when a governance proposal passes and a system change is made, Berachain's current 7-day notice period may be insufficient for users to respond. This could lead to unexpected losses for users or a decline in trust.

In particular, changes to fees, token economics, and the introduction of new restrictions can directly affect users' investment strategies and asset management.

#### Impact

`Informational`

It can affect user trust and investment direction, but it is not a direct vulnerability, so it is rated `Informational`.

#### Guideline

> * **Allow a** [**minimum notice period of 14 days**](../../reference.md#id-32.-average-defi-notice-period-14-days)<sub>32</sub> **from the time a governance proposal passes until it is actually implemented.** > **Announce the changes through various channels a total of three times: immediately after the proposal passes, 7 days before implementation, and 1 day before implementation.**
> * **Provide a longer notice period (up to 30 days) for changes that directly affect user assets (such as fees, interest rates, liquidation thresholds) to ensure users have enough time to respond.**
> * **Provide a simulation tool that allows users to check the impact of changes on their positions in advance to support proactive responses.**

#### Best Practice

[**`BerachainGovernance.sol`**](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Core/src/gov/BerachainGovernance.sol#L134-L151)

{% code overflow="wrap" %}
```solidity
function state(uint256 proposalId) public view override returns (ProposalState) {
    return GovernorTimelockControlUpgradeable.state(proposalId);
}

function proposalNeedsQueuing(uint256 proposalId) public view override returns (bool) {
    return GovernorTimelockControlUpgradeable.proposalNeedsQueuing(proposalId);
}
```
{% endcode %}

`Custom Code`

{% code overflow="wrap" %}
```solidity
// A notification system that sets different notice periods based on the impact of a proposal to provide users with sufficient preparation time.
contract GovernanceNotificationSystem {
    enum ImpactLevel { LOW, MEDIUM, HIGH, CRITICAL }

    mapping(uint256 => uint256) public effectiveTime;
    mapping(uint256 => ImpactLevel) public impactLevel;

    function queueProposal(uint256 proposalId, ImpactLevel impact) external {
        uint256 delay = impact >= ImpactLevel.HIGH ? 30 days : 14 days;
        effectiveTime[proposalId] = block.timestamp + delay;
        impactLevel[proposalId] = impact;

        emit ProposalQueued(proposalId, delay, impact);
    }

    function canExecute(uint256 proposalId) external view returns (bool) {
        return block.timestamp >= effectiveTime[proposalId];
    }
}
```
{% endcode %}
