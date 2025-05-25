// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDenManager} from "../../interfaces/core/IDenManager.sol";
import {IInfraredCollateralVault} from "../core/vaults/IInfraredCollateralVault.sol";

interface ICollVaultRouter {

    struct OpenDenVaultParams {
        IDenManager denManager;
        IInfraredCollateralVault collVault;
        uint256 _maxFeePercentage;
        uint256 _debtAmount;
        uint256 _collAssetToDeposit;
        address _upperHint;
        address _lowerHint;
        uint256 _minSharesMinted;
        uint256 _collIndex;
        bytes _preDeposit;
    }

    /// @dev Avoid stack too deep
    struct AdjustDenVaultParams {
        IDenManager denManager;
        IInfraredCollateralVault collVault;
        uint256 _maxFeePercentage;
        uint256 _collAssetToDeposit;
        uint256 _collWithdrawal;
        uint256 _debtChange;
        bool _isDebtIncrease;
        address _upperHint;
        address _lowerHint;
        bool unwrap;
        uint256 _minSharesMinted;
        uint256 _minAssetsWithdrawn;
        uint256 _collIndex;
        bytes _preDeposit;
    }

    /// @dev Avoid stack too deep
    struct RedeemCollateralVaultParams {
        IDenManager denManager;
        IInfraredCollateralVault collVault;
        uint256 _debtAmount;
        address _firstRedemptionHint;
        address _upperPartialRedemptionHint;
        address _lowerPartialRedemptionHint;
        uint256 _partialRedemptionHintNICR;
        uint256 _maxIterations;
        uint256 _maxFeePercentage;
        uint256 _minSharesWithdrawn;
        uint256 minAssetsWithdrawn;
        uint256 collIndex;
        bool unwrap;
    }

    struct DepositFromAnyParams {
        IInfraredCollateralVault collVault;
        address inputToken;
        uint inputAmount;
        uint minSharesMinted;
        uint outputMin;
        address outputReceiver;
        bytes dexCalldata;
    }

    struct RedeemToOneParams {
        uint shares;
        address receiver;
        IInfraredCollateralVault collVault;
        address targetToken;
        uint minTargetTokenAmount;
        uint[] outputQuotes;
        uint[] outputMins;
        bytes[] pathDefinitions;
        address executor;
        uint32 referralCode;
    }

    struct SimRedeemVars {
        uint256 netShares;
        uint256 totalSupply;
        address asset;
        uint256 earned;
        uint256 assetAmount;
    }

    function openDenVault(
        OpenDenVaultParams memory params
    ) external payable;
    function adjustDenVault(AdjustDenVaultParams calldata params) external payable;
    function closeDenVault(
        IDenManager denManager,
        IInfraredCollateralVault collVault,
        uint256 minAssetsWithdrawn,
        uint256 collIndex,
        bool unwrap
    ) external;

    function claimLockedTokens(IERC20[] memory tokens, uint[] memory amounts) external;

    function depositFromAny(
        DepositFromAnyParams calldata params
    ) external payable returns (uint shares);

    function redeemToOne(
        RedeemToOneParams calldata params
    ) external;

    function previewRedeemUnderlying(IInfraredCollateralVault collVault, uint shares) external view returns (address[] memory tokens, uint[] memory amounts);
}