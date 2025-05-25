---
icon: square-poll-vertical
---

# PoL 보안 가이드라인: 거버넌스



### 위협 1: 악성 컴포넌트 승인 <a href="#ec-9c-84-ed-98-911-ec-95-85-ec-84-b1-ec-bb-b4-ed-8f-ac-eb-84-8c-ed-8a-b8-ec-8a-b9-ec-9d-b8" id="ec-9c-84-ed-98-911-ec-95-85-ec-84-b1-ec-bb-b4-ed-8f-ac-eb-84-8c-ed-8a-b8-ec-8a-b9-ec-9d-b8"></a>

거버넌스를 통해 악의적인 보상 금고나 인센티브 토큰이 승인될 위험이 존재. 이를 통해 공격자가 자금을 탈취하거나 시스템 안정성을 해칠 수 있다.

#### 가이드라인

> * **보상 금고 및 인센티브 토큰 제안에 대해 기술적 검토, 경제적 영향 분석, 보안 감사를 포함한 다층적 검증 프로세스를 의무화하고, 각 단계별로 독립적인 검토자 그룹을 배정.**
> * **사전에 검증된 컨트랙트 템플릿이나 표준을 기반으로 한 제안만 허용하고, 새로운 형태의 컴포넌트는 추가적인 보안 감사와 테스트넷 검증을 거치도록 함.**
> * **새로운 컴포넌트는 제한된 규모로 시작하여 점진적으로 확장하는 방식으로 배포하여 잠재적 피해를 최소화.**

#### Best Practice

위치: `BERA_CORE/contracts/src/gov/BerachainGovernance.sol` (라인 75-85)

```solidity
contract ComponentValidator {
    enum ComponentStatus { PENDING, APPROVED, REJECTED }
    mapping(address => ComponentStatus) public componentStatus;
    
    function validateComponent(address component) external onlyValidator {
        // 보안 감사, 경제적 검토, 기술적 검토 완료 후
        componentStatus[component] = ComponentStatus.APPROVED;
    }
}
```

***

### 위협 2: 사익 충돌로 인한 거절 <a href="#ec-9c-84-ed-98-911-ec-95-85-ec-84-b1-ec-bb-b4-ed-8f-ac-eb-84-8c-ed-8a-b8-ec-8a-b9-ec-9d-b8" id="ec-9c-84-ed-98-911-ec-95-85-ec-84-b1-ec-bb-b4-ed-8f-ac-eb-84-8c-ed-8a-b8-ec-8a-b9-ec-9d-b8"></a>

재단이나 가디언즈가 자신에게 불리한 제안을 거부하여 거버넌스가 공정하게 작동하지 않고 중앙화될 우려가 있다. 이는 커뮤니티의 정당한 의사결정을 방해하고 시스템의 탈중앙화를 훼손할 수 있다.

#### 가이드라인

> * **모든 제안 거부 시 구체적이고 객관적인 사유를 공개하고 커뮤니티가 이에 대해 이의제기할 수 있는 메커니즘 제공.**
> * **재단이나 가디언즈의 결정에 대해 독립적으로 검토할 수 있는 중재 위원회를 구성하여 견제와 균형 확보.**
> * **거버넌스 참여자들의 이해관계를 투명하게 공개하고 직접적인 이해관계가 있는 제안에 대해서는 투표 참여를 제한.**

#### Best Practice

위치: `BERA_CORE/contracts/src/gov/TimeLock.sol` (라인 17)

위치: `BERA_CORE/contracts/src/gov/GovDeployer.sol` (라인 58-60)

```solidity
contract TransparentGovernance {
    struct RejectionRecord {
        uint256 proposalId;
        string reason;
        uint256 timestamp;
    }
    
    mapping(uint256 => RejectionRecord) public rejections;
    event ProposalRejected(uint256 indexed proposalId, string reason);
    
    function rejectProposal(uint256 proposalId, string memory reason) external onlyGuardian {
        rejections[proposalId] = RejectionRecord(proposalId, reason, block.timestamp);
        emit ProposalRejected(proposalId, reason);
    }
}
```

***

### 위협 3: On-chain Governance 로직 미구현 제한 <a href="#ec-9c-84-ed-98-911-ec-95-85-ec-84-b1-ec-bb-b4-ed-8f-ac-eb-84-8c-ed-8a-b8-ec-8a-b9-ec-9d-b8" id="ec-9c-84-ed-98-911-ec-95-85-ec-84-b1-ec-bb-b4-ed-8f-ac-eb-84-8c-ed-8a-b8-ec-8a-b9-ec-9d-b8"></a>

