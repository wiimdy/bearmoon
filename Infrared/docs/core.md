# Core Contracts - Infrared Protocol

The `core` folder of the Infrared Protocol contains contracts that facilitate interaction with Berachain’s Proof-of-Liquidity (PoL) reward system. These contracts manage Infrared validator registration, BGT (Bera Governance Token) accumulation, iBGT issuance, bribe collection, and reward distribution.

---

## Key Concepts: Berachain and Infrared Integration

Infrared is built to interact with Berachain’s PoL architecture, leveraging its reward mechanisms and governance structure. Here are the essential components of Berachain and how Infrared-managed validators interact with them:

1. **Proof-of-Liquidity (PoL) Reward System**: Berachain’s PoL rewards users who stake eligible assets in `BerachainRewardsVaults` with BGT emissions. Each Infrared validator uses a *RewardAllocation* to define how BGT emissions are allocated among various reward vaults.

2. **BeraChef and RewardAllocations**: Infrared validators configure their "RewardAllocations" via `BeraChef`, determining which `BerachainRewardsVaults` receive BGT when an Infrared validator proposes a block.

3. **BGT and Boosting Infrared Validators**: 
   - BGT can be delegated (boosted) to increase BGT production for validators. BGT is earned through staking liquidity tokens into `BerachainRewardsVaults`.
   - Infrared’s `harvestBoostRewards` function is used to claim rewards from BGT boosts, redistributing them to iBGT holders.

4. **Incentives via Bribes**: Berachain allows additional incentive layers by offering bribes within `BerachainRewardsVaults`. Infrared’s `BribeCollector` accumulates these bribes and auctions them off, redistributing the proceeds among validators and iBGT stakers.

---

## Key Actors

1. **User**: Deposits assets into `InfraredVaults` for staking into `BerachainRewardsVaults`, earning iBGT rewards and participating in PoL through Infrared.

2. **InfraredVault**: Manages user staking, rewards accumulation, and BGT claims via `Infrared`.

3. **Infrared Validator**: Validators registered with Infrared that can receive BGT boosts and participate in the PoL consensus on Berachain.

4. **Keeper**: Manages essential tasks, including updating validator configurations, distributing rewards, and BGT claiming.

5. **Governor**: Oversees protocol parameters, manages governance decisions, and controls critical configuration functions.

---

## Core Contracts

### 1. `Infrared.sol`

The `Infrared` contract serves as the main coordination contract for managing validators, processing BGT, issuing iBGT, and handling bribes and rewards.

- **Validator Registration and RewardAllocation Configuration**: Registers and configures Infrared validators and their operators and establishes their RewardAllocation.
  
- **Centralized BGT Claiming and iBGT Conversion**: Consolidates reward claims from `InfraredVaults`, converts BGT to iBGT, and distributes it to vault stakers.

- **Bribe Collection and Auctioning**: Sends POL bribes from Infrared validators to `BribeCollector` for auctioning. Proceeds are distributed to validators and iBGT stakers, with payout parameters set by governance.

- **Reward Harvesting**:
    - **harvestBase**: Harvests base rewards and commissions in BGT, splitting them between:
        - **wiBERA Vault**: Receives a portion of base rewards.
        - **Validator Distributor**: Distributes rewards to Infrared validators.
      Fees are applied to support protocol operations.
    - **harvestBoostRewards**: Harvests BGT rewards from boosting, distributing them to iBGT holders. Fees are applied based on protocol-defined parameters.

### 2. `InfraredVault`

Each `InfraredVault` manages staking for users in designated `BerachainRewardsVaults`, consolidating rewards and delegating BGT claims to `Infrared`.

- **Staking**: Users stake assets in `BerachainRewardsVaults` to participate in the PoL reward system.
- **Reward Accumulation**: Vaults accumulate BGT rewards, which `Infrared` claims centrally and converts to iBGT for user distribution.

### 3. `MultiRewards`

The `MultiRewards` contract adds flexibility to reward distribution by supporting multiple reward tokens per vault.

- **Diverse Reward Support**: Allows up to 10 reward tokens per vault, enabling varied incentives.

### 5. `BribeCollector`

The `BribeCollector` handles collection and auctioning of POL bribes from `BerachainRewardsVaults`.

- **Auction Mechanism**: POL bribes are auctioned to generate funds for validators and iBGT holders.
- **Governance-Configurable Parameters**: Payout tokens, amounts, and other auction parameters are controlled by governance.

### 5. `InfraredDistributor`

The `InfraredDistributor` is responsible for distributing rewards, primarily in iBGT, to Infrared validators. Key functionalities include:

- **Validator Registration and Reward Tracking**: Tracks rewards for each validator. Each validator’s rewards are logged in snapshots for easy claims by the operator.
  
- **Reward Notification and Distribution**:
    - **notifyRewardAmount**: Records the addition of rewards to the distributor and updates the cumulative reward amount.
    - **Claim Functionality**: Validators claim rewards in iBGT, based on the accumulated snapshots, which keeps track of each validator's cumulative reward total over time.

---

## Flow of Funds in Infrared

### Overview

The `Infrared` contract coordinates multiple fund flows, primarily through interactions with `InfraredVaults`, `BribeCollector`, and Berachain contracts:

1. **User Deposits and Staking**:
   - Users deposit assets into `InfraredVaults`, which stake into designated `BerachainRewardsVaults`, generating BGT rewards.

2. **BGT Accumulation and Conversion to iBGT**:
   - Infrared claims BGT rewards from `InfraredVaults`, converts them to iBGT, and distributes iBGT to vault stakers.

3. **Base Rewards and Boost Rewards Harvesting**:
   - **Base Rewards (`harvestBase`)**: BGT rewards are distributed between the wiBERA vault and validator distributor. Fees incentivize validator participation and support the wiBERA vault.
   - **Boost Rewards (`harvestBoostRewards`)**: Rewards from BGT boosts are claimed and distributed to iBGT holders.

4. **POL Bribe Collection and Auctioning**:
   - `BribeCollector` accumulates POL bribes, auctions them, and distributes the proceeds to validators, iBGT stakers, and protocol.

5. **Fee and Reward Allocation**:
   - After reward collection, fees support protocol operations, while remaining funds are distributed to validators and vault participants according to RewardAllocation configurations.

---

## Contract Dependencies and Access Control

### Dependencies

- **`Infrared.sol`**: Coordinates operations across all core contracts.
- **`InfraredVault.sol`**: Extends `MultiRewards`, manages interaction with `BerachainRewardsVault`.
- **`MultiRewards.sol`**: Provides multi-token reward distribution logic.
- **`BribeCollector.sol`**: Manages POL bribe auctions.
- **`InfraredDistributor.sol`**: Distributes BGT rewards to Infrared validator operators.

### Access Control

- **KEEPER_ROLE**: Manages operational tasks like updating configurations and claiming rewards.
- **GOVERNANCE_ROLE**: Controls protocol parameters and high-level functions across contracts. 