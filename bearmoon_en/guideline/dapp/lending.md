---
icon: plane-arrival
---

# dApp Security Guidelines: Lending

<table><thead><tr><th width="495.3115234375">Threat</th><th width="215.7291259765625" align="center">Impact</th></tr></thead><tbody><tr><td><a data-mention href="lending.md#id-1">#1 Vicious Cycle of Mass Liquidation Leading to Collateral Price Drops and Triggering Further Liquidations</a></td><td align="center"><code>Medium</code></td></tr><tr><td><a data-mention href="lending.md#id-2-erc-4626">#2 ERC-4626 Inflation Attack</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="lending.md#id-3-recovery-mode">#3 Incompleteness of Recovery Mode Status Judgment and Transition Mechanism</a></td><td align="center"><code>Low</code></td></tr><tr><td><a data-mention href="lending.md#id-4-owner">#4 System Integrity Violation due to Owner Privilege Abuse</a></td><td align="center"><code>Low</code></td></tr></tbody></table>

### <a href="#id-1" id="id-1"></a>Threat 1: Vicious Cycle of Mass Liquidation Leading to Collateral Price Drops and Triggering Further Liquidations

A large-scale liquidation triggers a sharp drop in the price of collateral assets, which in turn causes a chain reaction that triggers more position liquidations. This vicious cycle results in the loss of users' collateral assets and the creation of bad debt for the protocol.

#### Impact

`Medium`

