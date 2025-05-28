---
icon: square-poll-vertical
---

# PoL 보안 가이드라인: 거버넌스

<table><thead><tr><th width="591.765625">위협</th><th align="center">영향도</th></tr></thead><tbody><tr><td><a data-mention href="gov.md#ec-9c-84-ed-98-911-ec-95-85-ec-84-b1-ec-bb-b4-ed-8f-ac-eb-84-8c-ed-8a-b8-ec-8a-b9-ec-9d-b8">#ec-9c-84-ed-98-911-ec-95-85-ec-84-b1-ec-bb-b4-ed-8f-ac-eb-84-8c-ed-8a-b8-ec-8a-b9-ec-9d-b8</a></td><td align="center"><code>Medium</code></td></tr><tr><td><a data-mention href="gov.md#ec-9c-84-ed-98-911-ec-95-85-ec-84-b1-ec-bb-b4-ed-8f-ac-eb-84-8c-ed-8a-b8-ec-8a-b9-ec-9d-b8-1">#ec-9c-84-ed-98-911-ec-95-85-ec-84-b1-ec-bb-b4-ed-8f-ac-eb-84-8c-ed-8a-b8-ec-8a-b9-ec-9d-b8-1</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="gov.md#ec-9c-84-ed-98-911-ec-95-85-ec-84-b1-ec-bb-b4-ed-8f-ac-eb-84-8c-ed-8a-b8-ec-8a-b9-ec-9d-b8-2">#ec-9c-84-ed-98-911-ec-95-85-ec-84-b1-ec-bb-b4-ed-8f-ac-eb-84-8c-ed-8a-b8-ec-8a-b9-ec-9d-b8-2</a></td><td align="center"><code>Informational</code></td></tr><tr><td><a data-mention href="gov.md#ec-9c-84-ed-98-914-ec-9e-ac-eb-8b-a8-ed-9b-84-ec-9b-90-ea-b8-b0-eb-b0-98-validator-eb-a1-9c-ec-9d-b8">#ec-9c-84-ed-98-914-ec-9e-ac-eb-8b-a8-ed-9b-84-ec-9b-90-ea-b8-b0-eb-b0-98-validator-eb-a1-9c-ec-9d-b8</a></td><td align="center"><code>Informational</code></td></tr><tr><td><a data-mention href="gov.md#ec-9c-84-ed-98-915-bgt-eb-8f-85-ec-a0-90-ec-97-90-ec-9d-98-ed-95-9c-governance-ec-a1-b0-ec-9e-91">#ec-9c-84-ed-98-915-bgt-eb-8f-85-ec-a0-90-ec-97-90-ec-9d-98-ed-95-9c-governance-ec-a1-b0-ec-9e-91</a></td><td align="center"><code>Informational</code></td></tr><tr><td><a data-mention href="gov.md#ec-9c-84-ed-98-916-ea-b1-b0-eb-b2-84-eb-84-8c-ec-8a-a4-ec-a0-9c-ec-95-88-ea-b2-80-ec-a6-9d-eb-af-b8">#ec-9c-84-ed-98-916-ea-b1-b0-eb-b2-84-eb-84-8c-ec-8a-a4-ec-a0-9c-ec-95-88-ea-b2-80-ec-a6-9d-eb-af-b8</a></td><td align="center"><code>Informational</code></td></tr><tr><td><a data-mention href="gov.md#ec-9c-84-ed-98-917-ec-82-ac-ec-9a-a9-ec-9e-90-ea-b3-a0-ec-a7-80-eb-b6-80-ec-a1-b1-ec-9c-bc-eb-a1-9c">#ec-9c-84-ed-98-917-ec-82-ac-ec-9a-a9-ec-9e-90-ea-b3-a0-ec-a7-80-eb-b6-80-ec-a1-b1-ec-9c-bc-eb-a1-9c</a></td><td align="center"><code>Informational</code></td></tr></tbody></table>

### 위협 1: 악성 컴포넌트 승인 <a href="#ec-9c-84-ed-98-911-ec-95-85-ec-84-b1-ec-bb-b4-ed-8f-ac-eb-84-8c-ed-8a-b8-ec-8a-b9-ec-9d-b8" id="ec-9c-84-ed-98-911-ec-95-85-ec-84-b1-ec-bb-b4-ed-8f-ac-eb-84-8c-ed-8a-b8-ec-8a-b9-ec-9d-b8"></a>

