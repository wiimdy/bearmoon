---
icon: sack-dollar
---

# PoL 보안 가이드라인: 보상 분배

T-7. | 위협 |&#x20;

권한 없는 사용자의 Incentive token 조작 및 사용

\| 가이드라인 |

1\. incentive token whitelist 관리 시 maxIncentiveTokensCount 제한 및 중복 등록 방지

2\. incentive rate 설정 시 MIN/MAX 범위 검증 및 manager 권한 제한

3\. ERC20 토큰 회수 시 incentive token 및 staked token을 제외하고 전송

4\. reward vault별 incentive 분배 한도 설정

\| Best Practice |

contracts/src/pol/rewards/RewardVault.sol

* whitelistedTokens.length == maxIncentiveTokensCount 제한 체크
* MAX\_INCENTIVE\_RATE 상한선 설정
* recoverERC20에서 incentive token과 staked token 회수 방지



T-8. | 위협 |&#x20;

컨트랙트 초기화 시 잘못된 구성으로 인한 시스템 오류&#x20;

\| 가이드라인 |

1\. 모든 컨트랙트 초기화 시 zero address 검증 및 필수 매개변수 검증

2\. 초기 설정 매개변수들의 합리적 범위 검증

3\. genesis deposits root 설정 등 초기 상태의 무결성 보장

4\. 초기화 함수의 멱등성 보장 및 재초기화 방지 메커니즘

5\. critical parameter 변경을 위한 rollback 메커니즘

\| Best Practice |

contracts/src/pol/rewards/BlockRewardController.sol

* initialize에서 모든 주소 매개변수 설정 검증

contracts/src/pol/BGT.sol

* initialize에서 boost delay를 BOOST\_MAX\_BLOCK\_DELAY로 설정

contracts/src/pol/BeaconDeposit.sol

* genesisDepositsRoot 설정으로 초기 상태 정의

\


T-9. | 위협 |&#x20;

BGT redeem 시 Native token 부족으로 인한 유동성 위기

\| 가이드라인 |

1\. BGT redeem 시 컨트랙트 잔액 검증 및 충분한 native token 보유량 확보

2\. burnExceedingReserves 함수를 통한 초과 reserves 관리 및 적절한 버퍼 유지

3\. BGT 예상 발행량 계산 시 블록 버퍼 크기와 블록당 BGT 발행량 등 고려한 정확한 예상량 산출

\| Best Practice |

contracts/src/pol/BGT.sol

* redeem 함수에서 checkUnboostedBalance modifier로 사용자 잔액 검증
* burnExceedingReserves에서 현재 reserves와 outstanding amount 비교
* HISTORY\_BUFFER\_LENGTH \* br.getMaxBGTPerBlock()로 잠재적 민팅량 계산
* invariantCheck modifier를 통한 컨트랙트 상태 일관성 검증

\


T-10. | 위협 |&#x20;

보상 분배 로직 오류로 인한 특정 사용자에게 과도한 보상 지급 또는 보상 누락&#x20;

\


\| 가이드라인 |&#x20;

1\. 95% 코드 커버리지, Fuzz 테스트, 100명 이상 사용자 시뮬레이션 등 구체적 수치 제시

2\. Python/JavaScript 기반 오프체인 검증 시스템 구현 방안

\


\| Best Practice |&#x20;

contracts/src/pol/rewards/StakingRewards.sol:\_notifyRewardAmount&#x20;

보상이 추가 될 경우 rewardRate 계산

\


T-11. | 위협 |&#x20;

잘못된 접근 제어로 인한 권한 없는 보상 인출 또는 조작

\| 가이드라인 |&#x20;

1\. 각 함수 및 중요 데이터에 대해 명확한 역할(Owner, Admin, User 등)을 정의, 역할에 따른 접근 권한을 엄격히 부여

2\. onlyOwner, onlyRole 등의 modifier를 명확히 사용&#x20;

3\. 관리자 활동(권한 변경, 중요 함수 호출 등)에 대한 이벤트 로깅

\
\


\| Best Practice |&#x20;

contracts/src/pol/rewards/StakingRewards.sol:addIncentive

* incentive rate 변동은 manager 권한만 가능

contracts/src/pol/rewards/RewardVault.sol:getReward

* reward 수령은 사용자 혹은 사용자가 설정한 operator만 실행 가능

