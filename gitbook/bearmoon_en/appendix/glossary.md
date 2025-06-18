---
description: This is an explanation of the terms used in the guideline above.
---

# Glossary

### Basic Tokens and Mechanisms

- `PoL (Proof of Liquidity)`: A mechanism where contributing to network security by providing liquidity to a specific dApp earns rewards.
- `PoS (Proof of Stake)`: A traditional consensus mechanism where staking native tokens contributes to network security and earns rewards.
- `BERA`: The native gas token of Berachain.
- `BGT (Berachain Governance Token)`: The governance and PoL reward token of Berachain.
- `HONEY`: Berachain's stablecoin. It is generated with stablecoins (USDC, BYUSD) as collateral and used as the basic unit of transaction within the dApp ecosystem.
- `SBT (Soulbound Token)`: A token that is permanently bound to a specific wallet and cannot be transferred.
- `Governance`: A decentralized decision-making system where token holders decide on important protocol matters through voting.

---

### Protocol-Specific Tokens

- `NECT`: A stablecoin issued by the Beraborrow protocol.
- `POLLEN`: The governance token of the Beraborrow protocol.
- `iBERA (Infrared BERA)`: A liquid staking derivative token issued by the Infrared protocol for staking BERA.
- `iBGT (Infrared BGT)`: A token that liquefies BGT rewards in the Infrared protocol.

---

### DeFi Related Terms

- `dApp (Decentralized Application)`: A decentralized application.
- `DEX (Decentralized Exchange)`: A decentralized exchange.
- `LP Token (Liquidity Provider Token)`: A token received in return for providing liquidity to a DEX liquidity pool.
- `TWAP (Time-Weighted Average Price)`: The average price over a specific period, resistant to short-term price manipulation.
- `VWAP (Volume-Weighted Average Price)`: A method of calculating the average price that considers trading volume.
- `LTV (Loan-to-Value)`: The ratio of the loan amount to the value of the collateral.
- `Slippage`: The difference between the requested price of an order and the actual execution price.
- `Impermanent Loss`: A phenomenon where providing liquidity to a DEX results in a loss compared to simply holding the assets due to price fluctuations within the pool.
- `Staking`: The act of locking up tokens to contribute to network security and receive rewards.
- `Timelock`: a mandatory waiting period before a specific action can be executed. It is a security measure to prevent abrupt changes.
- `Emergency Withdrawal`: A feature to withdraw funds faster than the normal withdrawal process, usually with a penalty.
- `Oracle`: A service that brings real-world data (like price information) from outside the blockchain to the inside.
- `Pegging`: The state where a stablecoin maintains its target price (usually $1).
- `Minting`: The act of depositing collateral and issuing new tokens (like HONEY, NECT).
- `Redeem`: The act of returning issued tokens to retrieve the collateral assets.
- `Smoothing`: A mechanism to mitigate sharp price fluctuations and maintain a stable value.
- `MEV (Maximal Extractable Value)`: The maximum value that can be extracted by block producers or validators by manipulating the order of transactions.
- `Front-running`: The act of profiting by identifying another user's transaction and executing a trade before them.
- `Circuit Breaker`: A safety mechanism that automatically halts trading when an abnormal situation is detected.
- `Sybil Attack`: An attack where a single entity creates multiple fake accounts to manipulate votes.
- `Quadratic Voting`: A voting method that limits the influence of large holders by calculating voting power based on the square root of token holdings.
- `Single-sided Liquidity`: Providing liquidity with only one type of token.
- `Swap Router`: A router contract that handles token swaps.
- `Tick`: A unit representing a price range in Uniswap V3.
- `Whitelist`: A list of allowed tokens or addresses.
- `Multi-sig`: Multiple signatures. A security mechanism requiring multiple signatures.

---

### Berachain Ecosystem Related Terms

- `Boosting`: A mechanism where BGT holders delegate BGT to a specific validator to increase that validator's rewards.
- `Flywheel`: A structure in the Berachain ecosystem where incentives among participants create a virtuous cycle, leading to the growth of the entire ecosystem.
- `Reverse Flywheel`: A situation where the ecosystem falls into a vicious cycle due to decreased liquidity or participant churn.
- `LSP (Liquid Stability Pool)`: A pool in Beraborrow for NECT peg stability and liquidation support.
- `Den`: An individual debt position in Beraborrow where users deposit collateral and mint NECT.
- `Reward Vault`: A contract that distributes BGT or incentive tokens to liquidity providers.
- `Incentive Token`: An additional reward token provided by the protocol.
- `Delegation`: The act of BGT holders delegating BGT to validators to provide a boosting effect.
- `Operator`: An entity responsible for a validator's reward distribution. It is set by the validator and holds the authority for reward distribution.
- `Basket Mode`: A mode in HONEY for minting/redeeming with a combination of multiple collateral assets instead of a single asset.
- `Queue System`: A waiting system that processes requests in order.
- `Guardians`: Trusted entities with the authority to review and approve/reject governance proposals.
- `Keeper`: A bot or account with the authority to automatically execute specific protocol functions.
