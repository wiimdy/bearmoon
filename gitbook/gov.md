---
icon: square-poll-vertical
---

# PoL 보안 가이드라인: 거버넌스



### 위협1: 악성 컴포넌트 승인 <a href="#ec-9c-84-ed-98-911-ec-95-85-ec-84-b1-ec-bb-b4-ed-8f-ac-eb-84-8c-ed-8a-b8-ec-8a-b9-ec-9d-b8" id="ec-9c-84-ed-98-911-ec-95-85-ec-84-b1-ec-bb-b4-ed-8f-ac-eb-84-8c-ed-8a-b8-ec-8a-b9-ec-9d-b8"></a>

거버넌스를 통해 악의적인 보상 금고나 인센티브 토큰이 승인될 위험이 존재. 이를 통해 공격자가 자금을 탈취하거나 시스템 안정성을 해칠 수 있다.

#### 가이드라인

> * **보상 금고 및 인센티브 토큰 제안에 대해 기술적 검토, 경제적 영향 분석, 보안 감사를 포함한 다층적 검증 프로세스를 의무화하고, 각 단계별로 독립적인 검토자 그룹을 배정.**
> * **사전에 검증된 컨트랙트 템플릿이나 표준을 기반으로 한 제안만 허용하고, 새로운 형태의 컴포넌트는 추가적인 보안 감사와 테스트넷 검증을 거치도록 함.**
> * **새로운 컴포넌트는 제한된 규모로 시작하여 점진적으로 확장하는 방식으로 배포하여 잠재적 피해를 최소화.**

#### Best Practice

```solidity
contract ComponentValidator {
    mapping(address => ComponentStatus) public componentStatus;
    mapping(address => uint256) public maxAllocation;
    
    enum ComponentStatus { PENDING, APPROVED, REJECTED, DEPRECATED }
    
    struct ValidationRequirement {
        bool securityAudit;
        bool economicReview;
        bool technicalReview;
        uint256 testnetDuration;
    }
    
    function validateComponent(
        address component,
        ValidationRequirement memory requirements
    ) external onlyValidator {
        require(requirements.securityAudit, "Security audit required");
        require(requirements.economicReview, "Economic review required");
        require(requirements.technicalReview, "Technical review required");
        require(requirements.testnetDuration >= 30 days, "Insufficient testnet period");
        
        componentStatus[component] = ComponentStatus.APPROVED;
        maxAllocation[component] = getInitialAllocation(); // 초기 제한된 할당
    }
}
```

***

### 위협2: 사익 충돌로 인한 거절 <a href="#ec-9c-84-ed-98-911-ec-95-85-ec-84-b1-ec-bb-b4-ed-8f-ac-eb-84-8c-ed-8a-b8-ec-8a-b9-ec-9d-b8" id="ec-9c-84-ed-98-911-ec-95-85-ec-84-b1-ec-bb-b4-ed-8f-ac-eb-84-8c-ed-8a-b8-ec-8a-b9-ec-9d-b8"></a>

재단이나 가디언즈가 자신에게 불리한 제안을 거부하여 거버넌스가 공정하게 작동하지 않고 중앙화될 우려가 있다. 이는 커뮤니티의 정당한 의사결정을 방해하고 시스템의 탈중앙화를 훼손할 수 있다.

#### 가이드라인

> * **모든 제안 거부 시 구체적이고 객관적인 사유를 공개하고 커뮤니티가 이에 대해 이의제기할 수 있는 메커니즘 제공.**
> * **재단이나 가디언즈의 결정에 대해 독립적으로 검토할 수 있는 중재 위원회를 구성하여 견제와 균형 확보.**
> * **거버넌스 참여자들의 이해관계를 투명하게 공개하고 직접적인 이해관계가 있는 제안에 대해서는 투표 참여를 제한.**

#### Best Practice