거버넌스가 아직 On-chain에 구현되지 않아 forum 기반 투표로 운영되며, 이로 인해 투표율(20%) 충족이 어렵고 의사결정 과정이 비효율적이거나 조작 가능할 수 있다.

#### 가이드라인

> * **On-chain 구현 전까지 forum 투표와 snapshot 등을 결합한 하이브리드 시스템으로 투표의 투명성과 검증 가능성 확보.**
> * **거버넌스 참여에 대한 적절한 인센티브를 제공하여 투표율을 높여야함.**
> * **시빌 공격을 통해 포럼의 여론을 조작하려는 행위를 방지하는 메커니즘 도입.**

#### Best Practice

위치: `BERA_CORE/contracts/src/gov/BerachainGovernance.sol` (라인 95-105)

위치: `BERA_CORE/contracts/src/gov/GovDeployer.sol` (라인 67-72)

```solidity
contract HybridGovernance {
    struct Vote {
        uint256 weight;
        bool support;
        bytes32 offChainProof;
    }
    
    mapping(uint256 => mapping(address => Vote)) public votes;
    uint256 public constant QUORUM_THRESHOLD = 20e16; // 20%
    
    function castVote(uint256 proposalId, bool support, bytes32 proof) external {
        votes[proposalId][msg.sender] = Vote(getBGTBalance(msg.sender), support, proof);
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

위치: `BERA_CORE/contracts/src/gov/GovDeployer.sol` (라인 29-35)

위치: `BERA_CORE/contracts/src/gov/GovDeployer.sol` (라인 67)

```solidity
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

대규모 프로토콜이 사용자를 독점할 경우 전체 BGT 중 20% 이상을 얻을 수 있고, 하나의 프로토콜이 BGT를 대량 보유할 경우 투표를 조작하여 프로토콜에 유리한 정책을 강제할 수 있다.

#### 가이드라인

> * **단일 엔티티나 프로토콜이 전체 BGT의 일정 비율(예: 15%) 이상을 보유할 때 경고 메커니즘 도입**
> * **특정 비율을 넘어간 BGT에 대해서 선형적인 투표권 대신 영향력이 감소하는 투표권(예: 제곱근 기반의 보팅)을 도입하여 대량 보유자의 영향력을 제한.**
> * **BGT 분산을 촉진하는 인센티브 구조를 설계하고, 집중도가 높은 경우 추가적인 제약을 가하는 시스템 구축.**

#### Best Practice

위치: `BERA_CORE/contracts/src/gov/BerachainGovernance.sol` (라인 95-105)

위치: `BERA_CORE/contracts/src/gov/BerachainGovernance.sol` (라인 75-85)