\


T-12. | 위협 |&#x20;

재진입(Re-entrancy) 공격을 통해 보상 중복 청구

\| 가이드라인 |&#x20;

1\. 체크-효과-상호작용(Checks-Effects-Interactions) 패턴을 준수

2\. nonReentrant 가드 사용.

\
\


\| Best Practice |&#x20;

contracts/src/pol/rewards/RewardVault.sol:getReward

* nonReentrant 가드 사용
* unclaimed된 보상을 초기화 하고 trasnfer 진행

\


T-13. | 위협 |

Operator들이 담합하여 특정 reward vault에만 BGT 보상을 집중, 유동성 쏠림 및 타 프로토콜 유동성 고갈

\| 가이드라인 |&#x20;

1\. 여러 종류  Reward vault에게 나눠 주도록 강제(실제 Berachain 정책 반영)

2\. Operator/Validator reward allocation 변경 시 투명한 로그 기록 및 모니터링

3\. 담합 의심 시 거버넌스/커뮤니티 신고 및 감사 프로세스 마련

4\. vault별 TVL, APR, 유동성 집중도 실시간 대시보드 제공

\


\| Best Practice |&#x20;

contracts/src/pol/rewards/Berachef.sol: \_validateWeights

* 중복 vault 체크, reward vault당 최대 30% 까지 할당 가능

\


T-14. | 위협 |&#x20;

보상 분배 계산 과정 중 나눗셈 연산 정밀도 오류 발생 시 사용자 보상 미세 손실 누적 가능

\| 가이드라인 |&#x20;

1\. 보상 수령 대상 및 금액의 정확성을 교차 검증하는 로직 추가

2\. 최소 수량 or 최대 수량 설정으로 나눗셈 연산 오류 방지

3\. 사용자 유리한 반올림 정책

\
\


\| Best Practice |&#x20;

\
\


T-15. | 위협 |&#x20;

Reward Vault Factory Owner가 악의적인 distributor 생성 시 사용자 보상 시스템 문제 발생

\| 가이드라인 |&#x20;

1\. 악의적인 distributor 변경이 즉각 반영되는 것을 방지하기 위한 Timelock 등의 추가 보안 절차 반영 필요

2\. 변경시 다중 서명 거버넌스 (3명 중 2/3 승인) 필요

\


T-16. | 위협 |&#x20;

Incentive token이 고갈된 뒤에 추가 공급을 하지 않으면 벨리데이터의 Boost Reward 감소

\| 가이드라인 |&#x20;

1\. RewardVault 내의 Incentive token 최소 보유량을 제한

2\. Validator의 경우 BGT를 분배할 reward vault를 선택할때 Incentive token이 충분히 남아있는지 확인

3\. Reward vault에 incentive가 얼마나 남았는지 확인하는 대시보드 제작

\
\


T-17. | 위협 |

Incentive token가 고갈 된 후 Incentive rate를 낮춰 해당 vault를 선택한 벨리데이터의 Boost APR 감소

\| 가이드라인 |&#x20;

1\. Reward Vault의 Incentive rate 변동 시 delay 설정

2\. 사용자에게 incentive rate 변화 알릴 수단 추가

\
\


\| Best Practice |&#x20;

\


T-18. | 위협 |&#x20;

보상 분배 중 모든 LP token을 인출하여 잔고를 0으로 만들면 해당 보상 증발

\| 가이드라인 |&#x20;

1\. 새로운 reward vault를 만들 때는 소량의 초기 LP token을 운영할 주체가 예치(LP가 0 이 되지 않도록) (최소 lp token 설정)

\
\


T-19. | 위협 |&#x20;

정상적인 Incentive token 제거에 따른 보상 중단&#x20;

\


\| 가이드라인 |&#x20;

\


1\. removeIncentiveToken 함수의 호출 조건에 제한 로직 추가 (예: 해당 토큰이 현재 활성 보상 분배 중인 경우 제거 불가)

2\. Incentive Token 제거 또는 교체는 거버넌스 승인을 요구하도록 설계

3\. Incentive Token 제거 전, 해당 Vault의 남은 분배량 및 종료 일정 공지

4\. 토큰 제거 시 이벤트 로그 기록 필수 및 대시보드 상 실시간 반영

