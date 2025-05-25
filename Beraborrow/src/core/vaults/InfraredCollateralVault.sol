// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BaseCollateralVault, ERC4626Upgradeable} from "./BaseCollateralVault.sol";
import {PriceLib} from "../../libraries/PriceLib.sol";
import {IDenManager} from "../../interfaces/core/IDenManager.sol";
import {IInfraredWrapper} from "../../interfaces/core/vaults/IInfraredWrapper.sol";
import {IPriceFeed} from "../../interfaces/core/IPriceFeed.sol";
import {IInfraredCollateralVault} from "../../interfaces/core/vaults/IInfraredCollateralVault.sol";
import {IRebalancer} from "../../interfaces/utils/integrations/IRebalancer.sol";
import {IAsset} from "../../interfaces/utils/tokens/IAsset.sol";
import {IIBGTVault} from "../../interfaces/core/vaults/IIBGTVault.sol";
import {IInfraredVault} from "../../interfaces/utils/integrations/IInfraredVault.sol";
import {FeeLib} from "../../libraries/FeeLib.sol";
import {EmissionsLib} from "src/libraries/EmissionsLib.sol";


/**
 * @title Beraborrow Infrared Collateral Vault
 * @notice Supercharges DenManager with PoL
 */
abstract contract InfraredCollateralVault is BaseCollateralVault {
    using Math for uint;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EmissionsLib for EmissionsLib.BalanceData;
    using EmissionsLib for EmissionsLib.EmissionSchedule;
    using PriceLib for uint;
    using FeeLib for uint;

    uint internal constant WAD = 1e18;

    error WithdrawingLockedEmissions();

    // keccak256(abi.encode(uint(keccak256("openzeppelin.storage.InfraredCollateralVault")) - 1)) & ~bytes32(uint(0xff))
    bytes32 private constant InfraredCollateralVaultStorageLocation = 0xf6a35052099d23fafed8c58b549933969c057c5a9a13ac5133024adc8dd4f200;

    event Rebalance(address indexed sentCurrency, uint sent, uint received, uint sentValue, uint receivedValue);
    event PerformanceFee(address indexed token, uint amount);

    function _getInfraredCollVaultStorage() internal pure returns (IInfraredCollateralVault.InfraredCollVaultStorage storage store) {
        assembly {
            store.slot := InfraredCollateralVaultStorageLocation
        }
    }

    function __InfraredCollateralVault_init(IInfraredCollateralVault.InfraredInitParams calldata params) internal onlyInitializing {
        __InfraredCollateralVault_init_unchained(params);
    }

    function __InfraredCollateralVault_init_unchained(IInfraredCollateralVault.InfraredInitParams calldata params) internal onlyInitializing {
        IInfraredCollateralVault.InfraredCollVaultStorage storage $ = _getInfraredCollVaultStorage();

        if (params._iRedToken == address(0) ||  address(params._infraredVault) == address(0) || params._ibgtVault == address(0)) {
            revert("CollVault: 0 address");
        }

        IERC20 _asset = params._baseParams._asset;

        require(params._minPerformanceFee <= params._maxPerformanceFee && params._maxPerformanceFee <= BP, "CollVault: Incorrect min/max performance fee");
        require(params._performanceFee >= params._minPerformanceFee && params._performanceFee <= params._maxPerformanceFee, "CollVault: performance fee out of bounds");
        bool infraredWrapped = params._infraredWrapper != address(0);
        address stakingToken = params._infraredVault.stakingToken();
        require(infraredWrapped ? stakingToken == params._infraredWrapper : stakingToken == address(_asset), "CollVault: stakingToken mismatch");
        require(!infraredWrapped || IInfraredWrapper(params._infraredWrapper).infraredCollVault() == address(this), "CollVault: InfraredWrapper mismatch");

        $.minPerformanceFee = params._minPerformanceFee;
        $.maxPerformanceFee = params._maxPerformanceFee;
        $.performanceFee = params._performanceFee;

        $.iRedToken = params._iRedToken; // this set assumes that the iRedToken is a reward token in all InfraredVaults, which may not be the case
        $._infraredVault = params._infraredVault;
        $.ibgtVault = params._ibgtVault;
        $.infraredWrapper = IInfraredWrapper(params._infraredWrapper);

        __BaseCollateralVault_init(params._baseParams);

        $.ibgt = address(this) == params._ibgtVault ? address(_asset) : IIBGTVault(params._ibgtVault).asset();

        // so we don't have to approve() every time we stake into infrared
        IERC20(stakingToken).safeApprove(address(params._infraredVault), type(uint256).max);
    }

    // Compound iBGT rewards
    /// @dev Since we are not accepting donations, we won't `stake` ibgt.balanceOf(this)
    function _harvestRewards() internal override {
        if (block.timestamp == _getInfraredCollVaultStorage().lastUpdate) return;

        IInfraredVault iVault = infraredVault();
        address[] memory tokens = iVault.getAllRewardTokens();
        uint[] memory prevBalances = new uint[](tokens.length);

        for (uint i; i < tokens.length; i++) {
            prevBalances[i] = IERC20(tokens[i]).balanceOf(address(this));
        }

        // harvest rewards
        iVault.getReward();

        uint _performanceFee = getPerformanceFee();
        address _iRedToken = iRedToken();
        address _ibgt = ibgt();
        IIBGTVault _ibgtVault = IIBGTVault(ibgtVault());
        // re-stake iBGT, take performance fee and update accounting
        for (uint i; i < tokens.length; i++) {
            address _token = tokens[i];
            uint newBalance = IERC20(_token).balanceOf(address(this));

            uint rewards = newBalance - prevBalances[i];
            if (rewards == 0) continue; /// @dev Skip if no rewards, saves from iVault revert 'Cannot stake 0'

            (rewards, _token) = _autoCompoundHook(_token, _ibgt, _ibgtVault, rewards);

            // Meanwhile the token doesn't has an oracle mapped, it will be processed as a donation
            // This will avoid returns meanwhile a newly Infrared pushed reward token is not mapped
            if (_hasPriceFeed(_token) && _token != _iRedToken && !_isCollVault(_token)) {
                uint fee = rewards * _performanceFee / BP;
                uint netRewards = rewards - fee;

                if (_token == asset()) {
                    _stake(netRewards);
                }

                _increaseBalance(_token, netRewards);

                // First time the oracle happens to be mapped, we add the token to the rewardedTokens
                // If token has no oracle map this won't be called, hence not DOS the vault at `totalAssets`
                _addRewardedToken(_token); // won't add duplicates

                if (fee != 0) {
                    IERC20(_token).safeTransfer(getMetaBeraborrowCore().feeReceiver(), fee);

                    emit PerformanceFee(_token, fee);
                }
            }
        }
        _getInfraredCollVaultStorage().lastUpdate = uint96(block.timestamp);
    }

    /** @dev See {IERC4626-totalAssets}. */
    /// @notice Returns the total assets in the vault, denominated in the asset of the vault
    /// @dev Virtual accounting to avoid donations, asset valued denomination, returned in WAD
    /// @dev Not yet harvested rewards not yet added due to possible temporal overestimation due to rewards being donated through `getRewardForUser`
    function totalAssets() public view override virtual returns (uint amountInAsset) {
        // UsdValue is scaled to 1e18, since `getPrice` returns a WAD scaled price
        uint usdValue;
        address[] memory _rewardedTokens = rewardedTokens();
        uint rewardedTokensLength = _rewardedTokens.length;

        uint assetPrice = getPrice(asset());
        uint assetBalance = _isRewardedToken(asset()) ? 0 : getBalance(asset());

        for (uint i; i < rewardedTokensLength; i++) {
            usdValue += _convertToValue(_rewardedTokens[i]);
        }

        amountInAsset = usdValue.mulDiv(10 ** assetDecimals(), assetPrice) + assetBalance;
    }

    function _previewRedeem(uint shares) internal view override returns (uint, uint) {
        IInfraredCollateralVault.InfraredCollVaultStorage storage $ = _getInfraredCollVaultStorage();

        bool isInternalRedemption = address(this) == $.ibgtVault && getPriceFeed().isCollVault(msg.sender);
        uint shareFee = isInternalRedemption ? 0 : shares.feeOnRaw(getWithdrawFee());
        uint assets = ERC4626Upgradeable.previewRedeem(shares - shareFee);
        return (assets, shareFee);
    }

    /// @dev Token out or received currency will always be the asset of the vault
    function rebalance(IInfraredCollateralVault.RebalanceParams calldata p) external virtual onlyOwner {
        IInfraredCollateralVault.InfraredCollVaultStorage storage $ = _getInfraredCollVaultStorage();

        uint sentPrice = getPrice(p.sentCurrency);
        uint receivedPrice = getPrice(asset());
        uint8 sentDecimals = IAsset(p.sentCurrency).decimals();
        uint sentCurrencyBalance = IAsset(p.sentCurrency).balanceOf(address(this));
        uint receivedCurrencyBalance = IAsset(asset()).balanceOf(address(this));

        // Perform the swap using the swapper contract
        IERC20(p.sentCurrency).safeTransfer(p.swapper, p.sentAmount);
        IRebalancer(p.swapper).swap(
            p.sentCurrency,
            p.sentAmount,
            asset(),
            p.payload
        );

        uint received = IAsset(asset()).balanceOf(address(this)) - receivedCurrencyBalance;
        uint sent = sentCurrencyBalance - IAsset(p.sentCurrency).balanceOf(address(this));

        // if we were to rebalance locked emissions, a possible revert on subsequent `$.balanceOf` calls would occur
        if (sent > getBalance(p.sentCurrency)) revert WithdrawingLockedEmissions();

        uint receivedValue = received.convertToValue(receivedPrice, assetDecimals());
        uint sentValue = sent.convertToValue(sentPrice, sentDecimals);

        // if threshold isn't set, it will be 0, not tolerating any slippage
        require(receivedValue >= sentValue * (BP - $.threshold[p.sentCurrency]) / BP, "CollVault: received amount is below threshold");

        _decreaseBalance(p.sentCurrency, sent);
        _increaseBalance(asset(), received);

        _afterVaultRebalance(received);

        emit Rebalance(p.sentCurrency, sent, received, sentValue, receivedValue);
    }

    function setUnlockRatePerSecond(address token, uint64 _unlockRatePerSecond) external onlyOwner {
        _getBalanceData().setUnlockRatePerSecond(token, _unlockRatePerSecond);
    }

    /// @notice Creates a linear vesting for certain tokens donated to this vault
    /// @dev Make sure to call `setUnlockRatePerSecond` before calling this function for each token, default one is too low for this purpose
    function internalizeDonations(address[] memory tokens, uint128[] memory amounts) external virtual onlyOwner {
        uint tokensLength = tokens.length;

        require(tokensLength == amounts.length, "CollVault: tokens and amounts length mismatch");

        IInfraredVault iVault = infraredVault();
        address _ibgt = ibgt();
        IIBGTVault _ibgtVault = IIBGTVault(ibgtVault());
        uint _performanceFee = getPerformanceFee();

        for (uint i; i < tokensLength; i++) {
            address token = tokens[i];
            uint amount = amounts[i];

            if (amount == 0) continue;

            // asset is staked in infraredVault, not in address(this)
            uint donatedAmount = token != asset()
                ? IERC20(token).balanceOf(address(this)) - getBalanceOfWithFutureEmissions(token)
                : IAsset(asset()).balanceOf(address(this));
            require(donatedAmount >= amount, "CollVault: insufficient balance");

            (amount, token) = _autoCompoundHook(token, _ibgt, _ibgtVault, amount);

            require(_isRewardedToken(token), "CollVault: token not rewarded");

            uint fee = amount * _performanceFee / BP;
            uint netAmounts = amount - fee;

            if (token == asset()) {
                _stake(netAmounts);
            }

            if (fee != 0) {
                IERC20(token).safeTransfer(getMetaBeraborrowCore().feeReceiver(), fee);
            }

            _getBalanceData().addEmissions(token, uint128(netAmounts));
        }
    }

    /// @dev Harvests rewards to don't have previously accrued but still not harvested rewards processed with the new fee
    function setPerformanceFee(uint16 _performanceFee) external virtual onlyOwner harvestRewards {
        IInfraredCollateralVault.InfraredCollVaultStorage storage $ = _getInfraredCollVaultStorage();

        require(_performanceFee >= $.minPerformanceFee && _performanceFee <= $.maxPerformanceFee, "CollVault: performance fee out of bounds");

        $.performanceFee = _performanceFee;
    }

    function setPairThreshold(address tokenIn, uint thresholdInBP) external virtual onlyOwner {
        IInfraredCollateralVault.InfraredCollVaultStorage storage $ = _getInfraredCollVaultStorage();

        require(thresholdInBP <= BP, "CollVault: threshold > BP");

        $.threshold[tokenIn] = thresholdInBP;
    }

    function setIRED(address _iRedToken) external virtual onlyOwner {
        _getInfraredCollVaultStorage().iRedToken = _iRedToken;
    }

    function _increaseBalance(address token, uint amount) internal override {
        _getBalanceData().balance[token] += amount;
    }

    function _decreaseBalance(address token, uint amount) internal override {
        _getBalanceData().balance[token] -= amount;
    }

    /* Getters */

    /// @dev Doesn't include vesting amount, same as `getTokenVirtualBalance` in LSPGetters
    function getBalance(address token) public view override returns (uint) {
        return _getBalanceData().balanceOf(token);
    }

    /// @dev Includes vesting amount
    function getBalanceOfWithFutureEmissions(address token) public view virtual returns (uint) {
        return _getBalanceData().balance[token];
    }

    /// @dev Returns the locked emissions
    function getLockedEmissions(address token) public view returns (uint) {
        EmissionsLib.EmissionSchedule memory schedule = _getBalanceData().emissionSchedule[token];
        uint fullUnlockTimestamp = schedule.unlockTimestamp();

        return schedule.lockedEmissions(fullUnlockTimestamp);
    }

    function unlockRatePerSecond(address token) external view virtual returns (uint) {
        EmissionsLib.EmissionSchedule memory schedule = _getBalanceData().emissionSchedule[token];

        return schedule.unlockRatePerSecond();
    }

    function getFullProfitUnlockTimestamp(address token) external view returns (uint) {
        EmissionsLib.EmissionSchedule memory schedule = _getBalanceData().emissionSchedule[token];

        return schedule.unlockTimestamp();
    }

    function getPerformanceFee() public view virtual returns (uint16) {
        return _getInfraredCollVaultStorage().performanceFee;
    }

    /// @dev Returns tokens that has been rewarded at some point by the infrared vault
    function rewardedTokens() public view virtual returns (address[] memory) {
        return _getInfraredCollVaultStorage().rewardedTokens.values();
    }

    function _isRewardedToken(address token) internal view virtual returns (bool) {
        return _getInfraredCollVaultStorage().rewardedTokens.contains(token);
    }

    function _addRewardedToken(address token) internal virtual {
        IInfraredCollateralVault.InfraredCollVaultStorage storage $ = _getInfraredCollVaultStorage();
        $.rewardedTokens.add(token);
    }

    function iRedToken() public view virtual returns (address) {
        return _getInfraredCollVaultStorage().iRedToken;
    }

    function infraredVault() public view virtual returns (IInfraredVault) {
        return _getInfraredCollVaultStorage()._infraredVault;
    }

    function ibgt() public view virtual returns (address) {
        return _getInfraredCollVaultStorage().ibgt;
    }

    function ibgtVault() public view virtual returns (address) {
        return _getInfraredCollVaultStorage().ibgtVault;
    }

    function _stake(uint amount) internal override {
        IInfraredCollateralVault.InfraredCollVaultStorage storage $ = _getInfraredCollVaultStorage();
        IInfraredWrapper infraredWrapper = $.infraredWrapper;

        if (address(infraredWrapper) != address(0)) {
            IERC20(asset()).safeApprove(address(infraredWrapper), amount);
            infraredWrapper.depositFor(address(this), amount);
        }
        $._infraredVault.stake(amount);
    }

    function _unstake(uint amount) internal override {
        IInfraredCollateralVault.InfraredCollVaultStorage storage $ = _getInfraredCollVaultStorage();
        IInfraredWrapper infraredWrapper = $.infraredWrapper;

        $._infraredVault.withdraw(amount);

        if (address(infraredWrapper) != address(0)) {
            infraredWrapper.withdrawTo(address(this), amount);
        }
    }

    /// @dev Rewards the rest of the rewarded tokens (not the asset) to the receiver
    function _withdrawExtraRewardedTokens(
        address receiver,
        uint shares,
        uint _totalSupply
    ) internal override virtual {
        IInfraredCollateralVault.InfraredCollVaultStorage storage $ = _getInfraredCollVaultStorage();

        address[] memory tokens = rewardedTokens();
        uint tokensLength = tokens.length;
        address _ibgtVault = $.ibgtVault;

        for (uint i; i < tokensLength; i++) {
            address token = tokens[i];
            // if token is the asset, go next token since has already been transferred
            if (token == asset()) {
                continue;
            }

            uint amount = shares.mulDiv(getBalance(token), _totalSupply, Math.Rounding.Down);

            if (amount == 0) continue;
            _decreaseBalance(token, amount);

            if (token == _ibgtVault && _ibgtVault != address(this)) {
                IInfraredCollateralVault(token).redeem(amount, receiver, address(this));
            } else {
                IERC20(token).safeTransfer(receiver, amount);
            }
        }
    }

    function _hasPriceFeed(address token) internal view virtual returns (bool) {
        IPriceFeed priceFeed = getPriceFeed();

        (address oracle,,,,) = priceFeed.oracleRecords(token);

        IPriceFeed.FeedType memory feedInfo = priceFeed.feedType(token);

        return oracle != address(0) || feedInfo.isCollVault || feedInfo.spotOracle != address(0);
    }

    function _convertToValue(address token) public view virtual returns (uint) {
        uint currentBalance = getBalance(token);
        uint price = getPrice(token);
        uint8 _decimals = IAsset(token).decimals();
        return currentBalance.convertToValue(price, _decimals);
    }

    /**
     * @dev Hook that is called to check if the token is a collateral vault
     * @dev Prevents recursion DOS attacks by preventing the vault from being a reward token
     * Only collateral vault permitted is iBGTVault
     */
    function _isCollVault(address token) internal view virtual returns (bool) {
        IInfraredCollateralVault.InfraredCollVaultStorage storage $ = _getInfraredCollVaultStorage();

        // iBGTVault is the only collateral vault permitted, unless it is the current vault
        if (token == $.ibgtVault && $.ibgtVault != address(this)) {
            return false;
        }
        return getPriceFeed().isCollVault(token);
    }

    function _autoCompoundHook(address _token, address /*_ibgt*/, IIBGTVault /*_ibgtVault*/, uint _rewards) internal virtual returns (uint, address) {
        return (_rewards, _token);
    }

    /**
     * @dev Hook that is called after the vault has been rebalanced
     * Meant to be used by the child contract to stake the `asset()` in the infrared vault
     */
    function _afterVaultRebalance(uint amount) internal virtual {
        _stake(amount);
    }
}