```solidity
contract QuadraticGovernance {
    mapping(uint256 => mapping(address => uint256)) public quadraticVotes;
    uint256 public constant MAX_CONCENTRATION = 15e16; // 15%
    
    function calculateQuadraticWeight(uint256 bgtAmount) public pure returns (uint256) {
        return sqrt(bgtAmount);
    }
    
    function castQuadraticVote(uint256 proposalId, bool support) external {
        uint256 weight = calculateQuadraticWeight(getBGTBalance(msg.sender));
        if (getConcentration(msg.sender) > MAX_CONCENTRATION) {
            weight = weight / 2; // 50% 페널티
        }
        quadraticVotes[proposalId][msg.sender] = weight;
    }
    
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) { y = z; z = (x / z + z) / 2; }
        return y;
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

위치: `BERA_CORE/contracts/src/gov/BerachainGovernance.sol` (라인 87-93)

위치: `BERA_CORE/contracts/src/gov/TimeLock.sol`

```solidity
contract ProposalValidator {
    struct ProposalReview {
        uint256 proposalId;
        bool reviewed;
        uint256 riskScore;
        uint256 reviewDeadline;
    }
    
    mapping(uint256 => ProposalReview) public reviews;
    mapping(uint256 => bool) public emergencyPaused;
    uint256 public constant MIN_REVIEW_PERIOD = 7 days;
    
    function submitProposal(uint256 proposalId) external {
        reviews[proposalId] = ProposalReview({
            proposalId: proposalId,
            reviewed: false,
            riskScore: 0,
            reviewDeadline: block.timestamp + MIN_REVIEW_PERIOD
        });
    }
    
    function emergencyPauseProposal(uint256 proposalId) external onlyGuardian {
        emergencyPaused[proposalId] = true;
    }
}
```

***

### 위협 7: 사용자 고지 부족으로 인한 신뢰도 저하 및 예상치 못한 피해 <a href="#ec-9c-84-ed-98-917-ec-82-ac-ec-9a-a9-ec-9e-90-ea-b3-a0-ec-a7-80-eb-b6-80-ec-a1-b1-ec-9c-bc-eb-a1-9c" id="ec-9c-84-ed-98-917-ec-82-ac-ec-9a-a9-ec-9e-90-ea-b3-a0-ec-a7-80-eb-b6-80-ec-a1-b1-ec-9c-bc-eb-a1-9c"></a>

거버넌스 제안이 통과되어 시스템 변경이 이루어질 때 사용자들에게 충분한 사전 고지가 없을 경우에 사용자들이 변경사항을 인지하지 못해 예상치 못한 손실을 입거나 시스템에 대한 신뢰도가 저하될 수 있다. 특히 수수료 변경, 토큰 경제학 수정, 새로운 제약사항 도입 등은 사용자의 투자 전략과 자산 관리에 직접적인 영향을 미칠 수 있다.

#### 가이드라인

> * **다단계 공지 시스템: 거버넌스 제안 통과 후 실제 적용까지 최소 14일의 공지 기간을 두고, 제안 통과 즉시, 적용 7일 전, 적용 1일 전 총 3차례에 걸쳐 다양한 채널(공식 웹사이트, 소셜미디어, 이메일, 인앱 알림)을 통해 변경사항을 공지.**
> * **영향도별 차등 공지: 사용자 자산에 직접적인 영향을 미치는 변경사항(수수료, 이자율, 청산 임계값 등)은 더 긴 공지 기간(최소 30일)과 더 상세한 설명을 제공하고, 사용자가 대응할 수 있는 충분한 시간 확보.**
> * **사용자 맞춤형 알림: 각 사용자의 포지션과 사용 패턴을 분석하여 해당 변경사항이 개별 사용자에게 미칠 구체적인 영향을 계산하고 개인화된 알림 제공.**
> * **변경사항 시뮬레이션 도구: 사용자가 변경사항이 자신의 포지션에 미칠 영향을 미리 확인할 수 있는 시뮬레이션 도구를 제공하여 사전 대응 가능.**

#### Best Practice

**위치: `BERA_CORE/contracts/src/gov/BerachainGovernance.sol`**

```solidity
// 제안 상태 확인 - 사용자가 제안의 현재 상태를 추적할 수 있음
function state(uint256 proposalId) public view returns (ProposalState)

// 제안이 큐잉이 필요한지 확인 - 타임락 적용 여부 판단
function proposalNeedsQueuing(uint256 proposalId) public view returns (bool)

// 타임락 오퍼레이션 ID 조회 - 실행 예정 시간 추적 가능
function getTimelockOperationId(uint256 proposalId) external view returns (bytes32 operationId)
```

**위치: `BERA_CORE/contracts/src/gov/TimeLock.sol`**

```solidity
// 사용자 고지 시스템
contract UserNotificationSystem {
    struct ProposalNotification {
        uint256 proposalId;
        uint256 effectiveTime;
        string description;
        bool isHighImpact;
    }
    
    mapping(uint256 => ProposalNotification) public notifications;
    mapping(address => mapping(uint256 => bool)) public userAcknowledged;
    
    event ProposalQueued(uint256 indexed proposalId, uint256 effectiveTime);
    event UserNotified(uint256 indexed proposalId, address indexed user);
    
    // 제안이 큐잉될 때 알림 생성
    function notifyProposalQueued(
        uint256 proposalId,
        uint256 effectiveTime,
        string memory description,
        bool isHighImpact
    ) external onlyGovernance {
        notifications[proposalId] = ProposalNotification({
            proposalId: proposalId,
            effectiveTime: effectiveTime,
            description: description,
            isHighImpact: isHighImpact
        });
        
        emit ProposalQueued(proposalId, effectiveTime);
    }
    
    // 사용자가 알림 확인
    function acknowledgeProposal(uint256 proposalId) external {
        userAcknowledged[msg.sender][proposalId] = true;
        emit UserNotified(proposalId, msg.sender);
    }
    
    // 미확인 중요 제안 조회
    function getUnacknowledgedHighImpactProposals(address user) 
        external view returns (uint256[] memory) {
        // 구현 로직
    }
} 
```