거버넌스를 통해 악의적인 보상 금고나 인센티브 토큰이 승인될 위험이 존재 한다. 이를 통해 공격자가 자금을 탈취하거나 시스템 안정성을 해칠 수 있다.

#### 가이드라인

> * **보상 금고 및 인센티브 토큰 제안에 대해 기술적 검토, 경제적 영향 분석, 보안 감사를 포함한 다층적 검증 프로세스를 의무화하고 각 단계별로 독립적인 검토자 그룹을 배정.**
> * **사전에 검증된 컨트랙트 템플릿이나 표준을 기반으로 한 제안만 허용하고 새로운 형태의 컴포넌트는 추가적인 보안 감사와 테스트넷 검증을 거치도록 함.**
> * **새로운 컴포넌트는 제한된 규모로 시작하여 점진적으로 확장하는 방식으로 배포하여 잠재적 피해를 최소화.**

#### Best Practice

[`BerachainGovernance.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Core/src/gov/BerachainGovernance.sol#L84-L95)&#x20;

```solidity
function _voteSucceeded(uint256 proposalId) internal view virtual override returns (bool) {
    (uint256 againstVotes, uint256 forVotes,) = proposalVotes(proposalId);
    uint256 threshold = (forVotes + againstVotes) * 51 / 100;
    return forVotes >= threshold;
}
```

`커스텀 코드`&#x20;

```solidity
// 제안을 기술적 검토 → 경제적 검토 → 보안 감사 단계로 나누어 각 단계별 승인자가 순차적으로 검증하는 시스템

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

***

### 위협 2: 사익 충돌로 인한 거절 <a href="#ec-9c-84-ed-98-911-ec-95-85-ec-84-b1-ec-bb-b4-ed-8f-ac-eb-84-8c-ed-8a-b8-ec-8a-b9-ec-9d-b8" id="ec-9c-84-ed-98-911-ec-95-85-ec-84-b1-ec-bb-b4-ed-8f-ac-eb-84-8c-ed-8a-b8-ec-8a-b9-ec-9d-b8"></a>

재단이나 가디언즈가 자신에게 불리한 제안을 거부하여 거버넌스가 공정하게 작동하지 않고 중앙화될 우려가 있다. \
이는 커뮤니티의 정당한 의사결정을 방해하고 시스템의 탈중앙화를 훼손할 수 있다.

#### 가이드라인

> * **모든 제안 거부 시 구체적이고 객관적인 사유를 공개하고 커뮤니티가 이에 대해 이의제기할 수 있는 메커니즘 제공.**
> * **재단이나 가디언즈의 결정에 대해 독립적으로 검토할 수 있는 중재 위원회를 구성하여 견제와 균형 확보.**
> * **거버넌스 참여자들의 이해관계를 투명하게 공개하고 직접적인 이해관계가 있는 제안에 대해서는 투표 참여를 제한.**

#### Best Practice

[`GovDeployer.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Core/src/gov/GovDeployer.sol#L56-L58)&#x20;

```solidity
if (guardian != address(0)) {
    timelock.grantRole(timelock.CANCELLER_ROLE(), guardian);
}
```

`커스텀 코드`&#x20;

```solidity
// 제안 거부 시 구체적인 사유와 거부자, 시간을 기록하여 투명성을 확보하고 커뮤니티가 거부 사유를 확인할 수 있는 시스템

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

***

### 위협 3: 온체인 거버넌스 로직 미구현 제한 <a href="#ec-9c-84-ed-98-911-ec-95-85-ec-84-b1-ec-bb-b4-ed-8f-ac-eb-84-8c-ed-8a-b8-ec-8a-b9-ec-9d-b8" id="ec-9c-84-ed-98-911-ec-95-85-ec-84-b1-ec-bb-b4-ed-8f-ac-eb-84-8c-ed-8a-b8-ec-8a-b9-ec-9d-b8"></a>

거버넌스가 아직 온체인에 구현되지 않아 포럼 기반 투표로 운영되며, 이로 인해 투표율(20%) 충족이 어렵고 의사결정 과정이 비효율적이거나 조작 가능할 수 있다.

#### 가이드라인

> * **온체인 구현 전까지 포럼 투표와 snapshot 등을 결합한 하이브리드 시스템으로 투표의 투명성과 검증 가능성 확보.**
> * **거버넌스 참여에 대한 적절한 인센티브를 제공하여 투표율을 높여야함.**
> * **시빌 공격을 통해 포럼의 여론을 조작하려는 행위를 방지하는 메커니즘 도입.**

#### Best Practice

[`BerachainGovernance.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Core/src/gov/BerachainGovernance.sol#L110-L127)

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

&#x20;[`GovDeployer.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Core/src/gov/GovDeployer.sol#L61-L66)&#x20;

```solidity
InitialGovernorParameters memory params = InitialGovernorParameters({
    proposalThreshold: proposalThreshold * (10 ** IERC20Metadata(token).decimals()),
    quorumNumeratorValue: quorumNumeratorValue,
    votingDelay: uint48(votingDelay),
    votingPeriod: uint32(votingPeriod)
});
```

`커스텀 코드`&#x20;

```solidity
// 거버넌스 투표 참여자에게 토큰 보상을 지급하여 투표율을 높이고 커뮤니티 참여를 장려하는 인센티브 시스템

contract ParticipationIncentive {
    mapping(address => uint256) public participationRewards;
    uint256 public constant VOTE_REWARD = 10e18;
    
    function castVoteWithReward(uint256 proposalId, bool support) external {
        require(getBGTBalance(msg.sender) > 0, "No voting power");
        participationRewards[msg.sender] += VOTE_REWARD;
        emit VoteCast(proposalId, msg.sender, support);
    }
}
```

***

### 위협 4: 재단 후원 기반 검증자로 인한 중앙화 우려 <a href="#ec-9c-84-ed-98-914-ec-9e-ac-eb-8b-a8-ed-9b-84-ec-9b-90-ea-b8-b0-eb-b0-98-validator-eb-a1-9c-ec-9d-b8" id="ec-9c-84-ed-98-914-ec-9e-ac-eb-8b-a8-ed-9b-84-ec-9b-90-ea-b8-b0-eb-b0-98-validator-eb-a1-9c-ec-9d-b8"></a>

검증자의 자산이 재단 물량일 경우 검증자가 재단에 종속받는 구조가 되므로 거버넌스 투표가 재단에 의해 중앙화될 우려가 있다.

#### 가이드라인

> * **검증자 운영에 필요한 자산의 출처를 다양화하고, 재단 의존도를 점진적으로 줄이는 계획 수립.**
> * **각 검증자의 운영 주체, 재단과의 관계를 투명하게 공개하여 커뮤니티가 정보에 기반한 선택을 할 수 있도록 함.**
> * **재단으로부터 물량을 받은 경우 비율을 공개하여 중앙화 우려를 해소해야함.**

#### Best Practice

&#x20;[`GovDeployer.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Core/src/gov/GovDeployer.sol#L42-L43)

```solidity
// Check if the token implements ERC20Votes and ERC20 metadata
_checkIfERC20Votes(token);
```

`커스텀 코드`&#x20;

```solidity
// 검증자의 재단 의존도를 모니터링하고 30% 이하로 제한하여 중앙화를 방지하는 독립성 점수 시스템

contract ValidatorIndependence {
    struct ValidatorInfo {
        uint256 foundationStake;
        uint256 communityStake;
        uint256 independenceScore;
    }
    
    mapping(address => ValidatorInfo) public validators;
    uint256 public constant MAX_FOUNDATION_RATIO = 30e16; // 30%
    
    function registerValidator(address validator, uint256 foundationStake, uint256 communityStake) external {
        uint256 ratio = (foundationStake * 1e18) / (foundationStake + communityStake);
        require(ratio <= MAX_FOUNDATION_RATIO, "Excessive foundation dependency");
        validators[validator] = ValidatorInfo(foundationStake, communityStake, 1e18 - ratio);
    }
}
```

***

### 위협 5: BGT 독점에 의한 거버넌스 조작 <a href="#ec-9c-84-ed-98-915-bgt-eb-8f-85-ec-a0-90-ec-97-90-ec-9d-98-ed-95-9c-governance-ec-a1-b0-ec-9e-91" id="ec-9c-84-ed-98-915-bgt-eb-8f-85-ec-a0-90-ec-97-90-ec-9d-98-ed-95-9c-governance-ec-a1-b0-ec-9e-91"></a>

대규모 프로토콜이 사용자를 독점할 경우 전체 BGT 중 20% 이상을 얻을 수 있고 하나의 프로토콜이 BGT를 대량 보유할 경우 투표를 조작하여 프로토콜에 유리한 정책을 강제할 수 있다.

#### 가이드라인

> * **단일 엔티티나 프로토콜이 전체 BGT의 일정 비율(예: 15%) 이상을 보유할 때 경고 메커니즘 도입**
> * **특정 비율을 넘어간 BGT에 대해서 선형적인 투표권 대신 영향력이 감소하는 투표 시스템을 도입하여 대량 보유자의 영향력을 제한.**
> * **BGT 분산을 촉진하는 인센티브 구조를 설계하고 집중도가 높은 경우 추가적인 제약을 가하는 시스템 구축.**

#### Best Practice

[`BerachainGovernance.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Core/src/gov/BerachainGovernance.sol#L84-L95)&#x20;

```solidity
function _voteSucceeded(uint256 proposalId) internal view virtual override returns (bool) {
    (uint256 againstVotes, uint256 forVotes,) = proposalVotes(proposalId);
    uint256 threshold = (forVotes + againstVotes) * 51 / 100;
    return forVotes >= threshold;
}
```

`커스텀 코드`&#x20;

```solidity
// BGT 보유량의 제곱근으로 투표권을 계산하여 대량 보유자에 페널티를 적용하여 영향력을 제한하는 투표 시스템

contract QuadraticGovernance {
    function calculateQuadraticWeight(uint256 bgtAmount) public pure returns (uint256) {
        return sqrt(bgtAmount);
    }
    
    function castQuadraticVote(uint256 proposalId, bool support) external {
        uint256 weight = calculateQuadraticWeight(getBGTBalance(msg.sender));
        uint256 concentration = getConcentration(msg.sender);
        if (concentration > 15e16) weight = weight / 2; // 15% 이상 시 페널티
        emit VoteCast(proposalId, msg.sender, support, weight);
    }
}
```

***

### 위협 6: 거버넌스 제안 검증 미흡 <a href="#ec-9c-84-ed-98-916-ea-b1-b0-eb-b2-84-eb-84-8c-ec-8a-a4-ec-a0-9c-ec-95-88-ea-b2-80-ec-a6-9d-eb-af-b8" id="ec-9c-84-ed-98-916-ea-b1-b0-eb-b2-84-eb-84-8c-ec-8a-a4-ec-a0-9c-ec-95-88-ea-b2-80-ec-a6-9d-eb-af-b8"></a>

악의적인 코드 변경이나 시스템에 해로운 매개변수 변경을 포함한 제안이 충분한 검토 없이 통과하여 시스템 전체에 심각한 피해를 초래할 수 있다.

#### 가이드라인

> * **보상 금고 및 인센티브 토큰 제안에 대해 기술적 검토, 경제적 영향 분석, 보안 감사를 포함한 다층적 검증 프로세스를 의무화.**
> * **검증 프로세스의 각 단계별로 독립적인 검토자 그룹을 배정.**
> * **가디언즈에게 제안이 넘어갈 때 사전에 검증된 컨트랙트 템플릿이나 표준을 기반으로 한 제안만 허용하고 새로운 형태의 컴포넌트는 추가적인 보안 감사와 테스트넷 검증을 거치도록 함.**
> * **단계적 배포: 새로운 컴포넌트는 제한된 규모로 시작하여 점진적으로 확장하는 방식으로 배포하여 잠재적 피해를 최소화.**

#### Best Practice

[`BerachainGovernance.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Core/src/gov/BerachainGovernance.sol#L100-L108)&#x20;

```solidity
function getTimelockOperationId(uint256 proposalId) external view returns (bytes32 operationId) {
    TimelockControllerUpgradeable timelock = TimelockControllerUpgradeable(payable(_executor()));
    (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash) = proposalDetails(proposalId);
    bytes32 salt = bytes20(address(this)) ^ descriptionHash;
    operationId = timelock.hashOperationBatch(targets, values, calldatas, 0, salt);
}
```

`커스텀 코드`&#x20;

```solidity
// 제안 내용을 분석하여 금융 기능이나 권한 변경 포함 시 위험도 점수를 부여하고 고위험 제안에 대한 비상 정지 기능을 제공하는 시스템

contract ProposalValidator {
    mapping(uint256 => uint256) public riskScores; // 0-100
    mapping(uint256 => bool) public emergencyPaused;
    
    function calculateRiskScore(bytes calldata proposalData) external pure returns (uint256) {
        uint256 score = 0;
        if (containsFinancialFunctions(proposalData)) score += 40;
        if (containsAccessControlChanges(proposalData)) score += 30;
        return score > 100 ? 100 : score;
    }
    
    function emergencyPauseProposal(uint256 proposalId) external onlyGuardian {
        emergencyPaused[proposalId] = true;
    }
}
```

***

### 위협 7: 사전 고지 미흡으로 인한 신뢰도 저하 및 예상치 못한 피해 <a href="#ec-9c-84-ed-98-917-ec-82-ac-ec-9a-a9-ec-9e-90-ea-b3-a0-ec-a7-80-eb-b6-80-ec-a1-b1-ec-9c-bc-eb-a1-9c" id="ec-9c-84-ed-98-917-ec-82-ac-ec-9a-a9-ec-9e-90-ea-b3-a0-ec-a7-80-eb-b6-80-ec-a1-b1-ec-9c-bc-eb-a1-9c"></a>

거버넌스 제안이 통과되어 시스템 변경이 이루어질 때 사용자들에게 충분한 사전 고지가 없을 경우에 사용자들이 변경사항을 인지하지 못해 예상치 못한 손실을 입거나 시스템에 대한 신뢰도가 저하될 수 있다.&#x20;

특히 수수료 변경, 토큰 경제학 수정, 새로운 제약사항 도입 등은 사용자의 투자 전략과 자산 관리에 직접적인 영향을 미칠 수 있다.

#### 가이드라인

> * **다중 공지 시스템: 거버넌스 제안 통과 후 실제 적용까지 최소 14일의 공지 기간을 두고, 제안 통과 즉시, 적용 7일 전, 적용 1일 전 총 3차례에 걸쳐 다양한 채널을 통해 변경사항을 공지.**
> * **영향도별 차등 공지: 사용자 자산에 직접적인 영향을 미치는 변경사항(수수료, 이자율, 청산 임계값 등)은 더 긴 공지 기간과 더 상세한 설명을 제공하고, 사용자가 대응할 수 있는 충분한 시간 확보.**
> * **사용자 맞춤형 알림: 각 사용자의 포지션과 사용 패턴을 분석하여 해당 변경사항이 개별 사용자에게 미칠 구체적인 영향을 계산하고 개인화된 알림 제공.**
> * **변경사항 시뮬레이션 도구: 사용자가 변경사항이 자신의 포지션에 미칠 영향을 미리 확인할 수 있는 시뮬레이션 도구를 제공하여 사전 대응 가능.**

#### Best Practice

&#x20;[**`BerachainGovernance.sol`**](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Core/src/gov/BerachainGovernance.sol#L134-L151)

```solidity
function state(uint256 proposalId) public view override returns (ProposalState) {
    return GovernorTimelockControlUpgradeable.state(proposalId);
}

function proposalNeedsQueuing(uint256 proposalId) public view override returns (bool) {
    return GovernorTimelockControlUpgradeable.proposalNeedsQueuing(proposalId);
}
```

`커스텀 코드`&#x20;

```solidity
// 제안의 영향도에 따라 차등적인 공지 기간을 설정하여 사용자에게 충분한 준비 시간을 제공하는 알림 시스템

contract UserNotificationSystem {
    enum ImpactLevel { LOW, MEDIUM, HIGH, CRITICAL }
    
    struct ProposalNotification {
        uint256 effectiveTime;
        ImpactLevel impactLevel;
        string description;
    }
    
    mapping(uint256 => ProposalNotification) public notifications;
    
    function queueNotification(uint256 proposalId, ImpactLevel impact, string memory description) external {
        uint256 noticePeriod = impact >= ImpactLevel.HIGH ? 30 days : 14 days;
        notifications[proposalId] = ProposalNotification(block.timestamp + noticePeriod, impact, description);
        emit ProposalQueued(proposalId, impact);
    }
}
```