```solidity
// Some code
contract TransparentGovernance {
    struct Proposal {
        bytes32 id;
        address proposer;
        string description;
        uint256 votingDeadline;
        ProposalStatus status;
    }
    
    struct RejectionRecord {
        bytes32 proposalId;
        address rejector;
        string reason;
        uint256 timestamp;
        bool appealed;
    }
    
    mapping(bytes32 => RejectionRecord) public rejections;
    mapping(address => mapping(bytes32 => bool)) public conflictOfInterest;
    
    event ProposalRejected(bytes32 indexed proposalId, address rejector, string reason);
    event AppealSubmitted(bytes32 indexed proposalId, address appellant);
    
    function rejectProposal(
        bytes32 proposalId, 
        string memory reason
    ) external onlyGuardian {
        require(bytes(reason).length > 0, "Rejection reason required");
        
        rejections[proposalId] = RejectionRecord({
            proposalId: proposalId,
            rejector: msg.sender,
            reason: reason,
            timestamp: block.timestamp,
            appealed: false
        });
        
        emit ProposalRejected(proposalId, msg.sender, reason);
    }
    
    function submitAppeal(bytes32 proposalId) external {
        require(rejections[proposalId].timestamp != 0, "Proposal not rejected");
        require(!rejections[proposalId].appealed, "Already appealed");
        
        rejections[proposalId].appealed = true;
        emit AppealSubmitted(proposalId, msg.sender);
    }
}
```

***

### 위협3: On-chain Governance 로직 미구현 제한 <a href="#ec-9c-84-ed-98-911-ec-95-85-ec-84-b1-ec-bb-b4-ed-8f-ac-eb-84-8c-ed-8a-b8-ec-8a-b9-ec-9d-b8" id="ec-9c-84-ed-98-911-ec-95-85-ec-84-b1-ec-bb-b4-ed-8f-ac-eb-84-8c-ed-8a-b8-ec-8a-b9-ec-9d-b8"></a>

거버넌스가 아직 On-chain에 구현되지 않아 forum 기반 투표로 운영되며, 이로 인해 투표율(20%) 충족이 어렵고 의사결정 과정이 비효율적이거나 조작 가능할 수 있다.

#### 가이드라인

> * **On-chain 구현 전까지 forum 투표와 snapshot 등을 결합한 하이브리드 시스템으로 투표의 투명성과 검증 가능성 확보.**
> * **거버넌스 참여에 대한 적절한 인센티브를 제공하여 투표율을 높여야함.**
> * **시빌 공격을 통해 포럼의 여론을 조작하려는 행위를 방지하는 메커니즘 도입.**

#### Best Practice

```solidity
// Some code
contract HybridGovernance {
    struct Vote {
        address voter;
        uint256 weight;
        bool support;
        uint256 timestamp;
        bytes32 offChainProof; // IPFS hash 등
    }
    
    mapping(bytes32 => mapping(address => Vote)) public votes;
    mapping(bytes32 => uint256) public totalVotes;
    mapping(bytes32 => uint256) public supportVotes;
    
    uint256 public constant QUORUM_THRESHOLD = 20e16; // 20%
    uint256 public constant VOTING_PERIOD = 7 days;
    
    event VoteCast(bytes32 indexed proposalId, address voter, bool support, uint256 weight);
    
    function castVote(
        bytes32 proposalId,
        bool support,
        bytes32 offChainProof
    ) external {
        require(getBGTBalance(msg.sender) >= 10000e18, "Insufficient BGT");
        require(votes[proposalId][msg.sender].timestamp == 0, "Already voted");
        
        uint256 weight = getBGTBalance(msg.sender);
        
        votes[proposalId][msg.sender] = Vote({
            voter: msg.sender,
            weight: weight,
            support: support,
            timestamp: block.timestamp,
            offChainProof: offChainProof
        });
        
        totalVotes[proposalId] += weight;
        if (support) {
            supportVotes[proposalId] += weight;
        }
        
        emit VoteCast(proposalId, msg.sender, support, weight);
    }
    
    function checkQuorum(bytes32 proposalId) external view returns (bool) {
        uint256 totalBGT = getTotalBGTSupply();
        return totalVotes[proposalId] >= (totalBGT * QUORUM_THRESHOLD) / 1e18;
    }
}
```

***

### 위협4: 재단 후원 기반 Validator로 인한 중앙화 우려 <a href="#ec-9c-84-ed-98-914-ec-9e-ac-eb-8b-a8-ed-9b-84-ec-9b-90-ea-b8-b0-eb-b0-98-validator-eb-a1-9c-ec-9d-b8" id="ec-9c-84-ed-98-914-ec-9e-ac-eb-8b-a8-ed-9b-84-ec-9b-90-ea-b8-b0-eb-b0-98-validator-eb-a1-9c-ec-9d-b8"></a>