5\. Vault의 보상 구조 변경(토큰 추가/제거)은 사용자에게 사전 고지 및 명확한 UI 표시

6\. 보상 토큰 변경 이력은 감사 로그(audit trail) 로 저장, 분기별 커뮤니티 감사 진행

\| Best Practice |&#x20;

\


T-20. | 위협 |&#x20;

claimFees() 프론트러닝에 따른 사용자의 수수료 보상 왜곡&#x20;

\


\| 가이드라인 |&#x20;

1\. claimFees() 호출 시 프론트러닝 방지를 위해 수수료 계산 기준이 되는 블록 넘버/타임스탬프를 내부 저장하고 호출자 기준으로 고정하여 외부 간섭 방지 or 클레임 대상 사용자 주소 명시 필드 활용

2\. $HONEY 등 Fee Token 잔고가 급변할 경우 이상 징후 탐지 및 임시 정지 로직(safeguard) 활성화

3\. 수수료 누적/청구/소진 과정은 이벤트 로그를 통한 추적이 가능해야 하며, 이상 징후 발생 시 자동 경고를 발생시키는 보상 모니터링 시스템 구축

4\. 클레임 가능한 수수료 토큰 종류는 허용된 화이트리스트기반으로 제한

\


\| Best Practice |  &#x20;

\


T-21. | 위협 |&#x20;

dApp 프로토콜의 Fee Token 송금 누락에 따른 사용자 보상 실패&#x20;

\


\| 가이드라인 |&#x20;

\
\


1\. FeeCollector와 dApp 간 수수료 정산 상태(누적/미정산)를 주기적으로 확인하는 오프체인 모니터링 시스템 도입

2\. 일정 기간 동안 수수료 송금이 누락된 dApp은 해당 vualt의 인센티브 대상에서 제외하거나 거버넌스를 통해 보상 삭감/정지 등의 제재가 가능하도록 설계

3\. claimFees() 호출 시, payoutAmount가 200 HONEY(=1%) 이하일 경우 명확한 revert 사유 및 UI 피드백 제공

\


\| 위협 |

토큰 승인 검증 부재 및 ERC-20 표준 미검증으로 인한 위협

\| 가이드라인 |

1\. 안전한 토큰 승인 및 전송

* 거래별 정확한 승인량 계산 및 설정
* 승인량과 실제 사용량 일치 검증
* 모든 토큰 전송 후 반환값 검증 및 전송 실패 시 전체 롤백

\


2\. 토큰 표준 호환성 검증

* ERC-20 표준 준수 여부 사전 검증

\


3\. 토큰 화이트리스트 관리

* 지원 토큰 사전 심사 및 승인 절차
* 악성 토큰 블랙리스트 운영 및 실시간 업데이트

\


\| Best Practice |

SafeERC20 라이브러리 및 TransferHelper 활용 - kodiak-contracts/KodiakFarm/src/farms/KodiakFarm.sol

