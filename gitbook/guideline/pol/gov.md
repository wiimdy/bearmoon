---
icon: square-poll-vertical
---

# PoL 보안 가이드라인: 거버넌스

<table><thead><tr><th width="591.765625">위협</th><th align="center">영향도</th></tr></thead><tbody><tr><td><a data-mention href="gov.md#id-1">#id-1</a></td><td align="center"><code>High</code></td></tr><tr><td><a data-mention href="gov.md#id-2">#id-2</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="gov.md#id-3">#id-3</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="gov.md#id-4">#id-4</a></td><td align="center"><code>Informational</code></td></tr><tr><td><a data-mention href="gov.md#id-5">#id-5</a></td><td align="center"><code>Informational</code></td></tr></tbody></table>

### 위협 1: BGT 독점에 의한 거버넌스 조작 <a href="#id-1" id="id-1"></a>

대규모 LSD 프로토콜에 사용자가 몰릴 경우 BGT를 대규모 보유할 수 있고, 하나의 프로토콜이 BGT를 대량 보유할 경우 투표를 조작하여 프로토콜에 유리한 정책을 강제할 수 있다.

#### 영향도

`High`

하나의 프로토콜이 조작을 일으킬 수 있어 거버넌스가 무의미해지며 실현가능성 및 영향도가 크기에 `High` 로 평가한다.

#### 가이드라인

