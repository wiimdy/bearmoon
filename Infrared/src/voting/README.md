
# Voting Contracts - Infrared

The `voting` contracts in Infrared enable users to participate in the allocation of IBGT rewards to various vaults through a **voting escrow (ve) system**. The contracts form a bribe-based voting mechanism, where users vote to influence the distribution of validator resources (referred to as the "cutting board") among eligible vaults. Users receive rewards based on their voting commitment, with the option for additional incentives through a bribe system.

## Concepts

The Infrared protocol’s voting contracts implement a **voting escrow (ve)** system. This system encourages long-term token locking by rewarding users with voting power and additional incentives when they help allocate validator resources. Key concepts include:

1. **Voting Power**: Voting power is tied to the number of tokens a user locks and the duration of the lock. Longer locks yield higher voting power, which decreases as the lock expiration date nears.
2. **Voting Escrow NFTs (veNFTs)**: When users lock tokens, they receive a unique veNFT that represents their voting power. This veNFT can also be delegated to other users for voting purposes.
3. **Cutting Board Allocation**: The primary goal for veNFT holders is to vote on the distribution of validator resources (cutting board) across multiple vaults. By voting, users influence which vaults receive rewards and the relative weights of these rewards.
4. **Bribe Mechanism**: external actors can offer bribes to incentivize users to vote in their favor, increasing the likelihood of a higher allocation.
5. **Epochs and Voting Windows**: Voting periods align with weekly epochs. During each epoch, users can vote on vault allocations, and at the end of the period, votes are tallied and allocations updated.

## Actors

1. **User**: A participant who locks tokens in exchange for voting power. Users receive veNFTs, which allow them to vote on the allocation of validator resources to vaults.
2. **Governor**: Holds the authority to initialize the `VotingEscrow` contract, set the `Voter` contract address, and approve new vaults eligible for voting. Governors may adjust protocol parameters but are not directly involved in vote outcomes.
3. **Keeper**: Responsible for operational tasks, including creating new bribe vaults with `createBribeVault`, which allows voters to receive bribes for voting in favor of specific vaults.
4. **Delegatee**: An entity that receives voting power from users who choose not to vote directly.
5. **Whitelisted Tokens for Bribes**: Only specific, whitelisted tokens are allowed as bribes for voting. This whitelisting ensures that only tokens approved by governance are used as incentives

---

## Core Contracts

### 1. `VotingEscrow`

The `VotingEscrow` contract is central to the veTokenomics model, managing token locks and voting power.

- **Token Locking**: Users lock tokens in exchange for voting power, represented by veNFTs. The longer the lock, the more voting power the user receives.
- **Voting Power Decay**: Voting power decreases as the lock nears expiration. Users can extend locks or increase their token amounts to maintain or grow their voting power.
- **veNFT Management**: veNFTs, representing locked positions, can be delegated to other users or used to vote on allocations.

*Technical Details*: `VotingEscrow` includes structs like `LockedBalance`, `UserPoint`, and `GlobalPoint` to track user-specific and global voting power.

### 2. `Voter`

The `Voter` contract drives the allocation process by allowing veNFT holders to vote on cutting board distribution across vaults. Votes directly influence the weight each vault receives in the reward distribution.

- **Voting on Cutting Board Allocation**: Users cast votes to determine the distribution of validator resources (cutting board) among approved vaults. Vaults with higher votes receive a larger share of resources.
- **Bribe System with Whitelisted Tokens**: External actors can offer bribes to incentivize users to vote in favor of specific vaults. Bribes help vaults gain higher allocations by attracting more votes from veNFT holders. Importantly, only tokens that have been whitelisted by governance are allowed as incentives.
- **Vote Tallying and Weight Assignment**: At the end of each voting window, votes are tallied, and the weights for each vault are updated to reflect user preferences.
- **Epoch-Based Voting**: Votes are cast within a defined voting window in each weekly epoch, ensuring a predictable voting cycle.

*Technical Details*: `Voter` utilizes `VelodromeTimeLibrary` to enforce voting within set windows, helping to maintain synchronized cycles across all users.

### 3. `VelodromeTimeLibrary`

The `VelodromeTimeLibrary` library calculates epochs and voting windows based on weekly intervals. This structure provides consistent and predictable time-based operations within the `VotingEscrow` and `Voter` contracts.

- **Epoch Calculations**: Functions like `epochStart` and `epochNext` allow the protocol to determine the beginning and end of each weekly epoch.
- **Voting Window Calculations**: The `epochVoteStart` and `epochVoteEnd` functions calculate the voting window within each epoch, ensuring that all votes are cast within the designated timeframe.

---

## Contract Interactions

Here’s an overview of how the `voting` contracts interact:

1. **Locking Tokens**:
   - Users lock tokens in `VotingEscrow`, creating a veNFT that grants voting power.
   - Voting power decays over time, encouraging users to commit to longer locks for greater influence.

2. **Voting on Vault Allocations**:
   - Users vote with their veNFTs in the `Voter` contract to determine how validator resources are allocated across vaults.
   - Voting power, calculated at each vote, factors in token lock duration and decay rate.

3. **Proposal and Bribe Vault Lifecycle**:
   - Governance approves vaults eligible for voting through the Governor role.
   - The Keeper can then create bribe vaults with `createBribeVault` to allow vaults to offer incentives (bribes) for users to vote in their favor.

4. **Tallying Votes and Updating Weights**:
   - At the end of each voting period, the `Voter` contract tallies the votes.
   - Each vault’s allocation weight is updated based on vote totals, determining its share of resources until the next epoch.

---

## Security and Access Control

The `voting` contracts implement specific roles for security and access control:

- **Only veNFT Holders Can Vote**: Voting is restricted to users who hold veNFTs in `VotingEscrow`.
- **Delegation Restrictions**: Users can delegate voting power through veNFTs, with delegates receiving temporary voting power based on the owner's locked balance and lock duration.
- **Governor Role**: The Governor can initialize contracts, approve eligible vaults, and update protocol settings.
- **Keeper Role**: The Keeper can create bribe vaults, allowing vaults to incentivize votes, making voting more competitive.
- **Epoch-Based Voting Enforcement**: Votes are restricted to defined windows, ensuring governance actions are synchronized and follow a predictable cadence.
- **Whitelisted Tokens for Bribes**: Only specific, whitelisted tokens are allowed as bribes for voting. This whitelisting ensures that only tokens approved by governance are used as incentives.

---

## Summary

The `voting` contracts in Infrared implement a unique allocation mechanism that uses veTokenomics principles to distribute validator resources among vaults based on user votes. The system incentivizes long-term participation through token locking and rewards, while the bribe mechanism encourages active voting by offering additional incentives. 

With clear roles for the **Governor** and **Keeper**, predictable epochs, and well-defined voting windows, the Infrared voting contracts provide an efficient and secure way for the community to influence validator resource allocation. This setup fosters user engagement and transparent decision-making, helping align incentives across the protocol.