\`using SafeERC20 for IERC20\` 안전한 토큰 전송

\`TransferHelper.safeTransferFrom()\` 전송 실패 처리

\`IERC20Metadata\` 인터페이스로 토큰 메타데이터 표준 접근

\


&#x20;                                                                  &#x20;

\
\


T-23. | 위협 |&#x20;

인센티브 분배 대상 선정 로직 오류

\| 가이드라인 |\
1\. 인센티브 분배기에 필요한 각종 기능에 대한 권한을 거버넌스 구조로 역할 분리\
2\. 인센티브 분배 설정 변경 시 이중 검증 실시\
3\. 설정 변경 후 실제 적용에 시간차를 두기 위한 시간 지연 로직 구현

\| Best Practice |\
• src/pol/rewards/BGTIncentiveDistributor.sol\
&#x20; -\
• src/pol/rewards/BeraChef.sol\
&#x20; \- \_validateWeights, \_checkIfStillValid 등\
&#x20; \- 설정 변경 후 실제 지연에 시간차를 두기 위한 시간 지연 로직을 queueNewRewardAllocation, activateQueuedValCommision 함수를 통해서 구현\
&#x20; \- 허용된 인센티브 분배 대상을 분류하기 위한 화이트리스트 토큰, 볼트 주소 관리 기능을 whitelistIndentiveToken, setVaultWhitelistedStatus 함수를 통해서 관리



T-23. | 위협 |&#x20;

분배 비율 또는 기간 설정 오류로 인한 과도/과소 인센티브 지급 |

\| 가이드라인 |\
1\. 시간 기반 분배 로직 처리 과정에서 블록 타임스탬프 의존성 최소화\
2\. 인센티브 연산 과정에서 안전한 시간 연산을 위해 검증된 수학 계산 라이브러리 사용

\| Best Practice |\
• src/pol/rewards/RewardVault.sol -> src/base/StakingRewards.sol\
&#x20; \- 리워드 최솟값과 토큰 계산 과정에서 안전한 연산을 위한 FixedPointMathLib 라이브러리 사용\
&#x20; \- \_notifyRewardAmount, \_computeLeftOverReward 함수에서 조건부 시간 계산을 위해 안전성이 보장된 상황에서만 시간 차이를 계산\
• src/pol/rewards/BeraChef.sol\
&#x20; \- queueNewRewardAllocation 함수 시작부에서 블록 번호 기반 지연 처리를 통해 타임스탬프 조작 공격 방지\
• src/pol/rewards/BGTIncentiveDistributor.sol\
&#x20; \- MAX\_REWARD\_CLAIM\_DELAY 지정을 통해 타임스탬프 기반 지연 시간 최소화

T-24. | 위협 |&#x20;

권한 없는 사용자의 인센티브 풀 무단 인출&#x20;

\| 가이드라인 |\
1\. 인센티브 토큰과 연관된 스테이킹 토큰마다 별도의 RewardVault를 생성 및 검증된 Reward Vault만 운영할 수 있는 별도의 관리 기준 운영\
2\. 인센티브 토큰 보상 정보를 독립적으로 관리할 수 있는 로직 추가\
3\. 인센티브 토큰 지급 Vault 별 분산된 권한 관리를 위한 계층적 권한 구조 적용

\| Best Practice |\
• src/pol/rewards/RewardVault.sol\
&#x20; \- 오프체인 거버넌스 포럼 검증을 통한 허가된 Vault만 인센티브 보상을 제공하는 방식 제공 (향후 온체인 구현 필요)\
&#x20; \- 각 인센티브 토큰 정보를 별도의 구조체(struct Incentive)로 관리\
&#x20; \- 인센티브 토큰 별 정확한 잔액 추적과 관리자 지정을 위한 구조체 내 변수 지정\
&#x20; \- Vault에 필요한 계층적 권한 구조를 최고 관리자, Vault 관리자, Pauser, 인센티브 토큰 별 개별 관리자와 같이 지정 (src/base/FactoryOwnable.sol 상속 코드 확인)

\


T-25. | 위협 |&#x20;

Validator operator의 incentive 분배 직전 queue 조작을 통한 commission 탈취 및 사용자 분배 손실

\| 가이드라인 |\
1\. 인센티브 분배 로그 분석을 통한 현황 추적\
2\. 악의적인 validator slashing

\| Best Practice |\
• src/pol/rewards/RewardVault.sol\
&#x20; \- \_processIncentives 함수 내에서 BGT Booster와 Validator 몫에 대한 로깅을 이중으로 수행\
&#x20; \- \_processIncentives 함수 내 성공/실패 이력 모두 로깅 수행\
• src/pol/rewards/BeraChef.sol\
&#x20; \- \_getOperatorCommission 함수에서 매개변수로 제공받은 validator의 공개키로 인센티브 수량 계산 전 수령 유효성 확인\
&#x20; \- 악의적인 validator 탐지를 위한 ValidatorSet 등의 이벤트 처리기로 이력 추적 진행

T-26. | 위협 |&#x20;

$BGT 토큰 배출량 계산 오류 및 가중치 조작을 통한 인플레이션 유발

\| 가이드라인 |&#x20;

1\. 모든 중요 파라미터 변경은 거버넌스 투표를 통해서만 가능하도록 제한

2\. 보상 계산 파라미터 변경 시 점진적 변화만 허용하도록 상한선 및 하한선 설정

3\. 실시간 보상 배출량 모니터링 시스템 구축 및 이상 징후 감지 메커니즘 설정

4\. 심각한 계산 오류 발생 시 즉시 대응하기 위한 긴급 조치 프로토콜 마련

5\. 보상 계산식에 대한 명확한 문서화와 커뮤니티 이해를 위한 시각화 자료 제공

\