> * **단일 엔티티나 프로토콜이 전체 BGT의 일정 비율(15%) 이상을 보유할 때 경고 메커니즘 도입**
>   * 15% 기준은 제안이 올라가는 기준인 20%의 3/4로 설정
> * **특정 비율을 넘어간 BGT에 대해서 선형적인 투표권 대신 영향력이 감소하는 방식으로 대량 보유자의 영향력을 축소**
>   * 제곱근 기반 [**Quadratic Voting**](../../reference.md#quadratic-voting) 방식 적용하여 대량 보유자의 영향력 축소

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

`커스텀 코드`

{% code overflow="wrap" %}
```solidity
// BGT 보유량의 제곱근으로 투표권을 계산하여 대량 보유자에 페널티를 적용하여 영향력을 제한하는 투표 시스템
contract ConcentrationWarning {
    event ConcentrationWarning(address indexed user, uint256 concentration);
    
    function calculateQuadraticWeight(uint256 bgtAmount) public pure returns (uint256) {
        return sqrt(bgtAmount);
    }
    
    function castQuadraticVote(uint256 proposalId, bool support) external {
        uint256 weight = calculateQuadraticWeight(getBGTBalance(msg.sender));
        uint256 concentration = getConcentration(msg.sender);
        
        // 15% 이상: 경고 발생
        if (concentration > 15e16) {
            emit ConcentrationWarning(msg.sender, concentration);
        }
        
        emit VoteCast(proposalId, msg.sender, support, weight);
    }
    
    function getConcentration(address user) public view returns (uint256) {
        uint256 totalBGT = getTotalBGTSupply();
        uint256 userBGT = getBGTBalance(user) + getDelegatedBGT(user);
        return userBGT * 1e18 / totalBGT;
    }
    
    function isHighConcentration(address user) external view returns (bool) {
        return getConcentration(user) > 15e16;
    }
}



```
{% endcode %}

***

### 위협 2: 거버넌스 제안 검증 미흡 <a href="#id-2" id="id-2"></a>

거버넌스를 통해 악의적인 보상 금고나 인센티브 토큰이 승인될 위험이 존재 한다. 이를 통해 공격자가 자금을 탈취하거나 시스템 안정성을 해칠 수 있다.

#### 영향도

`Low`

거버넌스에서 취약한 토큰이나 금고를 화이트리스팅 할 경우 프로토콜 전체 자산 위협 가능성 있지만, Berachain의 타임락(2일)과 Guardian 개입(5-of-9 multisig)으로 인해 발생 확률 낮아 `Low` 로 평가

#### 가이드라인

> * **보상 금고 및 인센티브 토큰 제안에 대해 기술적 검토, 경제적 영향 분석, 보안 감사를 포함한 다층적 검증 프로세스를 의무화하고 각 단계별로 독립적인 검토자 그룹을 배정**
>   * 각 단계별 검토자 그룹을 리뷰어 지정
>     * 리뷰어의 경우는 거버넌스 투표로 산출하며 기술, 경제 분야를 나누어 지정
>     * 프로토콜과 이해관계에 대한 검증도 거버넌스 과정에서 진행
> * **사전에 검증된 컨트랙트 템플릿이나 표준을 기반으로 한 제안만 허용하고 새로운 형태의 컴포넌트는 추가적인 보안 감사와 테스트넷 검증을 거치도록 함**
>   * **표준 템플릿:** 기본 검토 절차
>   * **개선 및 혁신형 템플릿:** 기본 검토 절차에 더해 오딧 절차 및 리뷰 절차 확대
> * **새로운 컴포넌트는 제한된 규모로 시작하여 점진적으로 확장하는 방식으로 배포하여 잠재적 피해를 최소화**
>   * 제한은 화이트 리스팅 된 토큰 및 금고에 대해 TVL 한도, 참여자 수 제한을 통한 단계적 검증 절차
>   * 생태계 참여자들의 의견을 수렴할 수 있는 [**최소한의 기한(2\~3주, DeFi 평균 피드백 소요 시간 기준)**](../../reference.md#defi-2-3)를 거쳐 정식 토큰 및 금고로 등록
> * **통과된 제안은 가디언즈의 검증을 거칠** [**타임락 기간**](../../reference.md#berachain-2-guardian-5-of-9-multisig) **필요**

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

`커스텀 코드`

{% code overflow="wrap" %}
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
{% endcode %}

***

### 위협 3: 사익 충돌로 인한 거절 <a href="#id-3" id="id-3"></a>

재단이나 가디언즈가 자신에게 불리한 제안을 거부하여 거버넌스가 공정하게 작동하지 않고 중앙화될 우려가 있다.\
이는 커뮤니티의 정당한 의사결정을 방해하고 시스템의 탈중앙화를 훼손할 수 있다.

#### 영향도

`Low`

재단입장에서 사익을 추구하게 되면 사용자의 손실로 이어질 가능성이 높지만, Berachain의 타임락(2일)과 가디언의 멀티시그(5-of-9 multisig)로 인해 발생 확률이 낮아 `Low`로 평가.

#### 가이드라인

> * **모든 제안 거부 시 구체적이고 객관적인 사유를 공개하고 커뮤니티가 이에 대해 이의제기 메커니즘 제공**
>   * **이의제기 메커니즘:** [**독립적인 중재 위원회**](../../reference.md#undefined-8)(리뷰어 선출 과정과 동일)를 구성하여 다음 권한 부여
>     * 재단이나 가디언즈의 결정에 대해 독립적으로 검토 및 교체 제안
>     * 부결된 안건에 대한 재상정
>     * 부당한 결정 및 권한행사에 대한 챌린지
> * **거버넌스 참여자들의 이해관계를 투명하게 공개하고 직접적인 이해관계가 있는 제안에 대해서는 투표 참여 제한 또는 약화**
>   * 프로토콜에 관한 투표의 경우 프로토콜 관련자 투표 참여 제한
>   * 코어에 관한 투표의 경우 재단 및 재단 물량 검증자의 참여가능 BGT 물량을 30%로 제한
> * **재단 후원 검증자로 인한 중앙화 우려 해소**
>   * 재단으로부터 네이티브 토큰 물량을 받은 검증자의 재단 물량 공개 및 재단 보유량 대쉬보드 제공
>   * 각 검증자의 운영 주체, 재단과의 관계 투명하게 공개

#### Best Practice

[`GovDeployer.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Core/src/gov/GovDeployer.sol#L56-L58)

```solidity
if (guardian != address(0)) {
    timelock.grantRole(timelock.CANCELLER_ROLE(), guardian);
}
```

`커스텀 코드`

{% code overflow="wrap" %}
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
{% endcode %}

***

### 위협 4: 온체인 거버넌스 로직 미구현 제한 <a href="#id-4" id="id-4"></a>

거버넌스가 아직 온체인에 구현되지 않아 포럼 기반 투표로 운영되며, 이로 인해 투표율(20%) 충족이 어렵고 의사결정 과정이 비효율적이거나 조작 가능성이 있다.

#### 영향도

`Informational`

프로토콜 역시 온체인 거버넌스를 구현할 계획을 가지고 있지만 현재 [**구현이 안된 상태**](../../reference.md#undefined-9)이기에 `Informational` 평가

#### 가이드라인

> * **온체인 구현 전까지 포럼 투표에 대해 투명성과 검증 가능성 확보**
>   * 포럼 투표에 대한 데이터를 모아 온체인 데이터로 올려 누구나 볼 수 있게 구현
>   * 투표과정에 대해서도 5분단위의 스냅샷을 활용하여 결과 투표 상황이 실시간으로 반영되게 구현
> * **Civil 공격 방지 메커니즘 도입**
>   * 투표에 필요한 최소한의 BGT 제한 도입(예시: 100 BGT 이상 보유한 사용자만 투표 가능)
>   * 동일 IP/디바이스 다중 계정 추적 및 모니터링

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

`커스텀 코드`

{% code overflow="wrap" %}
```solidity
// 포럼 투표 투명성 및 시빌 저항성을 위한 온체인 검증 시스템
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

### 위협 5: 거버넌스 변경 사항 사전 고지 미흡 <a href="#id-5" id="id-5"></a>

거버넌스 제안이 통과되어 시스템 변경이 이루어질 때 사용자들에게 충분한 사전 고지가 부족하다면 Berachain의 현재 7일 공지 기간이 사용자 대응에 부족할 수 있다. 이는 사용자의 예상치 못한 손실이나 신뢰도 저하로 이어질 수 있다.

특히 수수료 변경, 토큰노믹스 수정, 신규 제약사항 도입 등은 사용자의 투자 전략과 자산 관리에 직접적인 영향을 미칠 수 있다.

#### 영향도

`Informational`

사용자의 신뢰도 저하 및 투자 방향에 영향을 미칠 수 있지만 직접적인 취약점은 아니므로 `Informational` 로 평가

#### 가이드라인

> * **거버넌스 제안 통과 후 실제 적용까지** [**최소 14일의 공지 기간**](../../reference.md#defi-14)**을 두고**\
>   **제안 통과 즉시, 적용 7일 전, 적용 1일 전 총 3차례에 걸쳐 다양한 채널을 통해 변경사항을 공지**
> * **사용자 자산에 직접적인 영향을 미치는 변경사항(수수료, 이자율, 청산 임계값 등)에 대해서 더 긴 공지 기간(최대 30일)을 제공하여 사용자가 대응할 수 있는 충분한 시간 확보**
> * **사용자가 변경사항이 자신의 포지션에 미칠 영향을 미리 확인할 수 있는 시뮬레이션 도구를 제공하여 사전 대응 지원**

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

`커스텀 코드`

{% code overflow="wrap" %}
```solidity
// 제안의 영향도에 따라 차등적인 공지 기간을 설정하여 사용자에게 충분한 준비 시간을 제공하는 알림 시스템
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
