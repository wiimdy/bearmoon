// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {ERC4626Upgradeable, ERC20Upgradeable, IERC20, Math, SafeERC20} from "@openzeppelin-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol"; 
import {IBaseCollateralVault, IERC4626} from "../../interfaces/core/vaults/IBaseCollateralVault.sol";
import {IMetaBeraborrowCore} from "../../interfaces/core/IMetaBeraborrowCore.sol";
import {IPriceFeed} from "../../interfaces/core/IPriceFeed.sol";
import {IAsset} from "../../interfaces/utils/tokens/IAsset.sol";
import {FeeLib} from "../../libraries/FeeLib.sol";
import {EmissionsLib} from "../../libraries/EmissionsLib.sol";

abstract contract BaseCollateralVault is ERC4626Upgradeable, UUPSUpgradeable, IBaseCollateralVault {
    using Math for uint;
    using SafeERC20 for IERC20;
    using FeeLib for uint;

    uint internal constant BP = 1e4;

    // keccak256(abi.encode(uint(keccak256("openzeppelin.storage.BaseCollateralVault")) - 1)) & ~bytes32(uint(0xff))
    bytes32 private constant BaseCollateralVaultStorageLocation = 0x19001df2d131e9aa1479f4ce661ae121445caf0662dea1e41907028a6da6fe00;

    function _getBaseCollVaultStorage() internal pure returns (BaseCollVaultStorage storage store) {
        assembly {
            store.slot := BaseCollateralVaultStorageLocation
        }
    }

    constructor() {
        _disableInitializers();
    }

    function __BaseCollateralVault_init(BaseInitParams calldata params) internal onlyInitializing {
        __BaseCollateralVault_init_unchained(params);
    }

    function __BaseCollateralVault_init_unchained(BaseInitParams calldata params) internal onlyInitializing {
        BaseCollVaultStorage storage $ = _getBaseCollVaultStorage();

        if (address(params._metaBeraborrowCore) == address(0) || address(params._asset) == address(0)) {
            revert("CollVault: 0 address");
        }

        IPriceFeed priceFeed = IPriceFeed(params._metaBeraborrowCore.priceFeed());
        // require(priceFeed.fetchPrice(address(params._asset)) != 0, "CollVault: asset price feed not set up");
        require(params._minWithdrawFee <= params._maxWithdrawFee && params._maxWithdrawFee <= BP, "CollVault: Incorrect min/max withdraw fee");
        require(params._withdrawFee >= params._minWithdrawFee && params._withdrawFee <= params._maxWithdrawFee, "CollVault: withdraw fee out of bounds");

        $.minWithdrawFee = params._minWithdrawFee;
        $.maxWithdrawFee = params._maxWithdrawFee;

        $.withdrawFee = params._withdrawFee;

        uint8 _assetDecimals = IAsset(address(params._asset)).decimals();
        if (_assetDecimals > 18) {
            revert("CollVault: asset decimals > 18");
        }
        $.assetDecimals = _assetDecimals;

        $._metaBeraborrowCore = params._metaBeraborrowCore;

        __ERC20_init(params._sharesName, params._sharesSymbol);
        __ERC4626_init(params._asset);
    }

    modifier onlyOwner {
        _onlyOwner();
        _;
    }

    modifier harvestRewards() {
        _harvestRewards();
        _;
    }

    function _onlyOwner() private view {
        // Owner is beacon variable MetaBeraborrowCore::owner()
        require(msg.sender == getMetaBeraborrowCore().owner(), "CollVault: caller is not the owner");
    }

    function _authorizeUpgrade(address newImplementation) internal override virtual onlyOwner {}

    /** @dev See {IERC4626-totalAssets}. */
    /// @notice Returns the total assets in the vault, denominated in the asset of the vault
    /// @dev Virtual accounting to avoid donations, asset valued denomination, returned in asset decimals
    function totalAssets() public view override(ERC4626Upgradeable, IBaseCollateralVault) virtual returns (uint) {
        return getBalance(asset());
    }

    /// @dev Called by DenManager, returns the share usd value in WAD
    /// @dev Fees are not accounted to downprice the share value for redeemCollateral,
    ///     for borrowing, MCR will account for this downprice 
    function fetchPrice() public view virtual returns (uint) {
        uint _totalSupply = totalSupply();
        if (_totalSupply == 0) return 0;
        return (totalAssets() * 10 ** _decimalsOffset()).mulDiv(getPrice(asset()), _totalSupply);
    }

    /// @dev Note, validate this implementation if inherited by multi asset vault (InfraredCollateralVault)
    function _decimalsOffset() internal view override virtual returns (uint8) {
        return 18 - assetDecimals();
    }

    function deposit(
        uint assets,
        address receiver
    ) public override(ERC4626Upgradeable, IERC4626) harvestRewards returns (uint shares) {
        shares = super.deposit(assets, receiver);

        _stake(assets);

        _increaseBalance(asset(), assets);
    }

    function mint(
        uint shares,
        address receiver
    ) public override(ERC4626Upgradeable, IERC4626) harvestRewards returns (uint assets) {
        assets = super.mint(shares, receiver);

        _stake(assets);

        _increaseBalance(asset(), assets);
    }

    function withdraw(
        uint assets,
        address receiver,
        address _owner
    ) public override(ERC4626Upgradeable, IERC4626) harvestRewards returns (uint shares) {
        uint _totalSupply = totalSupply(); // cached to don't account for the burn

        { // scope to avoid stack too deep error
            uint256 maxAssets = maxWithdraw(_owner);
            if (assets > maxAssets) {
                revert ERC4626ExceededMaxWithdraw(_owner, assets, maxAssets);
            }
        }
        uint shareFee;
        (shares, shareFee) = _previewWithdraw(assets);

        (uint assetAmount, uint netShares) = _applyShareFee(shares, _totalSupply, shareFee);

        if (assetAmount != 0) {
            _unstake(assetAmount);
            _decreaseBalance(asset(), assetAmount);
        }

        _withdraw(msg.sender, receiver, _owner, assetAmount, shares);
        _withdrawExtraRewardedTokens(receiver, netShares, _totalSupply);
    }

    /// @dev Decompounded redeem() function to reuse `previewRedeem()` on `infrared.withdraw`
    function redeem(
        uint shares,
        address receiver,
        address _owner
    ) public override(ERC4626Upgradeable, IERC4626) harvestRewards returns (uint assets) {
        uint _totalSupply = totalSupply(); // cached to don't account for the burn

        { // scope to avoid stack too deep error
            uint256 maxShares = maxRedeem(_owner);
            if (shares > maxShares) {
                revert ERC4626ExceededMaxRedeem(_owner, shares, maxShares);
            }
        }

        uint shareFee;
        (assets, shareFee) = _previewRedeem(shares);

        (uint assetAmount, uint netShares) = _applyShareFee(shares, _totalSupply, shareFee);

        if (assetAmount != 0) {
            _unstake(assetAmount);
            _decreaseBalance(asset(), assetAmount);
        }

        _withdraw(msg.sender, receiver, _owner, assetAmount, shares);
        _withdrawExtraRewardedTokens(receiver, netShares, _totalSupply);
    }

    function _applyShareFee(uint shares, uint _totalSupply, uint fee) internal virtual returns (uint, uint) {
        BaseCollVaultStorage storage $ = _getBaseCollVaultStorage();

        uint netShares = shares - fee;

        uint assetAmount = netShares.mulDiv(getBalance(asset()), _totalSupply, Math.Rounding.Down);

        address feeReceiver = $._metaBeraborrowCore.feeReceiver();
        if (fee != 0) {
            _mint(feeReceiver, fee);
        }

        return (assetAmount, netShares);
    }

    /// @dev Preview adding an exit fee on withdraw. See {IERC4626-previewWithdraw}.
    function previewWithdraw(
        uint assets
    ) public view virtual override(ERC4626Upgradeable, IERC4626) returns (uint) {
        (uint totalShares,) = _previewWithdraw(assets);
        return totalShares;
    }

    function _previewWithdraw(uint assets) internal view virtual returns (uint, uint) {
        BaseCollVaultStorage storage $ = _getBaseCollVaultStorage();

        uint netShares = super.previewWithdraw(assets);
        uint totalShares = netShares.mulDiv(BP, BP - $.withdrawFee, Math.Rounding.Up);
        uint shareFee = totalShares - netShares;
        return (totalShares, shareFee);
    }

    /// @dev Preview taking an exit fee on redeem. See {IERC4626-previewRedeem}.
    function previewRedeem(
        uint shares
    ) public view virtual override(ERC4626Upgradeable, IERC4626) returns (uint) {
        (uint assets,) = _previewRedeem(shares);
        return assets;
    }

    function _previewRedeem(uint shares) internal view virtual returns (uint, uint) {
        BaseCollVaultStorage storage $ = _getBaseCollVaultStorage();

        uint shareFee = shares.feeOnRaw($.withdrawFee);
        uint assets = super.previewRedeem(shares - shareFee);
        return (assets, shareFee);
    }

    /** @dev See {IERC4626-maxWithdraw}. */
    function maxWithdraw(address _owner) public view override(ERC4626Upgradeable, IERC4626) returns (uint) {
        return previewRedeem(balanceOf(_owner));
    }

    /// @dev `receiver` automatically receives `asset()` donations, and `tokens` and `amounts` donations as desired by the owner `amounts`
    function receiveDonations(address[] memory tokens, uint[] memory amounts, address receiver) external virtual onlyOwner {
        BaseCollVaultStorage storage $ = _getBaseCollVaultStorage();

        uint tokensLength = tokens.length;

        require(tokensLength == amounts.length, "CollVault: tokens and amounts length mismatch");

        uint assetBalance = IERC20(asset()).balanceOf(address(this));
        uint virtualBalance = $.balanceData.balance[asset()];

        if (assetBalance > virtualBalance) {
            IERC20(asset()).safeTransfer(receiver, assetBalance - virtualBalance);
        }

        for (uint i; i < tokensLength; i++) {
            if (tokens[i] == asset()) {
                continue;
            }
            uint256 tokenBalance = IERC20(tokens[i]).balanceOf(address(this));
            uint256 virtualTokenBalance = $.balanceData.balance[tokens[i]];
            uint256 transferAmount = Math.min(amounts[i], tokenBalance - virtualTokenBalance);
            if (transferAmount > 0) {
                IERC20(tokens[i]).safeTransfer(receiver, transferAmount);
            }
        }
    }

    function setWithdrawFee(uint16 _withdrawFee) external virtual onlyOwner {
        BaseCollVaultStorage storage $ = _getBaseCollVaultStorage();

        require(_withdrawFee >= $.minWithdrawFee && _withdrawFee <= $.maxWithdrawFee, "CollVault: Withdraw fee out of bounds");

        $.withdrawFee = _withdrawFee;
    }

    function _increaseBalance(address token, uint amount) internal virtual {
        BaseCollVaultStorage storage $ = _getBaseCollVaultStorage();
        $.balanceData.balance[token] += amount;
    }

    function _decreaseBalance(address token, uint amount) internal virtual {
        BaseCollVaultStorage storage $ = _getBaseCollVaultStorage();
        $.balanceData.balance[token] -= amount;
    }

    function _getBalanceData() internal view virtual returns (EmissionsLib.BalanceData storage) {
        return _getBaseCollVaultStorage().balanceData;
    }

    function getPrice(
        address token
    ) public view virtual returns (uint) {
        return getPriceFeed().fetchPrice(token);
    }

    function getBalance(address token) public view virtual returns (uint) {
        return _getBaseCollVaultStorage().balanceData.balance[token];
    }

    function getWithdrawFee() public view virtual returns (uint16) {
        return _getBaseCollVaultStorage().withdrawFee;
    }

    function getMetaBeraborrowCore() public view virtual returns (IMetaBeraborrowCore) {
        return _getBaseCollVaultStorage()._metaBeraborrowCore;
    }

    function getPriceFeed() public view virtual returns (IPriceFeed) {
        return IPriceFeed(_getBaseCollVaultStorage()._metaBeraborrowCore.priceFeed());
    }

    function assetDecimals() public view virtual returns (uint8) {
        return _getBaseCollVaultStorage().assetDecimals;
    }

    function _harvestRewards() internal virtual {}
    function _stake(uint amount) internal virtual {}
    function _unstake(uint amount) internal virtual {}
    function _withdrawExtraRewardedTokens(address receiver, uint netShares, uint _totalSupply) internal virtual {}
}