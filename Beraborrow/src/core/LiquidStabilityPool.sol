// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {ERC4626Upgradeable, ERC20Upgradeable, IERC20, Math, SafeERC20} from "@openzeppelin-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {UUPSUpgradeable} from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {PriceLib} from "../libraries/PriceLib.sol";
import {TokenValidationLib} from "../libraries/TokenValidationLib.sol";
import {EmissionsLib} from "../libraries/EmissionsLib.sol";
import {FeeLib} from "../libraries/FeeLib.sol";
import {BeraborrowMath} from "../dependencies/BeraborrowMath.sol";
import {ILiquidStabilityPool} from "../interfaces/core/ILiquidStabilityPool.sol";
import {IPriceFeed} from "../interfaces/core/IPriceFeed.sol";
import {IDebtToken} from "../interfaces/core/IDebtToken.sol";
import {IBeraborrowCore} from "../interfaces/core/IBeraborrowCore.sol";
import {IRebalancer} from "../interfaces/utils/integrations/IRebalancer.sol";
import {IAsset} from "../interfaces/utils/tokens/IAsset.sol";


/**
    @title Beraborrow Stability Pool
    @notice Based on Liquity's `StabilityPool`
            https://github.com/liquity/dev/blob/main/packages/contracts/contracts/StabilityPool.sol

            Beraborrow's implementation is modified to support multiple collaterals. Deposits into
            the liquid stability pool may be used to liquidate any supported collateral type.
 */
