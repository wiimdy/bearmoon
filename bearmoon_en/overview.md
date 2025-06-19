---
icon: teddy-bear
---

# Berachain PoL Overview

**PoL (Proof of Liquidity)** is a new mechanism that, unlike the existing PoS (Proof of Stake), supplies actual liquidity to the ecosystem.

In PoS, rewards are earned by contributing to security through the staking of native tokens. In this case, liquidity providers and network users do not receive separate rewards.

However, in PoL, users provide liquidity to dApps within the Berachain ecosystem (e.g., DEX, Lending Protocol) and stake the receipt tokens (such as LP tokens) received as proof in a reward vault to earn BGT, the reward token. The acquired BGT is delegated (boosted) to validators, influencing their reward distribution weight, and thereby contributing to the network by sharing a portion of protocol incentives and network fees.

While PoS is based on the assumption that 'asset ownership = contribution,' PoL aims to achieve both network security and DeFi ecosystem activation based on the assumption that 'real-use based assets = real contribution.'

In other words, the core of PoL is the ability to directly participate in the ecosystem while contributing to network security.

|        Feature        |          PoS          |                PoL               |
| :-------------------: | :-------------------: | :------------------------------: |
| Network Participation |     Simple Staking    | Liquidity Provision + LP Staking |
|     Economic Model    |    Dual Token Model   |          Tri-Token Model         |
|   Network Activation  | Indirect Contribution |        Direct Contribution       |

Berachain's PoL is designed with the following **tri-token model**.

1. **BERA**: Berachain's native token, used for paying transaction fees, providing liquidity, and maintaining network security.
2. **BGT (Berachain Governance Token)**: Berachain's governance and reward token, primarily distributed through reward vaults to participants who provide liquidity to the ecosystem. Validators also receive BGT as a base reward for proposing blocks. This token has a non-transferable characteristic, is bound to the user, and is used for validator boosting (delegation) and governance voting. It can also be exchanged 1:1 for $BERA.
3. **HONEY**: Berachain's stablecoin, used as the basic unit for various financial activities such as lending and trading within the dApp ecosystem. It is generated with stablecoins (USDC, \*BYUSD) as collateral and maintains its stability based on the collateral ratio and oracle prices within the protocol.

Through this tri-token structure, Berachain enables an economic flywheel structure of **"Ecosystem Participation = Rewards = Governance."**

_\*BYUSD: A token created by bridging and transferring PayPal USD (PYUSD) to Berachain._

***

### Berachain Flywheel <a href="#id-2.2" id="id-2.2"></a>

Berachain has designed a **flywheel** based on PoL to connect the rewards among network participants (protocols, validators, liquidity providers) into a single structure, aiming for long-term health.

In this structure, competition for boosts among validators, profit optimization strategies among liquidity providers, and competition for liquidity among dApp protocols are induced, leading to a virtuous cycle where the entire ecosystem's liquidity and security grow together.\
In other words, in the PoL structure, it operates not just as a simple reward distribution system but as a system that creates the driving force for ecosystem growth through strategic competition among network participants.

The specific flywheel operates as follows for each participant:

1. **Liquidity Provider** → Provides Liquidity → Stakes LP Tokens → Receives BGT Rewards → Boosts Validators
2. **Validator** → Stakes BERA → Creates Blocks (Block Creation Reward) → Distributes Rewards to Reward Vault → Receives Incentive Token Rewards
3. **Protocol (dApp)** → Receives Liquidity → Provides Incentive Tokens

<figure><img src=".gitbook/assets/image (7).png" alt=""><figcaption></figcaption></figure>

As a result, when the flywheel operates normally, it forms the following virtuous cycle.

<figure><img src=".gitbook/assets/image (2).png" alt=""><figcaption></figcaption></figure>

This ultimately promotes the **growth and stability** of the entire Berachain network.

***

Berachain's PoL is a structure that satisfies both network security and liquidity, inducing participation based on actual use to activate the ecosystem. Additionally, the governance token, BGT, is distributed only to actual ecosystem participants, allowing them to become governance participants.

However, PoL is not perfect.

If the flywheel operates normally, it leads to a structure that benefits everyone, but as it is a liquidity-based consensus algorithm, a decrease in liquidity could cause a **reverse flywheel**, destabilizing the entire ecosystem.

<figure><img src=".gitbook/assets/image (3).png" alt=""><figcaption></figcaption></figure>

Furthermore, PoL also has issues such as liquidity concentration, BGT monopoly, and centralization risks.

To solve these imperfections, security-focused design principles must be applied throughout the ecosystem.

Against this background, we propose the **PoL Security Guidelines**.