It forces excessive collateral losses on users and, in severe cases, can leave the protocol with unrecoverable bad debt, leading to system insolvency. The probability of occurrence exists depending on market conditions, and [past cases](../../reference.md#wonderland-dao) show that the damage can be fatal, so it is rated `Medium`.

#### Guideline

> - **[Chain Reaction](../../reference.md#undefined-10) Prevention Mechanism**
>
>   - Restrict collateral repayment in Recovery Mode.
>
>     ```solidity
>     function _requireValidAdjustmentInCurrentMode(...) {...
>          // Collateral repayment is not allowed in recoveryMode
>          if (_isRecoveryMode) {
>             require(_collWithdrawal == 0, "BorrowerOps: Collateral withdrawal not permitted in Recovery Mode");
>             if (_isDebtIncrease) {
>                 _requireICRisAboveCCR(newICR);
>                 _requireNewICRisAboveOldICR(newICR, oldICR);
>             }
>             ...
>     }
>
>     // Closing a loan position is not allowed in recoveryMode
>     function closeDen(...) {
>     ...
>     require(!isRecoveryMode, "BorrowerOps: Operation not permitted during Recovery Mode");
>     }
>     ```
>
> - **Dynamic Risk Parameters**
>
>   - Mechanism to lower the liquidation threshold during recoveryMode.
>
>     ```solidity
>     function liquidateDens(..) {
>
>     // In normal mode
>     if (ICR <= _LSP_CR_LIMIT) {
>         singleLiquidation = _liquidateWithoutSP(denManager, account);
>         _applyLiquidationValuesToTotals(totals, singleLiquidation);
>     } else if (ICR < applicableMCR) {
>         singleLiquidation = _liquidateNormalMode(
>             denManager,
>             account,
>             debtInStabPool,
>             denManagerValues.sunsetting
>         );
>         debtInStabPool -= singleLiquidation.debtToOffset;
>         _applyLiquidationValuesToTotals(totals, singleLiquidation);
>     } else break; // break if the loop reaches a Den with ICR >= MCR
>
>     // In recoveryMode
>     // Check recoveryMode (CCR > TCR) && check if it's a liquidation target (ICR < TCR)
>
>     {
>         uint256 TCR = BeraborrowMath._computeCR(entireSystemColl, entireSystemDebt);
>         if (TCR >= borrowerOperations.BERABORROW_CORE().CCR() || ICR >= TCR)
>             break;
>     }
>
>     // If recoveryMode is on and the Den's ICR is less than TCR, proceed with liquidation
>     singleLiquidation = _tryLiquidateWithCap(
>         denManager,
>         account,
>         debtInStabPool,
>         _getApplicableMCR(account, denManagerValues),
>         denManagerValues.price
>     );
>     ```

#### **Best practice**

[**`LiquidationManager.sol`**](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Beraborrow/src/core/LiquidationManager.sol#L331-L368)

[**`BorrowOperations.sol`**](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Beraborrow/src/core/BorrowerOperations.sol#L413-L423)

---

### <a href="#id-2-erc-4626" id="id-2-erc-4626"></a>Threat 2: [ERC-4626 Inflation](../../reference.md#erc-4626) Attack

When the total supply of an ERC-4626 vault is nearly zero, an attacker deposits a very small amount of shares and then directly transfers assets to the vault to inflate the value of their shares. Subsequent users who deposit will receive far fewer shares due to the inflated share price, effectively having their assets stolen by the attacker. Similar [past cases](https://blog.openzeppelin.com/a-novel-defense-against-erc4626-inflation-attacks) exist.

#### Impact

`Low`

If it occurs, it would have a significant impact, but the likelihood of the LSP supply being zero, the attacker inflating the share value, and a subsequent user depositing tokens is low, so it is rated `Low`.

#### Guideline

> - **Implement Virtual Shares Mechanism**
>   - Set up virtual shares and assets during initial deployment.
>   - [Apply OpenZeppelin's 9-digit decimal offset](https://github.com/OpenZeppelin/openzeppelin-contracts/pull/3979).
>   - Enforce a minimum deposit threshold to receive at least 69 shares, like $NECT ([OpenZeppelin recommendation](https://docs.openzeppelin.com/contracts/5.x/erc4626): at least 100 shares).
> - **Enhance Bootstrap Period Protection**
>   - Apply `whenNotBootstrapPeriod` to `deposit()` and `mint()` functions.
>   - Detect `totalSupply ≈ 0` state and activate automatic protection mode.

#### Best Practice

[`LiquidStabilityPool.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Beraborrow/src/core/LiquidStabilityPool.sol#L131-L134)

```solidity
modifier whenNotBootstrapPeriod() {
        _whenNotBootstrapPeriod();
        _;
    }
```

[`LiquidStabilityPool.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Beraborrow/src/core/LiquidStabilityPool.sol#L136-L149)

```solidity
function _whenNotBootstrapPeriod() internal view {
    // BoycoVaults should be able to unwind in the case ICR closes MCR
    ILiquidStabilityPool.LSPStorage storage $ = _getLSPStorage();

    if (
        block.timestamp < $.metaBeraborrowCore.lspBootstrapPeriod()
        && !$.boycoVault[msg.sender]
    ) revert BootstrapPeriod();
}
```

[`BaseCollateralVault.sol`](https://github.com/wiimdy/bearmoon/blob/1e6bc4449420c44903d5bb7a0977f78d5e1d4dff/Beraborrow/src/core/vaults/BaseCollateralVault.sol#L101C4-L103C6)

```solidity
function _decimalsOffset() internal view override virtual returns (uint8) {
        return 18 - assetDecimals();
    }
```

`Custom Code`

{% code overflow="wrap" %}

```solidity
// Prevents totalSupply from becoming 0.

constructor(address _assetToken) {
    if (_assetToken == address(0)) {
        revert("Zero address provided for asset token");
    }
    asset = IERC20(_assetToken);

    // These shares are effectively burned, but are included in the totalSupply calculation.
    totalSupply = LOCKED_SHARES;
    balanceOf[address(0)] = LOCKED_SHARES;
    ...
}

function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
// Guideline: Set a minimum deposit threshold & enhance bootstrap period protection
if (block.timestamp < bootstrapEndTime) {
    // Bootstrap period: apply a stricter minimum deposit
    require(assets >= MIN_DEPOSIT_BOOTSTRAP, "Deposit amount below bootstrap period minimum");
} else {
    // Normal period: apply the normal minimum deposit
    require(assets >= MIN_DEPOSIT_NORMAL, "Deposit amount below normal minimum");
}
```

{% endcode %}

---

### <a href="#id-3-recovery-mode" id="id-3-recovery-mode"></a>Threat 3: Incompleteness of Recovery Mode Status Judgment and Transition Mechanism

An error in the logic for judging or transitioning into Recovery Mode can make the system appear to be functioning normally when it is actually in a dangerous state, allowing for additional bad loans and magnifying losses.

If an attacker bypasses the collateral ratio (ICR/TCR) verification logic and takes out an excessive loan while the system is in [Recovery Mode](../../reference.md#recovery-mode-1), that loan is at very high risk of becoming bad debt.

#### Impact

`Low`

A failure in the Recovery Mode transition logic can lead to bad loans, causing potential losses for the protocol. There have been [cases of errors](https://medium.com/linum-labs/black-thursday-makerdaos-multi-collateral-dai-exploitation-and-the-plan-to-recover-c083c0b81875) during Recovery Mode entry in MakerDAO's MCD system. However, strong safeguards such as a ban on collateral withdrawal and multiple collateral ratio (ICR/TCR) verifications are already in place, making the probability of a successful attack low. Therefore, it is rated `Low`.

#### Guideline

> - **Simultaneous verification of individual ICR (Individual Collateral Ratio) and system TCR (Total Collateral Ratio) for all position changes.**
> - [**Mode Transition Stability**](../../reference.md#recovery-mode)
>   - Ensure the latest prices and interest are reflected when calculating TCR.
>   - Bulk update all position states during a mode transition.

#### Best Practice

[`BorrowerOperations.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Beraborrow/src/core/BorrowerOperations.sol#L182-L184)

{% code overflow="wrap" %}

```solidity
// Check current TCR
function checkRecoveryMode(uint256 TCR) public view returns (bool) {
    return TCR < BERABORROW_CORE.CCR();
}

// Apply different standards based on the protection mode
if (isRecoveryMode) {
    _requireICRisAboveCCR(vars.ICR);
} else {
    _requireICRisAboveMCR(vars.ICR, denManager.MCR(), account);
    uint256 newTCR = _getNewTCRFromDenChange(
        vars.totalPricedCollateral,
        vars.totalDebt,
        _collateralAmount * vars.price,
        true,
        vars.compositeDebt,
        true
    ); // bools: coll increase, debt increase
    _requireNewTCRisAboveCCR(newTCR);
}
```

{% endcode %}

[`BeraborrowOperations.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Beraborrow/src/core/BorrowerOperations.sol#L511-L530)

{% code overflow="wrap" %}

```solidity
if (_isRecoveryMode) {
    require(_collWithdrawal == 0, "BorrowerOps: Collateral withdrawal not permitted in Recovery Mode");
    if (_isDebtIncrease) {
        _requireICRisAboveCCR(newICR);
        _requireNewICRisAboveOldICR(newICR, oldICR);
    }
} else {
    _requireICRisAboveMCR(newICR, _vars.MCR, _vars.account);
    _requireNewTCRisAboveCCR(newTCR);
}
```

{% endcode %}

---

### <a href="#id-4-owner" id="id-4-owner"></a>Threat 4: System Integrity Violation due to Owner Privilege Abuse

If the Owner abuses their authority to maliciously change the protocol's critical parameters, users will suffer direct economic losses, such as paying unexpected excessive fees and facing increased risks of asset liquidation.

#### Impact

`Low`

Malicious parameter changes by the Owner are a serious threat that can cause direct financial loss to users. As seen in [past DeFi cases](https://medium.com/@alymarguerite/wonderland-dao-too-good-to-be-true-8832313aff81), this includes not only technical vulnerabilities but also '[governance risks](../../reference.md#wonderland-dao)' where a trusted core group turns malicious. However, since these privileges are controlled by multi-signature and Timelock mechanisms, the actual probability of success is low, so it is rated `Low`.

#### Guideline

> - **Decentralization of Governance Authority**
>   - [Apply multi-sig + timelock to all critical parameter changes](../../reference.md#owner)
>   - Prohibit changing the `paused` state except in emergencies
>   - Announce price feed changes
> - **Parameter Change Restrictions**
>   - Limit the maximum increase/decrease when changing MCR and CCR
>   - Limit the number of monthly fee changes
>   - Require community vote for system address changes
> - **Interest Rate Governance Protection**
>   - Apply a 7-day timelock for interest rate changes
>   - Limit the range of interest rate changes
>   - Require community vote for interest rate changes
> - **Interest Calculation Transparency**
>   - Make all interest calculations publicly verifiable on-chain
>   - Prevent overflow in the interest accrual logic
>   - Ensure traceability and auditability of interest rate change history

#### Best Practice

[`DenManager.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Beraborrow/src/core/DenManager.sol#L254-L257)

{% code overflow="wrap" %}

```solidity
require((_paused && msg.sender == guardian()) || msg.sender == owner(), "Unauthorized");
```

{% endcode %}

[`DenManager.sol`](https://github.com/wiimdy/bearmoon/blob/c5ff9117fc7b326375881f9061cbf77e1ab18543/Beraborrow/src/core/DenManager.sol#L326-L336)

{% code overflow="wrap" %}

```solidity
uint256 newInterestRate = (INTEREST_PRECISION * params.interestRateInBps) / (BP * SECONDS_IN_YEAR);
if (newInterestRate != interestRate) {
    _accrueActiveInterests();
    // accrual function doesn't update timestamp if interest was 0
    lastActiveIndexUpdate = block.timestamp;
    interestRate = newInterestRate;
}
```

{% endcode %}

---