validator의 자산이 재단 물량일 경우 validator가 재단에 종속받는 구조가 되므로 거버넌스 투표가 재단에 의해 중앙화될 우려가 있다.

#### 가이드라인

> * **Validator 운영에 필요한 자산의 출처를 다양화하고, 재단 의존도를 점진적으로 줄이는 계획 수립.**
> * **각 validator의 운영 주체, 재단과의 관계를 투명하게 공개하여 커뮤니티가 정보에 기반한 선택을 할 수 있도록 함.**
> * **재단으로부터 물량을 받은 경우 비율을 공개하여 중앙화 우려를 해소해야함.**

#### Best Practice

```solidity
// Some code
contract ValidatorIndependence {
    struct ValidatorInfo {
        address validator;
        uint256 foundationStake;
        uint256 communityStake;
        uint256 independenceScore;
        bool isActive;
    }
    
    mapping(address => ValidatorInfo) public validators;
    uint256 public constant MAX_FOUNDATION_RATIO = 30e16; // 30%
    
    event ValidatorRegistered(address validator, uint256 independenceScore);
    event IndependenceScoreUpdated(address validator, uint256 newScore);
    
    function registerValidator(
        address validator,
        uint256 foundationStake,
        uint256 communityStake
    ) external onlyGovernance {
        uint256 totalStake = foundationStake + communityStake;
        require(totalStake > 0, "Invalid stake amounts");
        
        uint256 foundationRatio = (foundationStake * 1e18) / totalStake;
        require(foundationRatio <= MAX_FOUNDATION_RATIO, "Excessive foundation dependency");
        
        uint256 independenceScore = calculateIndependenceScore(foundationStake, communityStake);
        
        validators[validator] = ValidatorInfo({
            validator: validator,
            foundationStake: foundationStake,
            communityStake: communityStake,
            independenceScore: independenceScore,
            isActive: true
        });
        
        emit ValidatorRegistered(validator, independenceScore);
    }
    
    function calculateIndependenceScore(
        uint256 foundationStake,
        uint256 communityStake
    ) internal pure returns (uint256) {
        uint256 totalStake = foundationStake + communityStake;
        uint256 communityRatio = (communityStake * 1e18) / totalStake;
        return communityRatio; // 커뮤니티 스테이크 비율이 독립성 점수
    }
}
```

***

### 위협5: BGT 독점에 의한 Governance 조작 <a href="#ec-9c-84-ed-98-915-bgt-eb-8f-85-ec-a0-90-ec-97-90-ec-9d-98-ed-95-9c-governance-ec-a1-b0-ec-9e-91" id="ec-9c-84-ed-98-915-bgt-eb-8f-85-ec-a0-90-ec-97-90-ec-9d-98-ed-95-9c-governance-ec-a1-b0-ec-9e-91"></a>

대규모 프로토콜이 사용자를 독점할 경우 전체 BGT 중 20% 이상을 얻을 수 있고, 하나의 프로토콜이 BGT를 대량 보유할 경우 투표를 조작하여 프로토콜에 유리한 정책을 강제할 수 있다.

#### 가이드라인

> * **단일 엔티티나 프로토콜이 전체 BGT의 일정 비율(예: 15%) 이상을 보유할 때 경고 메커니즘 도입**
> * **특정 비율을 넘어간 BGT에 대해서 선형적인 투표권 대신 영향력이 감소하는 투표권(예: 제곱근 기반의 보팅)을 도입하여 대량 보유자의 영향력을 제한.**
> * **BGT 분산을 촉진하는 인센티브 구조를 설계하고, 집중도가 높은 경우 추가적인 제약을 가하는 시스템 구축.**

#### Best Practice

