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

#### 수식 정상 동적 검증

<details>

<summary></summary>



</details>

### APR

#### 수식 정보

$$
\text{APR} = \frac{\textit{rewardRate} \times \textit{secondsPerYear} \times \textit{priceOfBGT}}{\textit{totalSupply} \times \textit{priceOfStakeToken}}
$$





## dApp 관련 수식

### Lending



### DEX



### LSD



