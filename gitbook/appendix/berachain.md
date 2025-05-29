# Berachain 수식 검증

## PoL 관련 수식

### BGT 분배

#### 수식 정보

$$
emission = \left\lfloor B + \max\left(m, (a+1) \left(1 - \frac{1}{1 + ax^b} \right) R \right) \right\rfloor
$$

| 파라미터                            | 설명                                             | 관련 변수 위치                                                       |
| ------------------------------- | ---------------------------------------------- | -------------------------------------------------------------- |
| x (boost)                       | <p>전체 BGT 중 특정 검증자에게 위임된 비율<br>(범위: 0 ~ 1)</p> | <p>boostees[pubkey] / totalBoosts<br>(BGT.sol:L404)</p>        |
| B (base rate)                   | 블록 생성 시 고정 지급되는 BGT                            | <p>baseRate<br>(BlockRewardController.sol:L52)</p>             |
| R (reward rate)                 | 보상 금고에서 할당되는 기본 BGT 양                          | <p>rewardRate<br>(BlockRewardController.sol:L55)</p>           |
| a (boost multipiler)            | BGT 부스트 효과 계수                                  | <p>boostMultiplier<br>(BlockRewardController.sol:L61)</p>      |
| b (convexity parameter)         | BGT 부스트 커브 기울기                                 | <p>rewardConvexity<br>(BlockRewardController.sol:L64)</p>      |
| m (minimum boosted reward rate) | 보상 금고에 대한 최소 보상 한도                             | <p>minBoostedRewardRate<br>(BlockRewardController.sol:L58)</p> |

#### 수식 검증

<details>