```solidity
contract QuadraticGovernance {
    mapping(address => uint256) public bgtBalance;
    mapping(bytes32 => mapping(address => uint256)) public quadraticVotes;
    
    uint256 public constant MAX_CONCENTRATION = 15e16; // 15%
    uint256 public constant CONCENTRATION_PENALTY = 50e16; // 50% 페널티
    
    event ConcentrationAlert(address entity, uint256 concentration);
    event QuadraticVoteCast(bytes32 proposalId, address voter, uint256 quadraticWeight);
    
    function calculateQuadraticWeight(uint256 bgtAmount) public pure returns (uint256) {
        // 제곱근 기반 투표권 계산
        return sqrt(bgtAmount);
    }
    
    function castQuadraticVote(bytes32 proposalId, bool support) external {
        uint256 bgtAmount = getBGTBalance(msg.sender);
        require(bgtAmount >= 10000e18, "Insufficient BGT");
        
        uint256 quadraticWeight = calculateQuadraticWeight(bgtAmount);
        
        // 집중도가 높은 경우 페널티 적용
        uint256 concentration = getConcentration(msg.sender);
        if (concentration > MAX_CONCENTRATION) {
            quadraticWeight = (quadraticWeight * (1e18 - CONCENTRATION_PENALTY)) / 1e18;
            emit ConcentrationAlert(msg.sender, concentration);
        }
        
        quadraticVotes[proposalId][msg.sender] = quadraticWeight;
        emit QuadraticVoteCast(proposalId, msg.sender, quadraticWeight);
    }
    
    function getConcentration(address entity) public view returns (uint256) {
        uint256 entityBGT = getBGTBalance(entity);
        uint256 totalBGT = getTotalBGTSupply();
        return (entityBGT * 1e18) / totalBGT;
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

***

### 위협6: 거버넌스 제안 검증 미흡 <a href="#ec-9c-84-ed-98-916-ea-b1-b0-eb-b2-84-eb-84-8c-ec-8a-a4-ec-a0-9c-ec-95-88-ea-b2-80-ec-a6-9d-eb-af-b8" id="ec-9c-84-ed-98-916-ea-b1-b0-eb-b2-84-eb-84-8c-ec-8a-a4-ec-a0-9c-ec-95-88-ea-b2-80-ec-a6-9d-eb-af-b8"></a>

악의적인 코드 변경이나 시스템에 해로운 매개변수 변경을 포함한 제안이 충분한 검토 없이 통과하여 시스템 전체에 심각한 피해를 초래할 수 있다.

#### 가이드라인

> * **보상 금고 및 인센티브 토큰 제안에 대해 기술적 검토, 경제적 영향 분석, 보안 감사를 포함한 다층적 검증 프로세스를 의무화.**
> * **검증 프로세스의 각 단계별로 독립적인 검토자 그룹을 배정.**
> * **가디언즈에게 제안이 넘어갈 때 사전에 검증된 컨트랙트 템플릿이나 표준을 기반으로 한 제안만 허용하고 새로운 형태의 컴포넌트는 추가적인 보안 감사와 테스트넷 검증을 거치도록 함.**
> * **단계적 배포: 새로운 컴포넌트는 제한된 규모로 시작하여 점진적으로 확장하는 방식으로 배포하여 잠재적 피해를 최소화.**

#### Best Practice

```solidity
contract ProposalValidator {
    struct ProposalReview {
        bytes32 proposalId;
        bool codeAudit;
        bool parameterReview;
        bool economicImpact;
        uint256 riskScore;
        uint256 reviewDeadline;
        address[] reviewers;
    }
    
    mapping(bytes32 => ProposalReview) public reviews;
    mapping(bytes32 => bool) public emergencyPaused;
    
    uint256 public constant MIN_REVIEW_PERIOD = 7 days;
    uint256 public constant HIGH_RISK_THRESHOLD = 80;
    
    event ProposalSubmitted(bytes32 indexed proposalId, uint256 reviewDeadline);
    event EmergencyPause(bytes32 indexed proposalId, address guardian);
    event ReviewCompleted(bytes32 indexed proposalId, uint256 riskScore);
    
    modifier requiresReview(bytes32 proposalId) {
        ProposalReview memory review = reviews[proposalId];
        require(review.codeAudit && review.parameterReview && review.economicImpact, "Incomplete review");
        require(block.timestamp >= review.reviewDeadline, "Review period not completed");
        require(!emergencyPaused[proposalId], "Proposal emergency paused");
        _;
    }
    
    function submitProposal(
        bytes32 proposalId,
        bytes memory code,
        uint256[] memory parameters
    ) external {
        uint256 reviewDeadline = block.timestamp + MIN_REVIEW_PERIOD;
        
        reviews[proposalId] = ProposalReview({
            proposalId: proposalId,
            codeAudit: false,
            parameterReview: false,
            economicImpact: false,
            riskScore: 0,
            reviewDeadline: reviewDeadline,
            reviewers: new address[](0)
        });
        
        // 자동 위험 분석 시작
        uint256 autoRiskScore = analyzeRisk(code, parameters);
        if (autoRiskScore > HIGH_RISK_THRESHOLD) {
            reviews[proposalId].reviewDeadline += 7 days; // 고위험 제안은 추가 검토 기간
        }
        
        emit ProposalSubmitted(proposalId, reviewDeadline);
    }
    
    function emergencyPauseProposal(bytes32 proposalId) external onlyGuardian {
        emergencyPaused[proposalId] = true;
        emit EmergencyPause(proposalId, msg.sender);
    }
    
    function completeReview(
        bytes32 proposalId,
        bool codeAudit,
        bool parameterReview,
        bool economicImpact,
        uint256 riskScore
    ) external onlyReviewer {
        ProposalReview storage review = reviews[proposalId];
        review.codeAudit = codeAudit;
        review.parameterReview = parameterReview;
        review.economicImpact = economicImpact;
        review.riskScore = riskScore;
        
        emit ReviewCompleted(proposalId, riskScore);
    }
    
    function analyzeRisk(
        bytes memory code,
        uint256[] memory parameters
    ) internal pure returns (uint256 riskScore) {
        // 자동화된 위험 분석 로직
        // 예: 코드 복잡도, 매개변수 변경 범위, 영향받는 함수 수 등을 분석
        riskScore = 50; // 기본 위험도
        
        // 코드 분석
        if (code.length > 10000) riskScore += 20; // 큰 코드 변경
        
        // 매개변수 분석
        for (uint i = 0; i < parameters.length; i++) {
            if (parameters[i] > 1e20) riskScore += 10; // 큰 매개변수 변경
        }
        
        return riskScore > 100 ? 100 : riskScore;
    }
}
```

***

### 위협7: 사용자 고지 부족으로 인한 신뢰도 저하 및 예상치 못한 피해 <a href="#ec-9c-84-ed-98-917-ec-82-ac-ec-9a-a9-ec-9e-90-ea-b3-a0-ec-a7-80-eb-b6-80-ec-a1-b1-ec-9c-bc-eb-a1-9c" id="ec-9c-84-ed-98-917-ec-82-ac-ec-9a-a9-ec-9e-90-ea-b3-a0-ec-a7-80-eb-b6-80-ec-a1-b1-ec-9c-bc-eb-a1-9c"></a>

거버넌스 제안이 통과되어 시스템 변경이 이루어질 때 사용자들에게 충분한 사전 고지가 없을 경우에 사용자들이 변경사항을 인지하지 못해 예상치 못한 손실을 입거나 시스템에 대한 신뢰도가 저하될 수 있다. 특히 수수료 변경, 토큰 경제학 수정, 새로운 제약사항 도입 등은 사용자의 투자 전략과 자산 관리에 직접적인 영향을 미칠 수 있다.

#### 가이드라인

> * **다단계 공지 시스템: 거버넌스 제안 통과 후 실제 적용까지 최소 14일의 공지 기간을 두고, 제안 통과 즉시, 적용 7일 전, 적용 1일 전 총 3차례에 걸쳐 다양한 채널(공식 웹사이트, 소셜미디어, 이메일, 인앱 알림)을 통해 변경사항을 공지.**
> * **영향도별 차등 공지: 사용자 자산에 직접적인 영향을 미치는 변경사항(수수료, 이자율, 청산 임계값 등)은 더 긴 공지 기간(최소 30일)과 더 상세한 설명을 제공하고, 사용자가 대응할 수 있는 충분한 시간 확보.**
> * **사용자 맞춤형 알림: 각 사용자의 포지션과 사용 패턴을 분석하여 해당 변경사항이 개별 사용자에게 미칠 구체적인 영향을 계산하고 개인화된 알림 제공.**
> * **변경사항 시뮬레이션 도구: 사용자가 변경사항이 자신의 포지션에 미칠 영향을 미리 확인할 수 있는 시뮬레이션 도구를 제공하여 사전 대응 가능.**

#### Best Practice

```
// Some code
```

***



