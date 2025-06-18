---
icon: sack-dollar
---

# PoL Security Guideline: Reward Distribution

<table><thead><tr><th width="617.40625">Threat</th><th align="center">Impact</th></tr></thead><tbody><tr><td><a data-mention href="reward.md#id-1">#id-1</a></td><td align="center"><code>Medium</code></td></tr><tr><td><a data-mention href="reward.md#id-2">#id-2</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="reward.md#id-3-erc20">#id-3-erc20</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="reward.md#id-4">#id-4</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="reward.md#id-5">#id-5</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="reward.md#id-6">#id-6</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="reward.md#id-7-lp-notifyrewardamount">#id-7-lp-notifyrewardamount</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="reward.md#id-8">#id-8</a></td><td align="center"><code>Low</code></td></tr></tbody></table>

### Threat 1: Double-claiming rewards through re-entrancy attacks

Allowing re-entrancy on functions that control token flow within a contract can lead to unauthorized token withdrawal through re-entrancy attacks, resulting in system-wide losses.

#### Impact

`Medium`

A successful re-entrancy attack allows a user to withdraw more than their legitimate rewards, causing direct financial loss to the protocol or other users. Therefore, it is assessed as 'Medium'.

#### Guideline

> - **Adhere to the Checks-Effects-Interactions pattern**
> - **Use [ReentrantGuard](../../reference.md#oz-reentrancyguard-spec)**

#### Best Practice

[`RewardVault.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/pol/rewards/RewardVault.sol#L336)

<pre class="language-solidity"><code class="lang-solidity">function <a data-footnote-ref href="#user-content-fn-1">getReward</a>(
    address account,
    address recipient
)
    external
    // Use nonReentrant guard
    nonReentrant
    onlyOperatorOrUser(Account)
    returns (uint256)
{
    // ...
}
</code></pre>

[`StakingRewards.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/base/StakingRewards.sol#L139)

```solidity
function _getReward(address account, address recipient)
    internal
    virtual
    updateReward(account)
    returns (uint256)
{
    // ...
    // Initialize and send the unclaimed reward
    uint256 reward = info.unclaimedReward;
    // ...
}
```

---

### Threat 2: Manipulation and use of incentive tokens by unauthorized users

An unauthorized user could add or duplicate incentive tokens, leading to excessive rewards from the system. Without a whitelist, token count limits, and duplication prevention logic, a malicious user could disrupt the incentive structure.

#### Impact

`Low`

If an attacker adds a malicious token to the incentive tokens, they could intercept validator and user rewards or increase the incentive rate, rapidly depleting the protocol's incentive tokens. However, since token registration is a process managed by governance, this is assessed as 'Low'.

#### Guideline

> - **[Limit incentive token count and prevent duplicate registration when managing the incentive token whitelist](../../reference.md#berachain-rewardvault-whitelist)**
>   - **Permission to add incentive tokens:** Factory Owner
>   - **Permission to remove incentive tokens:** Factory Vault Manager
>   - Currently, a maximum of 3 incentive tokens can be registered
> - **Verify max/min range when setting reward rates and restrict manager permissions**
>
>   - When adding incentive tokens, verify `minIncentive > 0`
>
>     ```solidity
>     // validate `minIncentiveRate` value
>     if (minIncentiveRate == 0) MinIncentiveRateIsZero.selector.revertWith();
>     if (minIncentiveRate > MAX_INCENTIVE_RATE) IncentiveRateTooHigh.selector.revertWith();
>     ```
>
>   - When changing the incentive rate, set it higher than the minimum rate
>   - ```solidity
>     // The incentive amount should be equal to or greater than the `minIncentiveRate` to avoid spamming.
>     if (amount < minIncentiveRate) AmountLessThanMinIncentiveRate.selector.revertWith();
>
>     // The incentive rate should be greater than or equal to the `minIncentiveRate`.
>     if (incentiveRate < minIncentiveRate) InvalidIncentiveRate.selector.revertWith();
>     ```
>
>   - Current incentive manager permissions
>     - Can add incentive token supply with `addIncentive()`, `accountIncentives()`
>
> - **When recovering ERC20 tokens, transfer excluding incentive and deposited tokens**

#### Best Practice

[`RewardVault.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/pol/rewards/RewardVault.sol#L164-L174)

{% code overflow="wrap" %}

```solidity
function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyFactoryOwner {
    // Check if the incentive token is currently active
    if (incentives[tokenAddress].minIncentiveRate != 0) CannotRecoverIncentiveToken.selector.revertWith();

    // Check stake token
    if (tokenAddress == address(stakeToken)) {
        uint256 maxRecoveryAmount = IERC20(stakeToken).balanceOf(address(this)) - totalSupply;
        if (tokenAmount > maxRecoveryAmount) {
            NotEnoughBalance.selector.revertWith();
        }
    }
}

function whitelistIncentiveToken(
    address token,
    uint256 minIncentiveRate,
    address manager
)
    external
    onlyFactoryOwner
{
    // ...
    // Check the limit on the number of incentive token types
    if (minIncentiveRate > MAX_INCENTIVE_RATE) IncentiveRateTooHigh.selector.revertWith();

    // ...
    // Check the limit on the number of incentive token types
    if (whitelistedTokens.length == maxIncentiveTokensCount || incentive.minIncentiveRate != 0) {
        TokenAlreadyWhitelistedOrLimitReached.selector.revertWith();
    }
    // ...
}
```

{% endcode %}

---

### Threat 3: Threats from unverified ERC20 compliance of incentive tokens

Lack of verification procedures, such as checking for ERC20 standard compliance for incentive tokens, can lead to asset loss due to approval mismatches or transfer failures during the network reward processing.

#### Impact

`Low`

Non-compliant ERC20 tokens or errors in the approval process can cause unintended token transfer failures or quantity mismatches in specific transactions, leading to partial asset loss or functional impairment. Therefore, it is assessed as 'Low'.

**Guideline**

> - **Secure token approval and transfer**
>   - Calculate and set the exact approval amount for each transaction
>   - Verify that the approved amount matches the actual usage
>   - Verify return values after all token transfers and roll back the entire transaction on failure
> - **Token standard compatibility verification**
>   - Pre-verify ERC20 standard compliance
> - **Token whitelist management**
>   - Pre-screening and approval process for supported tokens
>   - Operate a blacklist for malicious tokens with real-time updates

#### Best Practice

[`RewardVault.sol`](https://github.com/berachain/contracts/blob/a405d00920f5b328c69a73b4c2ed4ef3b13adc0d/src/pol/rewards/RewardVault.sol)

{% code overflow="wrap" %}

```solidity
// Manage token whitelist
address[] public whitelistedTokens;

// ...
// In the logic for rewarding incentive tokens, use a modifier to check if the reward token is in the whitelist
modifier onlyWhitelistedToken(address token) {
    if (incentives[token].minIncentiveRate == 0) TokenNotWhitelisted.selector.revertWith();
    _;
}

function addIncentive(
    address token,
    uint256 amount,
    uint256 incentiveRate
)
    external
    nonReentrant
    onlyWhitelistedToken(token)
{
    // ...
    // Use SafeERC20 library functions to handle token transfers securely
    IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    // ...
}
```

{% endcode %}

---

### Threat 4: System errors due to incorrect configuration during contract initialization

During the initial contract deployment, missing essential verification procedures and filtering functions can lead to system errors from incorrect settings.

#### Impact

`Low`

If a contract is deployed with an incorrect address, it may not function correctly. This is more likely to cause a temporary suspension of functionality rather than asset theft, so it is assessed as `Low`. However, preventing re-initialization is critical for upgradeable contracts, as cases like the Parity Wallet incident have shown that it can lead to severe consequences.

#### Guideline

> - **Verify all contract initializations for zero addresses and essential parameters**
> - **Validate the rational range of initial configuration parameters**
> - **Ensure the integrity of the initial state, such as initial deposit root settings**
> - **Ensure the immutability of the initialization function and prevent re-initialization (use `__disableInitializers()`)**
> - **Implement a rollback mechanism for major parameter changes**

#### Best Practice

[`BlockRewardController.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/pol/rewards/BlockRewardController.sol#L71-L88)

{% code overflow="wrap" %}

```solidity
function initialize(
    address _bgt,
    address _distributor,
    address _beaconDepositContract,
    address _governance
)
    external
    initializer
{
    // Verify all address parameter settings during initialization
    // Set _governance address
    __Ownable_init(_governance);
    __UUPSUpgradeable_init();
    // Set _bgt address
    bgt = BGT(_bgt);
    emit SetDistributor(_distributor);
    // Set _distributor address
    distributor = _distributor;
    // Set _beaconDepositContract address
    beaconDepositContract = IBeaconDeposit(_beaconDepositContract);
}
```

{% endcode %}

[`BGT.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/pol/BGT.sol#L117-L123)

```solidity
function initialize(address _owner) external initializer {
    // Set the initial value of boost delay to BOOST_MAX_BLOCK_DELAY
    // ...
    activateBoostDelay = BOOST_MAX_BLOCK_DELAY;
    dropBoostDelay = BOOST_MAX_BLOCK_DELAY;
}
```

---

### Threat 5: Unauthorized reward withdrawal or manipulation due to incorrect access control

If contract access control is not handled correctly, it can lead to reward withdrawal or manipulation by unintended malicious users.

#### Impact

`Low`

An attacker stealing another user's rewards is a significant threat, but the `onlyOperatorOrUser` modifier restricts withdrawals to the depositor or their delegate, making the likelihood of this occurring low. Thus, it is assessed as 'Low'.

#### Guideline

> - **Log all administrative activities (permission changes, critical function calls, etc.)**
> - **Use modifiers like `onlyOwner` and `onlyDistributor` clearly**
> - **Adhere to the principle of least privilege for each address, role, or component**

<table><thead><tr><th width="135.546875" align="center">Role</th><th width="556.265625">Responsibilities &#x26; Permissions</th><th data-hidden>Example Functions</th></tr></thead><tbody><tr><td align="center">Owner</td><td>- Holds overall ownership of the contract<br>- Appoints and dismisses Admin roles<br>- Sets the most critical contract parameters (e.g., adding incentive tokens, delegating pause/resume authority)<br>- Executes contract upgrades (when using a proxy pattern)</td><td>transferOwnership(address newOwner), addAdmin(address admin), removeAdmin(address admin), setProtocolFee(uint256 fee), pause(), unpause(), upgradeTo(address newImplementation)</td></tr><tr><td align="center">Operator</td><td>- Performs routine system operation tasks (more limited than Owner, specific function execution rights)<br>- Executes periodic processes (e.g., triggering reward distribution logic, updating oracle price information)<br>- Monitors system status and records relevant data</td><td>triggerRewardDistribution(), updatePriceOracle(address asset, uint256 price), recordSystemMetrics()</td></tr><tr><td align="center">User</td><td>- Uses the core functions of the protocol (e.g., asset deposit, swap, loan, repayment)<br>- Views and manages their own account-related information (e.g., checking balance, claiming rewards)<br>- Participates in governance (for token holders, voting, etc.)</td><td>deposit(address asset, uint256 amount), withdraw(address asset, uint256 amount), claimRewards(), getBalance(address user, address asset), voteOnProposal(uint256 proposalId, bool support)</td></tr></tbody></table>

#### Best Practice

[`RewardVault.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Core/src/pol/rewards/RewardVault.sol#L373)

```solidity
function addIncentive(
    address token,
    uint256 amount,
    uint256 incentiveRate
)
    external
    nonReentrant
    onlyWhitelistedToken(token)
{
    // ...
    // Only the manager can change the reward rate
    if (msg.sender != manager) NotIncentiveManager.selector.revertWith();
    // ...
}

modifier onlyOperatorOrUser(address account) {
    if (msg.sender != account) {
        if (msg.sender != _operators[account]) NotOperator.selector.revertWith();
    }
    _;
}

function getReward(
    address account,
    address recipient
)
    external
    nonReentrant
    // Only the operator or a user set by the operator can claim rewards
    onlyOperatorOrUser(account)
    returns (uint256)
{
    // ...
}
```

---

### Threat 6: Cumulative loss of user rewards due to precision errors in division operations during reward calculation

During reward distribution calculations, division [precision errors](../../reference.md#undefined-2) can cause some users' rewards to be consistently lost below the decimal point, leading to accumulation of losses.

#### Impact

`Low`

Due to the limited calculation precision of the contract, users may receive slightly less than the promised reward amount. However, this is a minute difference, often within the acceptable tolerance of financial systems (0.01%), and is not an intentional theft. Therefore, it is assessed as 'Low'.

#### Guideline

> - **Add logic to verify the accuracy of the claimed reward amount**
>   - Use the **`_verifyRewardCalculation`** function to reverse-calculate and verify the reward amount
>   - Set an [error margin of 0.01%](../../reference.md#id-0.01) (a common tolerance in most financial systems)
> - **Recommend using FixedPointMathLib**
>   - Use functions like `mulDiv` to perform multiplication and division safely while preserving maximum precision
> - **User-favorable rounding policy**
>
>   - If a user is entitled to a reward but the amount is truncated to zero by division, guarantee a minimum value (1 wei)
>
>   ```solidity
>   if (balance > 0 && earnedAmount == 0 && rewardPerTokenDelta > 0) {
>       earnedAmount = 1; // Guarantee at least 1 wei
>   }
>   ```

#### Best Practice

`Custom Code`

{% code overflow="wrap" %}

```solidity
// Improving the _processIncentives function in the existing RewardVault.sol
contract RewardVault is ... {
    // ... existing code ...

    // Guideline 2: Set min/max quantities
    uint256 private constant MIN_INCENTIVE_AMOUNT = 1e6; // to prevent dust
    uint256 private constant MAX_INCENTIVE_RATE = 1e36; // already in existing code

    // Improving the existing _processIncentives function
    function _processIncentives(bytes calldata pubkey, uint256 bgtEmitted) internal {
        // ... existing code ...

        unchecked {
            for (uint256 i; i < whitelistedTokensCount; ++i) {
                // ...

                // Recommend using FixedPointMathLib
                uint256 amount = FixedPointMathLib.mulDiv(bgtEmitted, incentive.incentiveRate, PRECISION);

                uint256 amountRemaining = incentive.amountRemaining;
                amount = FixedPointMathLib.min(amount, amountRemaining);

                uint256 validatorShare;
                if (amount > 0) {
                    validatorShare = beraChef.getValidatorIncentiveTokenShare(pubkey, amount);

                    // Verification: check that the validator share does not exceed the total amount
                    require(validatorShare <= amount, "Invalid share calculation");

                    amount -= validatorShare;
                }
            }

            // ... rest of the code ...
        }
    }

    // ... existing code ...
}
```

{% endcode %}

{% code overflow="wrap" %}

```solidity
// Improving the earned function in the existing StakingRewards.sol
contract StakingRewards is ... {
    // ... existing code ...

    // Guideline 3: User-favorable rounding
    function earned(address account) public view virtual returns (uint256) {
        Info storage info = _accountInfo[account];
        // ... existing code ...

        // Before: return unclaimedReward + FixedPointMathLib.fullMulDiv(balance, rewardPerTokenDelta, PRECISION);
        // After: Apply user-favorable rounding
        uint256 earnedAmount = FixedPointMathLib.fullMulDiv(balance, rewardPerTokenDelta, PRECISION);

        // If balance > 0 but calculated amount is 0, guarantee minimum value
        // Prevents division results from becoming 0, defending against precision-related vulnerabilities (reference)
        if (balance > 0 && earnedAmount == 0 && rewardPerTokenDelta > 0) {
            earnedAmount = 1; // Guarantee at least 1 wei
        }

        return unclaimedReward + earnedAmount;
    }

    // Guideline 1: Add reward calculation verification function
    function _verifyRewardCalculation(uint256 reward, uint256 totalSupply) internal pure {
        // Verify accuracy with reverse calculation
        if (totalSupply > 0 && reward > 0) {
            uint256 reverseCalc = FixedPointMathLib.fullMulDiv(reward, PRECISION, totalSupply);
            // Check if the error is within 0.01%
            require((reverseCalc <= rewardRate * 10001) / (10000 && rewardRate * 10001 / 10000 <= reverseCalc), "Calculation error");
        }
    }

    // ... existing code ...
}
```

{% endcode %}

---

### Threat 7: Double accumulation of rewards by withdrawing all LP tokens and calling notifyRewardAmount

After calling `notifyRewardAmount`, withdrawing all LP tokens to make the balance zero can cause the reward balance to accumulate twice, leading to an abnormal increase in the total recorded rewards. If staking resumes, the APR could spike, and if the allowance is insufficient, an `InsolventReward` revert could occur.\
Conversely, if `notifyRewardAmount` is called when the LP token balance is zero, the rewards for that period may not carry over and could be lost.

#### Impact

`Low`

This can cause a temporary calculation error in the reward distribution logic or cause rewards to be lost or duplicated, but the probability of `totalSupply` becoming zero is low, so it is assessed as 'Low'.

#### Guideline

> - **Prevent `totalSupply` from becoming zero by requiring a minimum LP token deposit when creating a reward vault.**

#### Best Practice

`Custom Code`

{% code overflow="wrap" %}

```solidity
// Apply minimum LP token deposit requirement
contract RewardVaultFactory {
    // ... existing code ...

    // Set minimum initial LP token deposit amount
    uint256 public constant MIN_INITIAL_LP_AMOUNT = 1e6; // e.g., LP token

    // Track whether initial LP has been deposited
    mapping(address => bool) public initialLPDeposited;

    // Modify the existing createRewardVault function
    function createRewardVault(
        address stakingToken,
        uint256 initialLPAmount
    ) external returns (address) {
        // ... existing validation logic ...

        // Validate minimum LP token deposit amount
        require(initialLPAmount >= MIN_INITIAL_LP_AMOUNT, "Initial LP too low");

        // Create vault
        address vault = LibClone.deployDeterministicERC1967BeaconProxy(beacon, salt);

        // ... initialize vault ...

        // Deposit initial LP tokens
        IERC20(stakingToken).safeTransferFrom(msg.sender, vault, initialLPAmount);
        RewardVault(vault).depositInitialLP(initialLPAmount);

        initialLPDeposited[vault] = true;
        emit InitialLPDeposited(vault, stakingToken, initialLPAmount);

        return vault;
    }

    // ... existing code ...
}
```

{% endcode %}

{% code overflow="wrap" %}

```solidity
contract RewardVault is RewardVault {
    // ... existing code ...

    bool public initialDeposited;

    function depositInitialLP(uint256 amount) external {
        // Can only be called once at creation
        require(!initialDeposited, "Already deposited");

        _deposit(msg.sender, amount);

        initialDeposited = true;
    }

    // ...
}
```

{% endcode %}

---

### Threat 8: Reward suspension due to normal removal of an incentive token

When a valid incentive token is removed, it can cause sudden user confusion due to the suspension of rewards and potential issues arising from changes to the reward structure.

#### Impact

`Low`

If an administrator removes an incentive while users are still eligible for rewards, those users will lose their rewards. However, since the administrator is determined by governance, the likelihood of this happening is low, so it is assessed as 'Low'.

#### Guideline

> - **Incentive token removal or replacement should be queued and applied after a delay (3 hours).**
>
>   - This is to align with the maximum reward claim delay of [3 hours (MAX_REWARD_CLAIM_DELAY)](../../reference.md#undefined-3) in the `BGTIncentiveDistributor`.
>
>     ```solidity
>     // BGTIncentiveDistributor.sol
>     uint64 public constant MAX_REWARD_CLAIM_DELAY = 3 hours;
>     ```
>
>   - To be added to the queue, it must pass validation logic.
>     - [Incentive Token Removal](../../reference.md#undefined-4)
>       - The current balance of the incentive token must be zero.
>       - Must be the `FactoryVaultManager`.
>       - The token to be removed must be on the whitelist.
>     - Adding an Incentive Token
>       - Only `FactoryOwner` can add.
>   - `addIncentive` cannot be called for a token in the removal queue.
>
> - **Changes to the reward vault's structure (adding/removing tokens) must be clearly communicated to users in advance and displayed on the UI.**
>   - Create a bot that listens for `IncentiveTokenWhitelisted` and `IncentiveTokenRemoved` events to display a popup on the protocol's website when a change occurs.

#### Best Practice

`Custom Code`

{% code overflow="wrap" %}

```solidity
// 1. Declare state variables and structs
contract RewardVault {
    struct QueuedRequest {
        address token;
        uint256 executionTime;
        bool isRemoval;
    }

    QueuedRequest[] public removalQueue;
    mapping(address => bool) public isQueuedForRemoval;
    uint256 public constant REMOVAL_DELAY = 3 hours;

    // 2. Queue incentive token for removal
    function queueIncentiveRemoval(address token) external onlyFactoryVaultManager {
        require(incentives[token].minIncentiveRate != 0, "Not whitelisted");
        require(!isQueuedForRemoval[token], "Already queued");
        require(incentives[token].amountRemaining == 0, "Incentives remain");

        removalQueue.push(QueuedRequest({
            token: token,
            executionTime: block.timestamp + REMOVAL_DELAY,
            isRemoval: true
        }));
        isQueuedForRemoval[token] = true;

        emit IncentiveRemovalQueued(token, block.timestamp + REMOVAL_DELAY);
    }

    // 3. Process the removal from the queue
    function processIncentiveRemoval(uint256 queueIndex) external {
        QueuedRequest storage request = removalQueue[queueIndex];
        require(block.timestamp >= request.executionTime, "Delay not over");
        require(request.isRemoval, "Not a removal request");

        _removeIncentiveToken(request.token);

        // Remove from queue
        // (Implementation for removing from array)
    }

    function _removeIncentiveToken(address token) internal {
        // ... (existing removal logic) ...
        isQueuedForRemoval[token] = false;
    }

    // Prevent adding incentives to tokens queued for removal
    function addIncentive(...) {
        require(!isQueuedForRemoval[token], "Queued for removal");
        // ...
    }
}
```

{% endcode %}

<br>

---

Footnotes
[^1]: The core reward claim function, ensuring state synchronization with `onlyOperatorOrUser` access control and the `updateReward` modifier.