<summary> 테스트 코드 정보</summary>

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { FixedPointMathLib } from "solady/src/utils/FixedPointMathLib.sol";
import { IBlockRewardController } from "src/pol/interfaces/IBlockRewardController.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract BlockRewardEmissionTest is Test {
    using FixedPointMathLib for uint256;
    
    // 테스트할 BlockRewardController 주소
    address constant BLOCK_REWARD_CONTROLLER_ADDRESS = 0x43C74F390B2f26e575010Ff8857677c37E8D15c9;
    IBlockRewardController blockRewardController;
    
    // 컨트랙트 변수 최대값
    uint256 constant MAX_BASE_RATE = 5 ether;                   // 최대 기본 비율
    uint256 constant MAX_REWARD_RATE = 5 ether;                 // 최대 리워드 비율
    uint256 constant MAX_MIN_BOOSTED_REWARD_RATE = 10 ether;    // 최대 최소 부스트 비율
    uint256 constant MAX_BOOST_MULTIPLIER = 5 ether;            // 최대 부스트 배율
    uint256 constant MAX_REWARD_CONVEXITY = 1 ether;            // 최대 리워드 볼록성
    
    // 테스트 케이스 구조체
    struct TestCase {
        uint256 baseRate;
        uint256 rewardRate;
        uint256 boostMultiplier;
        int256 rewardConvexity;
        uint256 minBoostedRewardRate;
        uint256 expectedEmission;
        uint256 boost;
        string description;
    }
    
    function setUp() public {
        // 포크 네트워크에서 테스트하는 경우 uncomment
        vm.createSelectFork(vm.rpcUrl("devnet"));
        blockRewardController = IBlockRewardController(BLOCK_REWARD_CONTROLLER_ADDRESS);
    }
    
    function testComputeRewardChangeBoost() public view {
        // 테스트 케이스 설정 - 1% 단위로 변경
        TestCase[] memory testCases = new TestCase[](101);

        // 컨트랙트에서 현재 파라미터 조회
        uint256 baseRate = blockRewardController.baseRate();
        uint256 rewardRate = blockRewardController.rewardRate();
        uint256 boostMultiplier = blockRewardController.boostMultiplier();
        int256 rewardConvexity = blockRewardController.rewardConvexity();
        uint256 minBoostedRewardRate = blockRewardController.minBoostedRewardRate();
        
        // 0%에서 100%까지 1%씩 증가하는 부스트 테스트 케이스 생성
        for (uint i = 0; i <= 100; i++) {
            uint256 boost = i * 0.01 ether;
            string memory description = string(abi.encodePacked(unicode"부스트 ", uint256ToString(i), "%"));
            testCases[i] = TestCase(
                baseRate,          // baseRate
                rewardRate,        // rewardRate
                boostMultiplier,   // boostMultiplier
                rewardConvexity,   // rewardConvexity
                minBoostedRewardRate, // minBoostedRewardRate
                0,                 // expectedEmission (0으로 설정)
                boost,             // boost
                description        // description
            );
        }
        
        console2.log(unicode"=== 부스트 변화에 따른 테스트 ===");
        console2.log(unicode"=== 기본 파라미터 (고정) ===");
        console2.log("baseRate: ", formatEther(baseRate), " ether");
        console2.log("rewardRate: ", formatEther(rewardRate), " ether");
        console2.log("boostMultiplier: ", formatEther(boostMultiplier), " ether");
        console2.log("rewardConvexity: ", formatEtherSigned(rewardConvexity), " ether");
        console2.log("minBoostedRewardRate: ", formatEther(minBoostedRewardRate), " ether");
        
        // 기본 파라미터로 계산 결과 출력 (50% 부스트에서)
        uint256 defaultBoost = 0.5 ether;
        uint256 contractComputeReward = blockRewardController.computeReward(
            defaultBoost,
            rewardRate,
            boostMultiplier,
            rewardConvexity
        );
        uint256 expectedReward = calculateExpectedReward(
            defaultBoost,
            rewardRate,
            boostMultiplier,
            rewardConvexity,
            baseRate
        );
        
        console2.log(unicode"기본 파라미터 (부스트 50%)의 computeReward 결과: ", formatEther(contractComputeReward), " ether");
        console2.log(unicode"기본 파라미터 (부스트 50%)의 calculateExpectedReward 결과: ", formatEther(expectedReward), " ether");
        console2.log("");
        
        console2.log(unicode"=== 독립 변수: boost (0 ~ 1 ether, 0.01 ether 단위) ===");
        console2.log(unicode"---------------------------------------------------------------------------");
        
        // 1% 단위로 모든 데이터 출력
        for (uint i = 0; i < testCases.length; i++) {
            TestCase memory tc = testCases[i];
            
            // 직접 계산 (수식 구현)
            uint256 directCalculation = calculateExpectedReward(
                tc.boost,
                tc.rewardRate,
                tc.boostMultiplier,
                tc.rewardConvexity,
                tc.baseRate
            );
            
            // 컨트랙트 함수를 사용한 계산
            uint256 contractReward = 0;
            if (tc.boost == 0) {
                contractReward = tc.baseRate + tc.minBoostedRewardRate;
            } else {
                uint256 boostedReward = blockRewardController.computeReward(
                    tc.boost,
                    tc.rewardRate,
                    tc.boostMultiplier,
                    tc.rewardConvexity
                );
                contractReward = tc.baseRate + (boostedReward > tc.minBoostedRewardRate ? boostedReward : tc.minBoostedRewardRate);
            }
            
            // 차이 계산 (항상 절대값으로)
            int256 difference;
            if (contractReward >= directCalculation) {
                difference = int256(contractReward - directCalculation);
            } else {
                difference = -int256(directCalculation - contractReward);
            }
            
            // 결과 출력
            string memory output = string(abi.encodePacked(
                formatEther(tc.boost), " | ", 
                formatEther(directCalculation), " | ", 
                formatEther(directCalculation), " | ", 
                formatEther(contractReward), " | ", 
                formatEtherSigned(difference)
            ));
            console2.log(output);
        }
        
        console2.log("");
    }
    
    // Boost 값에 따른 테스트
    function testComputeRewardWithVaryingBoost() public view {
        console2.log(unicode"========================== Boost 값 변화에 따른 테스트 ===========================");
        
        // 컨트랙트에서 현재 파라미터 조회
        uint256 baseRate = blockRewardController.baseRate();
        uint256 rewardRate = blockRewardController.rewardRate();
        uint256 boostMultiplier = blockRewardController.boostMultiplier();
        int256 rewardConvexity = blockRewardController.rewardConvexity();
        uint256 minBoostedRewardRate = blockRewardController.minBoostedRewardRate();
        
        // 현재 컨트랙트 파라미터 출력
        console2.log(unicode"============================== 기본 파라미터 (고정) ==============================");
        console2.log("baseRate: ", formatEther(baseRate), " ether");
        console2.log("rewardRate: ", formatEther(rewardRate), " ether");
        console2.log("boostMultiplier: ", formatEther(boostMultiplier), " ether");
        console2.log("rewardConvexity: ", formatEtherSigned(rewardConvexity), " ether");
        console2.log("minBoostedRewardRate: ", formatEther(minBoostedRewardRate), " ether");
        
        // 기본 파라미터로 계산 결과 출력 (50% 부스트에서)
        uint256 defaultBoost = 0.5 ether;
        uint256 contractComputeReward = blockRewardController.computeReward(
            defaultBoost,
            rewardRate,
            boostMultiplier,
            rewardConvexity
        );
        uint256 expectedReward = calculateExpectedReward(
            defaultBoost,
            rewardRate,
            boostMultiplier,
            rewardConvexity,
            baseRate
        );
        
        console2.log(unicode"기본 파라미터 (부스트 50%)의 computeReward 결과: ", formatEther(contractComputeReward), " ether");
        console2.log(unicode"기본 파라미터 (부스트 50%)의 calculateExpectedReward 결과: ", formatEther(expectedReward), " ether");
        console2.log("");
        
        console2.log(unicode"============== 독립 변수: boostPower (0 ~ 1 ether, 0.01 ether 단위) ==============");
        console2.log(unicode"boostPower  | computeReward | calculateExpected | 차이");
        console2.log(unicode"----------------------------------------------------------------------------------");
        
        // 0%에서 100%까지 1%씩 증가
        for (uint256 i = 0; i <= 100; i++) {
            uint256 boostPower = i * 0.01 ether;
            
            // Compute reward using contract function
            uint256 contractResult = blockRewardController.computeReward(
                boostPower,
                rewardRate,
                boostMultiplier,
                rewardConvexity
            );
            
            // Compute reward using our implementation
            uint256 calculationResult = calculateExpectedReward(
                boostPower,
                rewardRate,
                boostMultiplier,
                rewardConvexity,
                baseRate
            );
            
            // 차이 계산
            int256 difference;
            if (contractResult >= calculationResult) {
                difference = int256(contractResult - calculationResult);
            } else {
                difference = -int256(calculationResult - contractResult);
            }
            
            string memory output = string(abi.encodePacked(
                formatEther(boostPower), " | ", 
                formatEther(contractResult), "   | ", 
                formatEther(calculationResult), "       | ", 
                formatEtherSigned(difference)
            ));
            console2.log(output);
        }
        
        console2.log("");
    }
    
    // 리워드 비율에 따른 테스트
    function testComputeRewardWithVaryingRewardRate() public view {
        console2.log(unicode"=== 리워드 비율 변화에 따른 테스트 ===");
        
        // 컨트랙트에서 현재 파라미터 조회
        uint256 baseRate = blockRewardController.baseRate();
        uint256 rewardRate = blockRewardController.rewardRate();
        uint256 boostMultiplier = blockRewardController.boostMultiplier();
        int256 rewardConvexity = blockRewardController.rewardConvexity();
        uint256 minBoostedRewardRate = blockRewardController.minBoostedRewardRate();
        
        // 고정 파라미터 (boostPower는 1 ether로 고정)
        uint256 boostPower = 1 ether;
        
        // 현재 컨트랙트 파라미터 출력
        console2.log(unicode"=== 기본 파라미터 (고정) ===");
        console2.log("baseRate: ", formatEther(baseRate), " ether");
        console2.log("boostPower: ", formatEther(boostPower), " ether");
        console2.log("boostMultiplier: ", formatEther(boostMultiplier), " ether");
        console2.log("rewardConvexity: ", formatEtherSigned(rewardConvexity), " ether");
        console2.log("minBoostedRewardRate: ", formatEther(minBoostedRewardRate), " ether");
        
        // 기본 파라미터로 계산 결과 출력
        uint256 contractComputeReward = blockRewardController.computeReward(
            boostPower,
            rewardRate,
            boostMultiplier,
            rewardConvexity
        );
        uint256 expectedReward = calculateExpectedReward(
            boostPower,
            rewardRate,
            boostMultiplier,
            rewardConvexity,
            baseRate
        );
        
        console2.log(unicode"기본 파라미터의 computeReward 결과: ", formatEther(contractComputeReward), " ether");
        console2.log(unicode"기본 파라미터의 calculateExpectedReward 결과: ", formatEther(expectedReward), " ether");
        console2.log("");
        
        console2.log(unicode"=== 독립 변수: rewardRate (0 ~ 5 ether, 0.1 ether 단위) ===");
        console2.log(unicode"rewardRate | computeReward | calculateExpected | 차이");
        console2.log(unicode"--------------------------------------------------------");
        
        for (uint256 i = 0; i <= 50; i++) {
            uint256 testRewardRate = i * 0.1 ether;
            
            // Compute reward using contract function
            uint256 contractResult = blockRewardController.computeReward(
                boostPower,
                testRewardRate,
                boostMultiplier,
                rewardConvexity
            );
            
            // Compute reward using our implementation
            uint256 calcResult = calculateExpectedReward(
                boostPower,
                testRewardRate,
                boostMultiplier,
                rewardConvexity,
                baseRate
            );
            
            // 차이 계산
            int256 difference;
            if (contractResult >= calcResult) {
                difference = int256(contractResult - calcResult);
            } else {
                difference = -int256(calcResult - contractResult);
            }
            
            string memory output = string(abi.encodePacked(
                formatEther(testRewardRate), " | ", 
                formatEther(contractResult), " | ", 
                formatEther(calcResult), " | ", 
                formatEtherSigned(difference)
            ));
            console2.log(output);
        }
        console2.log("");
    }
    
    // 부스트 배율에 따른 테스트
    function testComputeRewardWithVaryingBoostMultiplier() public view {
        console2.log(unicode"=== 부스트 배율 변화에 따른 테스트 ===");
        
        // 컨트랙트에서 현재 파라미터 조회
        uint256 baseRate = blockRewardController.baseRate();
        uint256 rewardRate = blockRewardController.rewardRate();
        uint256 boostMultiplier = blockRewardController.boostMultiplier();
        int256 rewardConvexity = blockRewardController.rewardConvexity();
        uint256 minBoostedRewardRate = blockRewardController.minBoostedRewardRate();
        
        // 고정 파라미터 (boostPower는 1 ether로 고정)
        uint256 boostPower = 1 ether;
        
        // 현재 컨트랙트 파라미터 출력
        console2.log(unicode"=== 기본 파라미터 (고정) ===");
        console2.log("baseRate: ", formatEther(baseRate), " ether");
        console2.log("boostPower: ", formatEther(boostPower), " ether");
        console2.log("rewardRate: ", formatEther(rewardRate), " ether");
        console2.log("rewardConvexity: ", formatEtherSigned(rewardConvexity), " ether");
        console2.log("minBoostedRewardRate: ", formatEther(minBoostedRewardRate), " ether");
        
        // 기본 파라미터로 계산 결과 출력
        uint256 contractComputeReward = blockRewardController.computeReward(
            boostPower,
            rewardRate,
            boostMultiplier,
            rewardConvexity
        );
        uint256 calcResult = calculateExpectedReward(
            boostPower,
            rewardRate,
            boostMultiplier,
            rewardConvexity,
            baseRate
        );
        
        console2.log(unicode"기본 파라미터의 computeReward 결과: ", formatEther(contractComputeReward), " ether");
        console2.log(unicode"기본 파라미터의 calculateExpectedReward 결과: ", formatEther(calcResult), " ether");
        console2.log("");
        
        console2.log(unicode"=== 독립 변수: boostMultiplier (0 ~ 5 ether, 0.1 ether 단위) ===");
        console2.log(unicode"boostMultiplier | computeReward | calculateExpected | 차이");
        console2.log(unicode"-----------------------------------------------------------");
        
        for (uint256 i = 0; i <= 50; i++) {
            uint256 testBoostMultiplier = i * 0.1 ether;
            
            // Compute reward using contract function
            uint256 contractResult = blockRewardController.computeReward(
                boostPower,
                rewardRate,
                testBoostMultiplier,
                rewardConvexity
            );
            
            // Compute reward using our implementation
            uint256 multCalcResult = calculateExpectedReward(
                boostPower,
                rewardRate,
                testBoostMultiplier,
                rewardConvexity,
                baseRate
            );
            
            // 차이 계산
            int256 difference;
            if (contractResult >= multCalcResult) {
                difference = int256(contractResult - multCalcResult);
            } else {
                difference = -int256(multCalcResult - contractResult);
            }
            
            string memory output = string(abi.encodePacked(
                formatEther(testBoostMultiplier), " | ", 
                formatEther(contractResult), " | ", 
                formatEther(multCalcResult), " | ", 
                formatEtherSigned(difference)
            ));
            console2.log(output);
        }
        console2.log("");
    }
    
    // 리워드 볼록성에 따른 테스트
    function testComputeRewardWithVaryingRewardConvexity() public view {
        console2.log(unicode"=== 리워드 볼록성 변화에 따른 테스트 ===");
        
        // 컨트랙트에서 현재 파라미터 조회
        uint256 baseRate = blockRewardController.baseRate();
        uint256 rewardRate = blockRewardController.rewardRate();
        uint256 boostMultiplier = blockRewardController.boostMultiplier();
        int256 rewardConvexity = blockRewardController.rewardConvexity();
        uint256 minBoostedRewardRate = blockRewardController.minBoostedRewardRate();
        
        // 고정 파라미터 (boostPower는 0.5 ether로 고정)
        uint256 boostPower = 0.5 ether; // 0.5를 사용하면 convexity 효과가 더 잘 보임
        
        // 현재 컨트랙트 파라미터 출력
        console2.log(unicode"=== 기본 파라미터 (고정) ===");
        console2.log("baseRate: ", formatEther(baseRate), " ether");
        console2.log("boostPower: ", formatEther(boostPower), " ether");
        console2.log("rewardRate: ", formatEther(rewardRate), " ether");
        console2.log("boostMultiplier: ", formatEther(boostMultiplier), " ether");
        console2.log("minBoostedRewardRate: ", formatEther(minBoostedRewardRate), " ether");
        
        // 기본 파라미터로 계산 결과 출력
        uint256 contractComputeReward = blockRewardController.computeReward(
            boostPower,
            rewardRate,
            boostMultiplier,
            rewardConvexity
        );
        uint256 calcResult = calculateExpectedReward(
            boostPower,
            rewardRate,
            boostMultiplier,
            rewardConvexity,
            baseRate
        );
        
        console2.log(unicode"기본 파라미터의 computeReward 결과: ", formatEther(contractComputeReward), " ether");
        console2.log(unicode"기본 파라미터의 calculateExpectedReward 결과: ", formatEther(calcResult), " ether");
        console2.log("");
        
        console2.log(unicode"=== 독립 변수: rewardConvexity (0.1 ~ 1 ether, 0.1 ether 단위) ===");
        console2.log(unicode"rewardConvexity | computeReward | calculateExpected | 차이");
        console2.log(unicode"-----------------------------------------------------------");
        
        for (uint256 i = 1; i <= 10; i++) { // 0.1부터 시작 (0은 컨트랙트에서 허용 안함)
            uint256 testRewardConvexity = i * 0.1 ether;
            int256 testRewardConvexitySigned = int256(testRewardConvexity);
            
            // Compute reward using contract function
            uint256 contractResult = blockRewardController.computeReward(
                boostPower,
                rewardRate,
                boostMultiplier,
                testRewardConvexitySigned
            );
            
            // Compute reward using our implementation
            uint256 convexityCalcResult = calculateExpectedReward(
                boostPower,
                rewardRate,
                boostMultiplier,
                testRewardConvexitySigned,
                baseRate
            );
            
            // 차이 계산
            int256 difference;
            if (contractResult >= convexityCalcResult) {
                difference = int256(contractResult - convexityCalcResult);
            } else {
                difference = -int256(convexityCalcResult - contractResult);
            }
            
            string memory output = string(abi.encodePacked(
                formatEther(testRewardConvexity), " | ", 
                formatEther(contractResult), " | ", 
                formatEther(convexityCalcResult), " | ", 
                formatEtherSigned(difference)
            ));
            console2.log(output);
        }
        console2.log("");
    }
    
    // 모든 변수를 동시에 점진적으로 증가시키는 테스트
    function testComputeRewardWithGradualIncreases() public view {
        console2.log(unicode"=== 모든 변수 점진적 증가 테스트 ===");
        
        // 초기값 설정
        uint256 initialBaseRate = 0.1 ether;                    // 0.1 BGT
        uint256 initialRewardRate = 0.1 ether;                 // 0.1 BGT
        uint256 initialBoostMultiplier = 0.1 ether;            // 0.1x
        int256 initialRewardConvexity = 0.1 ether;             // 0.1
        uint256 initialBoost = 0.1 ether;                      // 10% 부스트
        
        // 최종값 설정
        uint256 finalBaseRate = MAX_BASE_RATE;                 // 5 BGT
        uint256 finalRewardRate = MAX_REWARD_RATE;             // 5 BGT
        uint256 finalBoostMultiplier = MAX_BOOST_MULTIPLIER;   // 5x
        int256 finalRewardConvexity = int256(MAX_REWARD_CONVEXITY);    // 1
        uint256 finalBoost = 1 ether;                          // 100% 부스트
        
        // 단계 수
        uint256 steps = 20;
        
        console2.log(unicode"=== 초기값 ===");
        console2.log("baseRate: ", formatEther(initialBaseRate), " ether");
        console2.log("rewardRate: ", formatEther(initialRewardRate), " ether");
        console2.log("boostMultiplier: ", formatEther(initialBoostMultiplier), " ether");
        console2.log("rewardConvexity: ", formatEtherSigned(initialRewardConvexity), " ether");
        console2.log("boost: ", formatEther(initialBoost), " ether");
        
        console2.log(unicode"\n=== 최종값 ===");
        console2.log("baseRate: ", formatEther(finalBaseRate), " ether");
        console2.log("rewardRate: ", formatEther(finalRewardRate), " ether");
        console2.log("boostMultiplier: ", formatEther(finalBoostMultiplier), " ether");
        console2.log("rewardConvexity: ", formatEtherSigned(finalRewardConvexity), " ether");
        console2.log("boost: ", formatEther(finalBoost), " ether");
        
        console2.log(unicode"\n=== 단계별 결과 ===");
        console2.log(unicode"단계 | baseRate | rewardRate | boostMultiplier | rewardConvexity | boost | 컨트랙트계산 | 직접계산 | 차이");
        console2.log(unicode"--------------------------------------------------------------------------------------------------------");
        
        // 각 단계별 계산
        for (uint256 i = 0; i <= steps; i++) {
            // 현재 단계의 값 계산
            uint256 currentBaseRate = initialBaseRate + ((finalBaseRate - initialBaseRate) * i) / steps;
            uint256 currentRewardRate = initialRewardRate + ((finalRewardRate - initialRewardRate) * i) / steps;
            uint256 currentBoostMultiplier = initialBoostMultiplier + ((finalBoostMultiplier - initialBoostMultiplier) * i) / steps;
            int256 currentRewardConvexity = initialRewardConvexity + ((finalRewardConvexity - initialRewardConvexity) * int256(i)) / int256(steps);
            uint256 currentBoost = initialBoost + ((finalBoost - initialBoost) * i) / steps;
            
            // 컨트랙트 함수를 사용한 계산
            uint256 contractReward = 0;
            if (currentBoost == 0) {
                contractReward = 0;  // baseRate 제거
            } else {
                contractReward = blockRewardController.computeReward(
                    currentBoost,
                    currentRewardRate,
                    currentBoostMultiplier,
                    currentRewardConvexity
                );
            }
            
            // 직접 계산
            uint256 directCalculation = calculateExpectedReward(
                currentBoost,
                currentRewardRate,
                currentBoostMultiplier,
                currentRewardConvexity,
                currentBaseRate
            );
            
            // 차이 계산
            int256 difference;
            if (contractReward >= directCalculation) {
                difference = int256(contractReward - directCalculation);
            } else {
                difference = -int256(directCalculation - contractReward);
            }
            
            // 결과 출력
            string memory output = string(abi.encodePacked(
                vm.toString(i), " | ",
                formatEther(currentBaseRate), " | ",
                formatEther(currentRewardRate), " | ",
                formatEther(currentBoostMultiplier), " | ",
                formatEtherSigned(currentRewardConvexity), " | ",
                formatEther(currentBoost), " | ",
                formatEther(contractReward), " | ",
                formatEther(directCalculation), " | ",
                formatEtherSigned(difference)
            ));
            console2.log(output);
            
            // 이전 단계와 비교 (i > 0인 경우)
            if (i > 0) {
                uint256 prevBaseRate = initialBaseRate + ((finalBaseRate - initialBaseRate) * (i-1)) / steps;
                uint256 prevRewardRate = initialRewardRate + ((finalRewardRate - initialRewardRate) * (i-1)) / steps;
                uint256 prevBoostMultiplier = initialBoostMultiplier + ((finalBoostMultiplier - initialBoostMultiplier) * (i-1)) / steps;
                int256 prevRewardConvexity = initialRewardConvexity + ((finalRewardConvexity - initialRewardConvexity) * int256(i-1)) / int256(steps);
                uint256 prevBoost = initialBoost + ((finalBoost - initialBoost) * (i-1)) / steps;
                
                uint256 prevContractReward = 0;
                if (prevBoost == 0) {
                    prevContractReward = 0;  // baseRate 제거
                } else {
                    prevContractReward = blockRewardController.computeReward(
                        prevBoost,
                        prevRewardRate,
                        prevBoostMultiplier,
                        prevRewardConvexity
                    );
                }
                
                // 모든 변수가 증가할 때 보상도 증가하는지 확인
                assertGe(contractReward, prevContractReward, "Reward should increase with increasing parameters");
            }
        }
    }
    
    // 문서 수식에 기반한 예상 보상 계산 - emission = [B + (a+1)(1−1/(1+axb))R]
    function calculateExpectedReward(
        uint256 boost, 
        uint256 _rewardRate,
        uint256 _boostMultiplier,
        int256 _rewardConvexity,
        uint256 _baseRate
    ) internal pure returns (uint256) {
        if (boost == 0) {
            return 0;
        }
        
        uint256 one = FixedPointMathLib.WAD;

        if (boost == one) {
            return FixedPointMathLib.mulWad(_rewardRate, _boostMultiplier);
        } else {
            uint256 tmp_0 = uint256(FixedPointMathLib.powWad(int256(boost), _rewardConvexity));
            uint256 tmp_1 = one + FixedPointMathLib.mulWad(_boostMultiplier, tmp_0);
            uint256 tmp_2 = one - FixedPointMathLib.divWad(one, tmp_1);
            uint256 coeff = FixedPointMathLib.mulWad(tmp_2, one + _boostMultiplier);
            if (coeff > _boostMultiplier) coeff = _boostMultiplier;
            return FixedPointMathLib.mulWad(_rewardRate, coeff);
        }
    }
    
    function isApproximatelyEqual(uint256 a, uint256 b, uint256 tolerance) internal pure returns (bool) {
        if (a > b) {
            // mulDiv 대신 곱셈과 나눗셈 직접 사용
            return a - b <= (a * tolerance) / 1e18;
        } else {
            return b - a <= (b * tolerance) / 1e18;
        }
    }
    
    // 이더 단위로 소수점 형식화 함수 (9자리 정밀도로 표시)
    function formatEther(uint256 value) internal pure returns (string memory) {
        // 정수 부분
        uint256 integerPart = value / 1e18;
        
        // 소수 부분 (소수점 9자리까지만 표시)
        uint256 fractionalPart = (value % 1e18) / 1e9;
        
        // fractionalPart가 0일 경우 "0"으로 표시
        string memory fractionalStr = uint256ToString(fractionalPart);
        
        // 필요한 만큼 앞에 0 추가
        while (bytes(fractionalStr).length < 9) {
            fractionalStr = string(abi.encodePacked("0", fractionalStr));
        }
        
        return string(abi.encodePacked(uint256ToString(integerPart), ".", fractionalStr));
    }
    
    // int256 타입을 위한 이더 단위 형식화 함수 (9자리 정밀도로 표시)
    function formatEtherSigned(int256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0.000000000";
        }
        
        bool isNegative = value < 0;
        
        // 절대값으로 변환 (음수 최대값 주의)
        uint256 absValue;
        if (value == type(int256).min) {
            absValue = uint256(type(int256).max) + 1;
        } else {
            absValue = isNegative ? uint256(-value) : uint256(value);
        }
        
        // 기존 formatEther 함수를 활용
        string memory formattedValue = formatEther(absValue);
        
        // 음수 부호 추가
        if (isNegative) {
            return string(abi.encodePacked("-", formattedValue));
        }
        
        return formattedValue;
    }
    
    // 숫자를 문자열로 변환
    function uint256ToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        
        uint256 temp = value;
        uint256 digits;
        
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        
        bytes memory buffer = new bytes(digits);
        
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + value % 10));
            value /= 10;
        }
        
        return string(buffer);
    }
}
```

</details>

>
>
> ```
> 테스트 결과
> ```

### APR

#### 수식 정보

$$
\text{APR} = \frac{\textit{rewardRate} \times \textit{secondsPerYear} \times \textit{priceOfBGT}}{\textit{totalSupply} \times \textit{priceOfStakeToken}}
$$



#### 수식 검증

<details>

<summary>ㅅ</summary>



</details>

## dApp 관련 수식

### Lending



### DEX



### LSD