contract LiquidStabilityPool is ERC4626Upgradeable, UUPSUpgradeable {
    using Math for uint;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using PriceLib for uint;
    using TokenValidationLib for address;
    using TokenValidationLib for address[];
    using EmissionsLib for EmissionsLib.BalanceData;
    using EmissionsLib for EmissionsLib.EmissionSchedule;
    using SafeCast for uint;
    using FeeLib for uint;

    uint128 public constant SUNSET_DURATION = 7 days;
    uint constant WAD = 1e18;
    uint constant BP = 1e4;

    // keccak256(abi.encode(uint(keccak256("openzeppelin.storage.LiquidStabilityPool")) - 1)) & ~bytes32(uint(0xff))
    bytes32 private constant LiquidStabilityPoolStorageLocation = 0x3c2bbd5b01c023780ac7877400fd851b17fd98c152afdb1efc02015acd68a300;

    function _getLSPStorage() internal pure returns (ILiquidStabilityPool.LSPStorage storage store) {
        assembly {
            store.slot := LiquidStabilityPoolStorageLocation
        }
    }

    event CollateralOverwritten(address oldCollateral, address newCollateral);
    event AssetsWithdraw(
        address indexed receiver,
        uint shares,
        address[] tokens,
        uint[] amounts
    );
    event ExtraAssetAdded(address token);
    event ExtraAssetRemoved(address token);
    event ProtocolRegistered(
        address indexed factory,
        address indexed liquidationManager
    );
    event ProtocolBlacklisted(address indexed factoryRemoved, address indexed LMremoved);
    event Offset(address collateral, uint debtToOffset, uint collToAdd, uint collSurplusAmount);
    event Rebalance(address indexed sentCurrency, address indexed receivedCurrency, uint sentAmount, uint receivedAmount, uint sentValue, uint receivedValue);

    error AddressZero();
    error NoPriceFeed();
    error OnlyOwner();
    error TokenCannotBeNect();
    error TokenCannotBeExtraAsset();
    error CallerNotFactory();
    error CollateralIsSunsetting();
    error ExistingCollateral();
    error CollateralMustBeSunset();
    error BalanceRemaining();
    error Paused();
    error BootstrapPeriod();
    error InvalidArrayLength();
    error LastTokenMustBeNect();
    error CallerNotLM();
    error SameTokens();
    error BelowThreshold();
    error ZeroTotalSupply();
    error TokenMustBeExtraAsset();
    error TokenIsVesting();
    error InvalidThreshold();
    error FactoryAlreadyRegistered();
    error LMAlreadyRegistered();
    error FactoryNotRegistered();
    error LMNotRegistered();
    error WithdrawingLockedEmissions();

    constructor() {
        _disableInitializers();
    }

    function initialize(ILiquidStabilityPool.InitParams calldata params) initializer external {
        ILiquidStabilityPool.LSPStorage storage $ = _getLSPStorage();

        if (address(params._metaBeraborrowCore) == address(0) || params._liquidationManager == address(0) || params._factory == address(0)) {
            revert AddressZero();
        }
        
        $.metaBeraborrowCore = params._metaBeraborrowCore;
        $.feeReceiver = params._feeReceiver;

        _registerProtocol(
            $,
            address(params._liquidationManager),
            address(params._factory)
        );

        IPriceFeed priceFeed = IPriceFeed(params._metaBeraborrowCore.priceFeed());
        if (priceFeed.fetchPrice(address(params._asset)) == 0) revert NoPriceFeed();

        __ERC20_init(params._sharesName, params._sharesSymbol);
        __ERC4626_init(params._asset);
    }

    modifier onlyOwner {
        _onlyOwner();
        _;
    }

    modifier whenNotBootstrapPeriod() {
        _whenNotBootstrapPeriod();
        _;
    }

    function _onlyOwner() private view {
        // Owner is beacon variable MetaBeraborrowCore::owner()
        if (msg.sender != _getLSPStorage().metaBeraborrowCore.owner()) revert OnlyOwner();
    }

    function _whenNotBootstrapPeriod() internal view {
        // BoycoVaults should be able to unwind in the case ICR closes MCR
        ILiquidStabilityPool.LSPStorage storage $ = _getLSPStorage();
            
        if (
            block.timestamp < $.metaBeraborrowCore.lspBootstrapPeriod()
            && !$.boycoVault[msg.sender]
        ) revert BootstrapPeriod();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function enableCollateral(address _collateral, uint64 _unlockRatePerSecond, bool forceThroughBalanceCheck) external {
        ILiquidStabilityPool.LSPStorage storage $ = _getLSPStorage();

        if (_collateral == asset()) revert TokenCannotBeNect();
        if (!$.factoryProtocol[msg.sender]) revert CallerNotFactory();
        if ($.extraAssets.contains(_collateral)) revert TokenCannotBeExtraAsset();

        uint length = $.collateralTokens.length;
        bool collateralEnabled;

        $.balanceData.setUnlockRatePerSecond(_collateral, _unlockRatePerSecond);
        for (uint i; i < length; i++) {
            if ($.collateralTokens[i] == _collateral) {
                collateralEnabled = true;
                break;
            }
        }

        if (!collateralEnabled) {
            ILiquidStabilityPool.Queue memory queueCached = $.queue;
            if (
                queueCached.nextSunsetIndexKey > queueCached.firstSunsetIndexKey
            ) {
                ILiquidStabilityPool.SunsetIndex memory sIdx = $._sunsetIndexes[
                    queueCached.firstSunsetIndexKey
                ];
                if (sIdx.expiry < block.timestamp) {
                    delete $._sunsetIndexes[$.queue.firstSunsetIndexKey++];
                    _overwriteCollateral(_collateral, sIdx.idx, forceThroughBalanceCheck);
                    return;
                }
            }
            $.collateralTokens.push(_collateral);
            $.indexByCollateral[_collateral] = $.collateralTokens.length;
        } else {
            bool isSunsetting = $.indexByCollateral[_collateral] == 0;
            
            if (isSunsetting) {
                revert CollateralIsSunsetting();
            } else {
                revert ExistingCollateral();
            }
        }
    }

    /// @dev When a collateral is overwritten it will stop being tracked on totalAssets and withdraws, a total rebalance is needed
    function _overwriteCollateral(address _newCollateral, uint idx, bool forceThroughBalanceCheck) internal {
        ILiquidStabilityPool.LSPStorage storage $ = _getLSPStorage();

        if($.indexByCollateral[_newCollateral] != 0) revert CollateralMustBeSunset();

        address oldCollateral = $.collateralTokens[idx];
        if ($.balanceData.balance[oldCollateral] != 0 && !forceThroughBalanceCheck) revert BalanceRemaining();
        $.indexByCollateral[_newCollateral] = idx + 1;
        $.collateralTokens[idx] = _newCollateral;

        emit CollateralOverwritten(oldCollateral, _newCollateral);
    }

    /**
     * @notice Starts sunsetting a collateral
     *         During sunsetting liquidated collateral handoff to the SP will revert
        @dev IMPORTANT: When sunsetting a collateral, `DenManager.startSunset`
                        should be called on all DM linked to that collateral
        @param collateral Collateral to sunset
     */
    function startCollateralSunset(address collateral) external onlyOwner {
        ILiquidStabilityPool.LSPStorage storage $ = _getLSPStorage();

        if ($.indexByCollateral[collateral] == 0) revert CollateralIsSunsetting();

        $._sunsetIndexes[$.queue.nextSunsetIndexKey++] = ILiquidStabilityPool.SunsetIndex(
            uint128($.indexByCollateral[collateral] - 1),
            uint128(block.timestamp + SUNSET_DURATION)
        );
        delete $.indexByCollateral[collateral];
    }

    /** @dev See {IERC4626-totalAssets}. */
    /// @dev AmountInNect is scaled to 18 decimals, since its NECT decimals
    /// @dev Substracts balances locked emissions
    function totalAssets() public view override returns (uint amountInNect) {
        ILiquidStabilityPool.LSPStorage storage $ = _getLSPStorage();

        uint amountInUsd;
        address[] memory collaterals = getCollateralTokens();
        uint nectPrice = getPrice(asset());

        uint collateralsLength = collaterals.length;
        uint extraAssetsLength = $.extraAssets.length();

        // we directly use `$.balanceData.balance[]` instead of `$.balanceOf` because NECT can't be an extra asset, neither a collateral, which are the only ones that can be locked through `addEmissions()`
        // this comment applies to all instances of `$.balanceData.balance[asset()]`
        // assumes NECT is 18 decimals
        uint nectBalance = $.balanceData.balance[asset()];

        for (uint i; i < collateralsLength; i++) {
            address collateral = collaterals[i];
            uint balance = $.balanceData.balanceOf(collateral);

            if (balance > 0) {
                amountInUsd += balance.convertToValue(getPrice(collateral), IAsset(collateral).decimals());
            }
        }

        for (uint i; i < extraAssetsLength; i++) {
            address token = $.extraAssets.at(i);
            uint balance = $.balanceData.balanceOf(token);

            if (balance > 0) {
                amountInUsd += balance.convertToValue(getPrice(token), IAsset(token).decimals());
            }
        }

        amountInNect = amountInUsd * WAD / nectPrice + nectBalance;
    }

    function getPrice(
        address token
    ) public view returns (uint scaledPriceInUsdWad) {
        IPriceFeed priceFeed = IPriceFeed(_getLSPStorage().metaBeraborrowCore.priceFeed());
        return priceFeed.fetchPrice(token);
    }

    function deposit(
        uint assets,
        address receiver
    ) public override returns (uint shares) {
        ILiquidStabilityPool.LSPStorage storage $ = _getLSPStorage();

        if ($.metaBeraborrowCore.paused()) revert Paused();

        (uint rawShares, uint feeShares) = _previewDeposit(assets);
        shares = rawShares - feeShares;

        _depositAndMint($, shares, assets, receiver, feeShares);
    }

    function mint(
        uint shares,
        address receiver
    ) public override returns (uint assets) {
        ILiquidStabilityPool.LSPStorage storage $ = _getLSPStorage();

        if ($.metaBeraborrowCore.paused()) revert Paused();

        assets = previewMint(shares);

        uint fee = shares.mulDiv(BP, BP - _entryFeeBP(), Math.Rounding.Up) - shares;

        _depositAndMint($, shares, assets, receiver, fee);
    }

    function _depositAndMint(ILiquidStabilityPool.LSPStorage storage $, uint shares, uint assets, address receiver, uint fee) private {
        // Here we pass 'assets' since it is the amount of Nect we want to transfer to the LSP
        _provideFromAccount(msg.sender, assets);

        if (fee != 0) {
            _mint($.feeReceiver, fee);
        }

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function withdraw(
        uint assets,
        address receiver,
        address _owner
    ) public whenNotBootstrapPeriod override returns (uint shares) {
        ILiquidStabilityPool.LSPStorage storage $ = _getLSPStorage();
            
        uint _totalSupply = totalSupply();

        uint maxAssets = maxWithdraw(_owner);
        if (assets > maxAssets) revert ERC4626ExceededMaxWithdraw(_owner, assets, maxAssets);

        shares = previewWithdraw(assets);

        (uint nectAmount, uint fee) = _burn($, shares, _totalSupply, _owner);

        _withdraw(nectAmount, receiver, shares - fee, _totalSupply, _owner, assets, shares);
    }

    function redeem(
        uint shares,
        address receiver,
        address _owner
    ) public whenNotBootstrapPeriod override returns (uint assets) {
        ILiquidStabilityPool.LSPStorage storage $ = _getLSPStorage();

        uint _totalSupply = totalSupply();

        uint maxShares = maxRedeem(_owner);
        if (shares > maxShares) revert ERC4626ExceededMaxRedeem(_owner, shares, maxShares);

        assets = previewRedeem(shares);

        (uint nectAmount, uint fee) = _burn($, shares, _totalSupply, _owner);

        _withdraw(nectAmount, receiver, shares - fee, _totalSupply, _owner, assets, shares);
    }

    function _withdraw(uint nectAmount, address receiver, uint cachedShares, uint _totalSupply, address _owner, uint assets, uint shares) private {
        _withdrawFromAccount(nectAmount, receiver);
        _withdrawCollAndExtraAssets(receiver, cachedShares, _totalSupply);

        emit Withdraw(msg.sender, receiver, _owner, assets, shares);
    }

    function withdraw(
        uint assets,
        address[] calldata preferredUnderlyingTokens,
        address receiver,
        address _owner
    ) public whenNotBootstrapPeriod returns (uint shares) {
        ILiquidStabilityPool.LSPStorage storage $ = _getLSPStorage();

        uint maxAssets = maxWithdraw(_owner);
        if (assets > maxAssets) revert ERC4626ExceededMaxWithdraw(_owner, assets, maxAssets);
        
        /// @dev should we have a check for assets == 0? its redundant but gas will be low
        shares = previewWithdraw(assets);

        // Pass totalSupply as 0 since we don't need to calculate `nectAmount`
        _burn($, shares, 0, _owner);

        _withdrawPreferredUnderlying($, assets, preferredUnderlyingTokens, receiver);

        emit Withdraw(msg.sender, receiver, _owner, assets, shares);
    }

    function redeem(
        uint shares,
        address[] calldata preferredUnderlyingTokens,
        address receiver,
        address _owner
    ) public whenNotBootstrapPeriod returns (uint assets) {
        ILiquidStabilityPool.LSPStorage storage $ = _getLSPStorage();

        uint maxShares = maxRedeem(_owner);
        if (shares > maxShares) revert ERC4626ExceededMaxRedeem(_owner, shares, maxShares);

        assets = previewRedeem(shares);

        // Pass totalSupply as 0 since we don't need to calculate `nectAmount`
        _burn($, shares, 0, _owner);

        _withdrawPreferredUnderlying($, assets, preferredUnderlyingTokens, receiver);

        emit Withdraw(msg.sender, receiver, _owner, assets, shares);
    }

    function _burn(ILiquidStabilityPool.LSPStorage storage $, uint shares, uint _totalSupply, address _owner) private returns (uint nectAmount, uint fee) {
        fee = shares.feeOnRaw(_exitFeeBP());

        if (msg.sender != _owner) {
            _spendAllowance(_owner, msg.sender, shares);
        }

        /// @dev Always round in favor of the vault
        if (_totalSupply != 0) {
            nectAmount = (shares - fee).mulDiv($.balanceData.balance[asset()], _totalSupply, Math.Rounding.Down);
        }

        // We could remove fee > 0 if we deploy with fees and the minimum fee is not 0
        if (fee != 0) {
            _mint($.feeReceiver, fee);
        }

        _burn(_owner, shares);
    }

    /// @dev No token validation is needed, if token is not collateral or extraAsset, it will underflow in `$balance[token]`
    /// @dev Reentrancy attack vector should not be possible since user has their shares burned before the calls to tokens
    /// @dev No duplicated token check needed
    function _withdrawPreferredUnderlying(
        ILiquidStabilityPool.LSPStorage storage $,
        uint assets,
        address[] memory preferredUnderlyingTokens,
        address receiver
    ) internal {
        // Avoid stack too deep error
        ILiquidStabilityPool.Arrays memory arr = _initArrays(preferredUnderlyingTokens);

        if (arr.length != $.extraAssets.length() + arr.collateralsLength + 1) revert InvalidArrayLength();
        if (preferredUnderlyingTokens[arr.length - 1] != asset()) revert LastTokenMustBeNect();
        preferredUnderlyingTokens.checkForDuplicates(arr.length);

        uint remainingAssets = assets;
        uint nectPrice = getPrice(asset());

        for (uint i; i < arr.length && remainingAssets != 0; i++) {
            address token = preferredUnderlyingTokens[i];

            token.checkValidToken(arr.collaterals, arr.collateralsLength, asset(), $.extraAssets.contains(token));

            uint unlockedBalance = $.balanceData.balanceOf(token);
            if (unlockedBalance == 0) continue;
            uint tokenPrice = getPrice(token);
            // Price could be 0 if CollVault collateral or extraAsset is just added without atomical initial deposit
            // Would result in less assets withdrawn than expected
            if (tokenPrice == 0) continue;
            uint8 tokenDecimals = IAsset(token).decimals();

            uint amount = remainingAssets.convertAssetsToCollAmount(
                tokenPrice,
                nectPrice,
                decimals(), // NECT decimals
                tokenDecimals,
                Math.Rounding.Down
            );

            if (unlockedBalance >= amount) {
                remainingAssets = 0;
                $.balanceData.balance[token] -= amount;
            } else {
                uint remainingColl = amount - unlockedBalance;
                remainingAssets = remainingColl.convertCollAmountToAssets(
                    tokenPrice,
                    nectPrice,
                    decimals(), // NECT decimals
                    tokenDecimals
                );

                amount = unlockedBalance;
                $.balanceData.balance[token] -= amount;
            }
            
            arr.amounts[i] = amount;
        }

        for (uint i; i < arr.length; i++) {
            if(arr.amounts[i] > 0) {
                IERC20(preferredUnderlyingTokens[i]).safeTransfer(receiver, arr.amounts[i]);
            }
        }

        emit AssetsWithdraw(receiver, assets, preferredUnderlyingTokens, arr.amounts);
    }

    function _provideFromAccount(
        address account,
        uint _amount
    ) internal {
        ILiquidStabilityPool.LSPStorage storage $ = _getLSPStorage();

        IDebtToken(asset()).sendToSP(account, _amount);
        $.balanceData.balance[asset()] += _amount;
    }

    function _withdrawFromAccount(
        uint _amount,
        address receiver
    ) internal {
        ILiquidStabilityPool.LSPStorage storage $ = _getLSPStorage();

        IDebtToken(asset()).returnFromPool(address(this), receiver, _amount);
        $.balanceData.balance[asset()] -= _amount;
    }

    /*
     * Cancels out the specified debt against the Debt contained in the Stability Pool (as far as possible)
     */
    function offset(
        address collateral,
        uint _debtToOffset,
        uint _collToAdd
    ) external virtual {
        ILiquidStabilityPool.LSPStorage storage $ = _getLSPStorage();

        if (!$.liquidationManagerProtocol[msg.sender]) revert CallerNotLM();
        
        uint collPrice = getPrice(collateral);
        uint nectPrice = getPrice(asset());
        uint debtInCollateralAmount = _debtToOffset.convertAssetsToCollAmount(
            collPrice,
            nectPrice,
            decimals(),
            IAsset(collateral).decimals(),
            Math.Rounding.Up
        );

        // Unlikely case in which LM offsets more debt value than collateral
        uint collSurplusAmount;
        if (_collToAdd > debtInCollateralAmount) {
            collSurplusAmount = _collToAdd - debtInCollateralAmount;
        }

        if (collSurplusAmount > 0) {
            $.balanceData.addEmissions(address(collateral), collSurplusAmount.toUint128());
        }

        $.balanceData.balance[collateral] += _collToAdd - collSurplusAmount;
        // Cancel the liquidated Debt debt with the Debt in the stability pool
        $.balanceData.balance[asset()] -= _debtToOffset;

        emit Offset(collateral, _debtToOffset, _collToAdd, collSurplusAmount);
    }

    /**
     * @notice Withdraws as much collaterals awaiting conversion as shares being used for NECT withdrawal
     * @param receiver Address to receive the collaterals
     * @param shares Amount of shares being used for NECT withdrawal
     * @param _totalSupply Has shares added to total supply since they have just been burned
     */
    function _withdrawCollAndExtraAssets(
        address receiver,
        uint shares,
        uint _totalSupply
    ) internal {
        ILiquidStabilityPool.LSPStorage storage $ = _getLSPStorage();

        address[] memory collaterals = getCollateralTokens();
        uint collLength = collaterals.length;
        uint extraAssetsLength = $.extraAssets.length();

        uint[] memory amounts = new uint[](collLength + extraAssetsLength);
        address[] memory tokens = new address[](collLength + extraAssetsLength);

        for (uint i; i < collLength; i++) {
            uint balanceWithUnlockedEmissions = $.balanceData.balanceOf(collaterals[i]);
            amounts[i] = shares.mulDiv(balanceWithUnlockedEmissions, _totalSupply, Math.Rounding.Down);
            tokens[i] = collaterals[i];

            $.balanceData.balance[collaterals[i]] -= amounts[i];
        }

        for (uint i; i < extraAssetsLength; i++) {
            uint idx = i + collLength;
            address token = $.extraAssets.at(i);

            uint balanceWithUnlockedEmissions = $.balanceData.balanceOf(token);
            amounts[idx] = shares.mulDiv(balanceWithUnlockedEmissions, _totalSupply, Math.Rounding.Down);
            tokens[idx] = token;

            $.balanceData.balance[token] -= amounts[idx];
        }

        for (uint i; i < tokens.length; i++) {
            if (amounts[i] != 0) {
                IERC20(tokens[i]).safeTransfer(receiver, amounts[i]);
            }
        }

        emit AssetsWithdraw(receiver, shares, tokens, amounts);
    }

    function rebalance(ILiquidStabilityPool.RebalanceParams calldata p) external onlyOwner {
        ILiquidStabilityPool.LSPStorage storage $ = _getLSPStorage();

        if (p.sentCurrency == p.receivedCurrency) revert SameTokens();

        uint sentPrice = getPrice(p.sentCurrency);
        uint receivedPrice = getPrice(p.receivedCurrency);
        uint8 sentDecimals = IAsset(p.sentCurrency).decimals();
        uint8 receivedDecimals = IAsset(p.receivedCurrency).decimals();
        uint sentCurrencyBalance = IAsset(p.sentCurrency).balanceOf(address(this));
        uint receivedCurrencyBalance = IAsset(p.receivedCurrency).balanceOf(address(this));

        // Perform the swap using the swapper contract
        IERC20(p.sentCurrency).safeTransfer(p.swapper, p.sentAmount);
        IRebalancer(p.swapper).swap(
            p.sentCurrency,
            p.sentAmount,
            p.receivedCurrency,
            p.payload
        );

        uint received = IAsset(p.receivedCurrency).balanceOf(address(this)) - receivedCurrencyBalance;
        uint sent = sentCurrencyBalance - IAsset(p.sentCurrency).balanceOf(address(this));

        // if we were to rebalance locked emissions, a possible revert on subsequent `$.balanceOf` calls would occur
        if (sent > $.balanceData.balance[p.sentCurrency] - getLockedEmissions(p.sentCurrency)) revert WithdrawingLockedEmissions();

        uint receivedValue = received.convertToValue(receivedPrice, receivedDecimals);
        uint sentValue = sent.convertToValue(sentPrice, sentDecimals);

        bytes32 hash = keccak256(abi.encodePacked(p.sentCurrency, p.receivedCurrency));
        
        // if threshold isn't set, it will be 0, not tolerating any slippage
        if (receivedValue < sentValue * (BP - $.threshold[hash]) / BP) revert BelowThreshold();

        $.balanceData.balance[p.sentCurrency] -= sent;
        $.balanceData.balance[p.receivedCurrency] += received;

        emit Rebalance(p.sentCurrency, p.receivedCurrency, sent, received, sentValue, receivedValue);
    }

    /**
     * @dev Limited to tokens that are not collaterals or NECT
     * @param token Token to add to the extraAssets
     * @param _unlockRatePerSecond Unlock rate per second once the token is pulled to the LSP
     */
    function addNewExtraAsset(
        address token,
        uint64 _unlockRatePerSecond
    ) external onlyOwner {
        ILiquidStabilityPool.LSPStorage storage $ = _getLSPStorage();

        address[] memory collaterals = getCollateralTokens();
        if (token == asset()) revert TokenCannotBeNect();

        uint enableCollateralLength = collaterals.length;
        for (uint i; i < enableCollateralLength; i++) {
            if (collaterals[i] == token) revert ExistingCollateral();
        }

        if (!$.extraAssets.add(token)) revert TokenCannotBeExtraAsset();
        IPriceFeed priceFeed = IPriceFeed($.metaBeraborrowCore.priceFeed());
        if (priceFeed.fetchPrice(token) == 0) revert NoPriceFeed();

        $.balanceData.setUnlockRatePerSecond(token, _unlockRatePerSecond);

        emit ExtraAssetAdded(token);
    }

    /*
     * @notice Params overwrites the current vesting for the token
     * @dev Adjust the unlockRatePerSecond if we want to keep the fullUnlockTimestamp
     */
    function linearVestingExtraAssets(address token, int amount, address recipient) external onlyOwner {
        ILiquidStabilityPool.LSPStorage storage $ = _getLSPStorage();

        if (totalSupply() == 0) revert ZeroTotalSupply(); // convertToShares will return 0 for 'assets < totalAssets'
        if (!$.extraAssets.contains(token)) revert TokenMustBeExtraAsset();

        if (amount > 0) {
            uint _amount = uint(amount);
            IERC20(token).safeTransferFrom(msg.sender, address(this), _amount);
            $.balanceData.addEmissions(token, _amount.toUint128());
        } else {
            uint _amount = uint(-amount);
            // Note, revert with underflow if amount > `lockedEmissions`
            $.balanceData.subEmissions(token, _amount.toUint128());
            IERC20(token).safeTransfer(recipient, _amount);
        }
    }

    function removeExtraAsset(address token) external onlyOwner {
        ILiquidStabilityPool.LSPStorage storage $ = _getLSPStorage();

        if ($.balanceData.balance[token] != 0) revert BalanceRemaining();
        if ($.balanceData.emissionSchedule[token].unlockTimestamp() >= block.timestamp) revert TokenIsVesting();
        if (!$.extraAssets.remove(token)) revert TokenMustBeExtraAsset();

        emit ExtraAssetRemoved(token);
    }

    function setPairThreshold(address tokenIn, address tokenOut, uint thresholdInBP) external onlyOwner {
        ILiquidStabilityPool.LSPStorage storage $ = _getLSPStorage();

        if (thresholdInBP > BP) revert InvalidThreshold();

        bytes32 hash = keccak256(abi.encodePacked(tokenIn, tokenOut));
        $.threshold[hash] = thresholdInBP;
    }

    function setUnlockRatePerSecond(address token, uint64 _unlockRatePerSecond) external onlyOwner {
        ILiquidStabilityPool.LSPStorage storage $ = _getLSPStorage();

        $.balanceData.setUnlockRatePerSecond(token, _unlockRatePerSecond);
    }

    function setBoycoVaults(address[] calldata _boycoVaults, bool[] calldata enable) external onlyOwner {
        ILiquidStabilityPool.LSPStorage storage $ = _getLSPStorage();

        if (_boycoVaults.length != enable.length) revert InvalidArrayLength();

        for (uint i; i < _boycoVaults.length; i++) {
            address boycoVault = _boycoVaults[i];

            if (boycoVault == address(0)) revert AddressZero();

            $.boycoVault[boycoVault] = enable[i];
        }
    }

    // Preview ERC4626 functions applying entry/exit fees
    function previewDeposit(uint assets) public view override returns (uint) {
        (uint rawShares, uint feeShares) = _previewDeposit(assets);
        return rawShares - feeShares;
    }

    function _previewDeposit(uint assets) internal view returns (uint rawShares, uint feeShares) {
        rawShares = super.previewDeposit(assets);
        feeShares = rawShares.feeOnRaw(_entryFeeBP());
    }

    function previewMint(uint netShares) public view override returns (uint) {
        uint totalShares = netShares.mulDiv(BP, BP - _entryFeeBP(), Math.Rounding.Up);
        return super.previewMint(totalShares);
    }

    function previewWithdraw(uint assets) public view override returns (uint) {
        uint netShares = super.previewWithdraw(assets);
        uint totalShares = netShares.mulDiv(BP, BP - _exitFeeBP(), Math.Rounding.Up);
        return totalShares;
    }

    function previewRedeem(uint shares) public view override returns (uint) {
        uint fee = shares.feeOnRaw(_exitFeeBP());
        return super.previewRedeem(shares - fee);
    }

    /** @dev See {IERC4626-maxWithdraw}. */
    function maxWithdraw(address _owner) public view override returns (uint) {
        return previewRedeem(balanceOf(_owner));
    }

    // === Fee configuration ===
    
    /// @dev Rebalancer fee discounts will look to a forwarding contract similar to LSPRouter, but with access control
    function _entryFeeBP() internal view virtual returns (uint) {
        ILiquidStabilityPool.LSPStorage storage $ = _getLSPStorage();

        return $.metaBeraborrowCore.getLspEntryFee(msg.sender);
    }

    function _exitFeeBP() internal view virtual returns (uint) {
        ILiquidStabilityPool.LSPStorage storage $ = _getLSPStorage();

        return $.metaBeraborrowCore.getLspExitFee(msg.sender);
    }

    function _initArrays(address[] memory preferredUnderlyingTokens) private view returns (ILiquidStabilityPool.Arrays memory arr) {
        address[] memory collaterals = getCollateralTokens();
        uint length = preferredUnderlyingTokens.length;

        arr = ILiquidStabilityPool.Arrays({
            length: length,
            collaterals: collaterals,
            collateralsLength: collaterals.length,
            amounts: new uint[](length)
        });
    }

    /// @notice Either registeres or blacklists a protocol from using the LSP by setting/removing its factory and liquidation manager permissions
    /// @param _factory The factory contract address to update
    /// @param _liquidationManager The liquidation manager contract address to update
    function updateProtocol(
        address _liquidationManager,
        address _factory,
        bool _register
    ) external onlyOwner {
        ILiquidStabilityPool.LSPStorage storage $ = _getLSPStorage();

        if (
            _liquidationManager == address(0) ||
            _factory == address(0)
        ) revert AddressZero();

        if (_register) {
            _registerProtocol($, _liquidationManager, _factory);
        } else {
            if (!$.factoryProtocol[_factory]) revert FactoryNotRegistered();
            if (!$.liquidationManagerProtocol[_liquidationManager]) revert LMNotRegistered();

            delete $.factoryProtocol[_factory];
            delete $.liquidationManagerProtocol[_liquidationManager];

            emit ProtocolBlacklisted(_factory, _liquidationManager);
        }
    }

    function _registerProtocol(
        ILiquidStabilityPool.LSPStorage storage $,
        address _liquidationManager,
        address _factory
    ) internal {
        if ($.factoryProtocol[_factory]) revert FactoryAlreadyRegistered();
        if ($.liquidationManagerProtocol[_liquidationManager]) revert LMAlreadyRegistered();

        $.factoryProtocol[_factory] = true;
        $.liquidationManagerProtocol[_liquidationManager] = true;

        emit ProtocolRegistered(_factory, _liquidationManager);
    }

    /* STORAGE VIEW */

    function extSloads(bytes32[] calldata slots) external view returns (bytes32[] memory res) {
        uint nSlots = slots.length;

        res = new bytes32[](nSlots);

        for (uint i; i < nSlots;) {
            bytes32 slot = slots[i++];

            assembly ("memory-safe") {
                mstore(add(res, mul(i, 32)), sload(slot))
            }
        }
    }

    /// @dev Returns the locked emissions
    function getLockedEmissions(address token) public view returns (uint) {
        EmissionsLib.EmissionSchedule memory schedule = _getLSPStorage().balanceData.emissionSchedule[token];
        uint fullUnlockTimestamp = schedule.unlockTimestamp();

        return schedule.lockedEmissions(fullUnlockTimestamp);
    }

    /**
     * @notice NECT is not locked
     */
    function getTotalDebtTokenDeposits() external view returns (uint) {
        return _getLSPStorage().balanceData.balance[asset()];
    }

    /**
     * @dev Tracks Stability's Pool `collateralTokens`
     * `collateralTokens` is pushed when a new collateral is added, but its index are overwritten if coll didn't exist
     * When a sunset is expired, its epoch is set to 0, and a new coll is added at that index
     * `queue.first` is increased for every sunsetted expired coll that is overwritten
     * `queue.next` is increased for every coll sunset, and it stores the index of the coll being sunset of the `collateralTokens` array
     * because the sunsetted expired collateral is only removed from the `collateralTokens` array when a new coll is added, the pulling of the coll has to check the sunset isn't expired
     * TLDR; the function doesn't need changes but the pulling of the coll has to check the sunset isn't expired
     */
    /// The comments below is to handle the case when a sunset collateral expires and is not yet overwritten on the LSP::collateralTokens array
    /// @dev My stance on this matter is that it is possible that certain balance liquidated collateral can happen to stoy at LV after its sunset expires
    /// On that case we could whitelist it to overwrite it and remove it from the LSP::collateralTokens array
    /// Doing that we could add it as extraAsset token (it no longer is in coll array)
    /// But whitelisting would require a new token, which we may not have the need to add as collateral type
    /// I'm a fan of dynamically excluding it below once the sunset expires and manually adding it as extraAsset token if it makes sense economically
    function getCollateralTokens() public view returns (address[] memory) {
        return _getLSPStorage().collateralTokens;
    }
}