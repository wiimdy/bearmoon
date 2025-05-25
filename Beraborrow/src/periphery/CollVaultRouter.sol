// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IInfraredCollateralVault} from "../interfaces/core/vaults/IInfraredCollateralVault.sol";
import {ILiquidStabilityPool} from "../interfaces/core/ILiquidStabilityPool.sol";
import {IBorrowerOperations} from "../interfaces/core/IBorrowerOperations.sol";
import {IWBera} from "../interfaces/utils/tokens/IWBERA.sol";
import {IDebtToken} from "../interfaces/core/IDebtToken.sol";
import {IDenManager} from "../interfaces/core/IDenManager.sol";
import {ICollVaultRouter} from "../interfaces/periphery/ICollVaultRouter.sol";
import {IMetaBeraborrowCore} from "../interfaces/core/IMetaBeraborrowCore.sol";
import {IPreDepositHook} from "../interfaces/periphery/preDepositHooks/IPreDepositHook.sol";
import {IOBRouter} from "../interfaces/utils/integrations/IOBRouter.sol";
import {IInfraredVault} from "src/interfaces/utils/integrations/IInfraredVault.sol";
import {TokenValidationLib} from "../libraries/TokenValidationLib.sol";
import {UtilsLib} from "../libraries/UtilsLib.sol";
import {DynamicArrayLib} from "solady/utils/DynamicArrayLib.sol";
import {FeeLib} from "../libraries/FeeLib.sol";

/// @dev Doesn't have DelegatedOps functionality
/// @dev Periphery whitelisted in BeraborrowCore, delegates BorrowerOperations accounts
contract CollVaultRouter is ICollVaultRouter {
    using SafeERC20 for IERC20;
    using Math for uint;
    using TokenValidationLib for address[];
    using TokenValidationLib for IInfraredCollateralVault;
    using DynamicArrayLib for DynamicArrayLib.DynamicArray;
    using DynamicArrayLib for address[];
    using DynamicArrayLib for uint[];
    using UtilsLib for bytes;
    using FeeLib for uint;

    IInfraredCollateralVault immutable ibgtVault;
    IBorrowerOperations immutable borrowerOperations;
    IWBera immutable wBera;
    IDebtToken immutable nectar;
    ILiquidStabilityPool immutable liquidStabilityPool;
    IMetaBeraborrowCore immutable metaBeraborrowCore;
    IOBRouter immutable obRouter;

    constructor(
        address _borrowerOperations,
        address _wBera,
        address _nectar,
        address _liquidStabilityPool,
        address _metaBeraborrowCore,
        address _obRouter,
        address _ibgtVault
    ) {
        if (_borrowerOperations == address(0) || _wBera == address(0) || _nectar == address(0) || _liquidStabilityPool == address(0) || _metaBeraborrowCore == address(0)) {
            revert("CollVaultRouter: 0 address");
        }

        borrowerOperations = IBorrowerOperations(_borrowerOperations);
        wBera = IWBera(_wBera);
        nectar = IDebtToken(_nectar);
        liquidStabilityPool = ILiquidStabilityPool(_liquidStabilityPool);
        metaBeraborrowCore = IMetaBeraborrowCore(_metaBeraborrowCore);
        obRouter = IOBRouter(_obRouter);
        ibgtVault = IInfraredCollateralVault(_ibgtVault);
    }

    /**
     * @notice Opens positions by routing the wrapping of the token for the vault share
     * @notice Handles BERA to iBERA conversion
     * @param params - _preDeposit If has data, we call `preDepositHook` on the vault, `_collAssetToDeposit` will be overridden by the amount returned
     */
    function openDenVault(
        ICollVaultRouter.OpenDenVaultParams memory params
    ) external payable {
        IERC20 vaultAsset = _validateVaultAndManager(params.collVault, params._collIndex, params.denManager);

        if (params._preDeposit.length != 0) {
            (bytes memory preDepositParams, IPreDepositHook target) = abi.decode(params._preDeposit, (bytes, IPreDepositHook));
            uint prevAssetBalance = vaultAsset.balanceOf(address(this));
            target.preDepositHook{value: msg.value}(msg.sender, preDepositParams);
            params._collAssetToDeposit = vaultAsset.balanceOf(address(this)) - prevAssetBalance;
        } else {
            if (msg.value != 0) {
                require(address(vaultAsset) == address(wBera), "Passed msg.value with non-WBERA vault");
                require(msg.value == params._collAssetToDeposit, "msg.value != _collAmount");
                wBera.deposit{value: params._collAssetToDeposit}();
            } else {
                vaultAsset.safeTransferFrom(msg.sender, address(this), params._collAssetToDeposit);
            }
        }

        vaultAsset.safeIncreaseAllowance(address(params.collVault), params._collAssetToDeposit);
        uint sharesMinted = params.collVault.deposit(params._collAssetToDeposit, address(this));

        require(sharesMinted >= params._minSharesMinted, "sharesMinted < _minSharesMinted");

        params.collVault.approve(address(borrowerOperations), sharesMinted);
        borrowerOperations.openDen(
            address(params.denManager),
            msg.sender,
            params._maxFeePercentage,
            sharesMinted,
            params._debtAmount,
            params._upperHint,
            params._lowerHint
        );

        nectar.transfer(msg.sender, params._debtAmount);
    }

    function adjustDenVault(
        ICollVaultRouter.AdjustDenVaultParams memory params
    ) external payable {
        IERC20 vaultAsset = _validateVaultAndManager(params.collVault, params._collIndex, params.denManager);
        
        uint sharesMinted;

        if (params._collAssetToDeposit != 0) {
            if (params._preDeposit.length != 0) {
                (bytes memory preDepositParams, IPreDepositHook target) = abi.decode(params._preDeposit, (bytes, IPreDepositHook));
                uint256 prevAssetsBalance = vaultAsset.balanceOf(address(this));
                target.preDepositHook{value: msg.value}(msg.sender, preDepositParams);
                params._collAssetToDeposit = vaultAsset.balanceOf(address(this)) - prevAssetsBalance;
            } else {
                if (msg.value != 0) {
                    require(address(vaultAsset) == address(wBera), "Passed msg.value with non-WBERA vault");  
                    require(msg.value == params._collAssetToDeposit, "msg.value != _collAmount");
                    wBera.deposit{value: params._collAssetToDeposit}();
                } else {
                    vaultAsset.safeTransferFrom(msg.sender, address(this), params._collAssetToDeposit);
                }
            }
            vaultAsset.safeIncreaseAllowance(address(params.collVault), params._collAssetToDeposit);
            sharesMinted = params.collVault.deposit(params._collAssetToDeposit, address(this));
            require(sharesMinted >= params._minSharesMinted, "sharesMinted < minSharesMinted");

            params.collVault.approve(address(borrowerOperations), sharesMinted);
        }

        if (!params._isDebtIncrease && params._debtChange != 0) {
            nectar.sendToPeriphery(msg.sender, params._debtChange);
        }

        borrowerOperations.adjustDen(
            address(params.denManager),
            msg.sender,
            params._maxFeePercentage,
            sharesMinted,
            params._collWithdrawal,
            params._debtChange,
            params._isDebtIncrease,
            params._upperHint,
            params._lowerHint
        );

        if (params._collWithdrawal != 0) {
            if (params.unwrap) {
                uint assetsWithdrawn = params.collVault.redeem(params._collWithdrawal, msg.sender, address(this));
                require(assetsWithdrawn >= params._minAssetsWithdrawn, "assetsWithdrawn < _minAssetsWithdrawn");
            } else {
                IERC20(address(params.collVault)).safeTransfer(msg.sender, params._collWithdrawal);
            }
        }

        if (params._isDebtIncrease) {
            nectar.transfer(msg.sender, params._debtChange);
        }
    }

    function closeDenVault(
        IDenManager denManager,
        IInfraredCollateralVault collVault,
        uint256 minAssetsWithdrawn,
        uint256 collIndex,
        bool unwrap
    ) external {
        require(_isWhitelistedCollateralAt(address(collVault), collIndex), "Incorrect collateral");
        require(address(denManager.collateralToken()) == address(collVault), "Incorrect DenManager or Vault");

        uint prevSharesBalance = collVault.balanceOf(address(this));

        (, uint debt) = denManager.getDenCollAndDebt(msg.sender);
        uint debtToBurn = debt - borrowerOperations.DEBT_GAS_COMPENSATION();

        nectar.sendToPeriphery(msg.sender, debtToBurn);

        borrowerOperations.closeDen(
            address(denManager),
            msg.sender
        );

        uint sharesWithdrawn = collVault.balanceOf(address(this)) - prevSharesBalance;

        if (unwrap) {
            uint assetsWithdrawn = collVault.redeem(sharesWithdrawn, msg.sender, address(this));
            require(assetsWithdrawn >= minAssetsWithdrawn, "assetsWithdrawn < _minAssetsWithdrawn");
        } else {
            IERC20(address(collVault)).safeTransfer(msg.sender, sharesWithdrawn);
        }
    }

    function redeemCollateralVault(
        ICollVaultRouter.RedeemCollateralVaultParams memory params
    ) external {
        require(_isWhitelistedCollateralAt(address(params.collVault), params.collIndex), "Incorrect collateral");
        require(address(params.denManager.collateralToken()) == address(params.collVault), "Incorrect DenManager or Vault");

        uint prevSharesBalance = params.collVault.balanceOf(address(this));
        uint prevNectBalance = nectar.balanceOf(address(this));

        nectar.sendToPeriphery(msg.sender, params._debtAmount);

        params.denManager.redeemCollateral(
            params._debtAmount,
            params._firstRedemptionHint,
            params._upperPartialRedemptionHint,
            params._lowerPartialRedemptionHint,
            params._partialRedemptionHintNICR,
            params._maxIterations,
            params._maxFeePercentage
        );

        uint sharesWithdrawn = params.collVault.balanceOf(address(this)) - prevSharesBalance;
        require(sharesWithdrawn >= params._minSharesWithdrawn , "sharesWithdrawn < _minSharesWithdrawn");

        if (params.unwrap) {
            uint assetsWithdrawn = params.collVault.redeem(sharesWithdrawn, msg.sender, address(this));
            require(assetsWithdrawn >= params.minAssetsWithdrawn, "assetsWithdrawn < _minAssetsWithdrawn");
        } else {
            IERC20(address(params.collVault)).safeTransfer(msg.sender, sharesWithdrawn);
        }

        // Dust nect could be left if not all expected redemptions were made
        uint currentNectBalance = nectar.balanceOf(address(this));
        if (currentNectBalance > prevNectBalance) {
            nectar.transfer(msg.sender, currentNectBalance - prevNectBalance);
        }
    }

    function claimCollateralRouter(
        IDenManager denManager,
        IInfraredCollateralVault collVault,
        address receiver,
        uint minAssetsWithdrawn
    ) external {
        uint surplusBalance = denManager.surplusBalances(msg.sender);

        denManager.claimCollateral(msg.sender, address(this));

        uint assetsWithdrawn = collVault.redeem(surplusBalance, receiver, address(this));
        require(assetsWithdrawn >= minAssetsWithdrawn, "assetsWithdrawn < _minAssetsWithdrawn");
    }

    /// @dev Previewed amount withdrawn could be less if between offchain calculation and onchain execution, the earned amount is updated through `getRewardForUser`
     function previewRedeemUnderlying(
        IInfraredCollateralVault collVault,
        uint sharesToRedeem
    ) external view returns (address[] memory tokens, uint[] memory amounts) {
        DynamicArrayLib.DynamicArray memory _tokens;
        DynamicArrayLib.DynamicArray memory _amounts;

        // Simulate the redemption as if calling collVault.redeem()
        _simulateVaultRedemption(collVault, sharesToRedeem, _tokens, _amounts, false);

        tokens = _tokens.asAddressArray();
        amounts = _amounts.asUint256Array();
    }

    /**
     * @dev Recursively simulates a redemption on a given vault, including fee calculation,
     * proportionate distribution of rewarded tokens, and nested vault redemptions.
     */
    function _simulateVaultRedemption(
        IInfraredCollateralVault vault,
        uint sharesToRedeem,
        DynamicArrayLib.DynamicArray memory tokens,
        DynamicArrayLib.DynamicArray memory amounts,
        bool isNested
    ) internal view {
        SimRedeemVars memory v;

        v.netShares = isNested ? sharesToRedeem : sharesToRedeem - sharesToRedeem.feeOnRaw(vault.getWithdrawFee());
        v.totalSupply = vault.totalSupply();
        v.asset = vault.asset();

        // If not an InfraredVault, the try-catch just skips
        try vault.infraredVault() returns (IInfraredVault infraredVault) {
            v.earned = infraredVault.earned(v.asset, address(vault));
        } catch {}

        v.assetAmount = v.netShares.mulDiv(
            vault.getBalance(v.asset) + v.earned,
            v.totalSupply,
            Math.Rounding.Down
        );

        TokenValidationLib.aggregateIfNotExistent(v.asset, v.assetAmount, tokens, amounts);

        address[] memory allTokens = vault.tryGetRewardedTokens();

        for (uint256 i; i < allTokens.length; i++) {
            address token = allTokens[i];

            // Skip if it’s the primary asset
            if (token == v.asset) continue;

            try vault.infraredVault() returns (IInfraredVault infraredVault) {
                v.earned = infraredVault.earned(token, address(vault));
                if (token == address(ibgtVault)) {
                    // Internal earned amount not included, returned amount will probably be slightly lower
                    v.earned = ibgtVault.previewDeposit(v.earned);
                }
            } catch {
                v.earned = 0;
            }
            uint256 tokenBalance = vault.getBalance(token) + v.earned;
            if (tokenBalance == 0) continue;

            uint256 tokenAmount = v.netShares.mulDiv(tokenBalance, v.totalSupply, Math.Rounding.Down);
            if (tokenAmount == 0) continue;

            // Recursively simulate if token is a nested vault
            if (token == address(ibgtVault) && token != address(vault)) {
                IInfraredCollateralVault nestedVault = IInfraredCollateralVault(token);
                _simulateVaultRedemption(nestedVault, tokenAmount, tokens, amounts, true);
            } else {
                TokenValidationLib.aggregateIfNotExistent(token, tokenAmount, tokens, amounts);
            }
        }
    }

    function depositFromAny(
        DepositFromAnyParams calldata params
    ) external payable returns (uint shares) {
        require(params.dexCalldata.getSelector() == IOBRouter.swap.selector, "CollVaultRouter: Invalid dex selector");

        if (msg.value != 0) {
            require(params.inputToken == address(wBera), "Passed msg.value with non-WBERA vault");
            require(msg.value == params.inputAmount, "msg.value != inputAmount");
            wBera.deposit{value: params.inputAmount}();
        } else {
            IERC20(params.inputToken).safeTransferFrom(msg.sender, address(this), params.inputAmount);
        }

        address assetToken = params.collVault.asset();
        uint prevAssetTokenBalance = IERC20(assetToken).balanceOf(address(this));
        IERC20(params.inputToken).safeIncreaseAllowance(address(obRouter), params.inputAmount);
     
        // Will revert on dexCalldata generation if assetToken == inputToken
        (bool success, bytes memory retData) = address(obRouter).call(params.dexCalldata);

        if (!success) {
            retData.bubbleUpRevert();
        }

        // wrap assets 
        uint swappedAmount = IERC20(assetToken).balanceOf(address(this)) - prevAssetTokenBalance;
        require(swappedAmount >= params.outputMin, "Insufficient Output Amount");

        IERC20(assetToken).safeIncreaseAllowance(address(params.collVault), swappedAmount);
        shares = params.collVault.deposit(swappedAmount, params.outputReceiver);
        require(shares >= params.minSharesMinted, "Insufficient Share Amount");
    }
    
    function redeemToOne(
        RedeemToOneParams calldata params
    ) external {
        address[] memory tokens = params.collVault.tryGetRewardedTokens();
        (address[] memory rewardTokens, uint length) = tokens.tryGetRewardedTokensIncludingIbgtVault(params.collVault.asset(), ibgtVault);

        uint[] memory prevBalances = new uint[](length);

        for (uint i; i < length; i++) {
            prevBalances[i] = IERC20(rewardTokens[i]).balanceOf(address(this));
        }

        params.collVault.redeem(params.shares, address(this), msg.sender);

        uint prevTargetTokenBalance = IERC20(params.targetToken).balanceOf(params.receiver);
        // Swap reward tokens to target token
        for (uint i; i < length; i++) {
            address token = rewardTokens[i];

            uint amount = IERC20(token).balanceOf(address(this)) - prevBalances[i];
            if (token != params.targetToken) {
                if (amount > 0) {
                    IERC20(token).safeIncreaseAllowance(address(obRouter), amount);

                    IOBRouter.swapTokenInfo memory tokenInfo = IOBRouter.swapTokenInfo({
                        inputToken: token,
                        inputAmount: amount,
                        outputToken: params.targetToken,
                        outputQuote: params.outputQuotes[i],
                        outputMin: params.outputMins[i], // since we check total diff later, we don't need to pass min output amount
                        outputReceiver: params.receiver
                    });

                    obRouter.swap(tokenInfo, params.pathDefinitions[i], params.executor, params.referralCode);
                }
            } else {
                IERC20(token).safeTransfer(params.receiver, amount);
            }
        }

        uint targetTokenBalanceDelta = IERC20(params.targetToken).balanceOf(params.receiver) - prevTargetTokenBalance;
        require(targetTokenBalanceDelta >= params.minTargetTokenAmount, "Insufficient token amount");
    }

    function claimLockedTokens(IERC20[] memory tokens, uint[] memory amounts) external {
        require(msg.sender == metaBeraborrowCore.owner(), "Only owner");

        for (uint i; i < tokens.length; i++) {
            if (address(tokens[i]) == address(0xdead)) {
                (bool success,) = metaBeraborrowCore.feeReceiver().call{value: amounts[i]}("");
                require(success, "ETH transfer failed");
            } else {
                tokens[i].safeTransfer(metaBeraborrowCore.feeReceiver(), amounts[i]);
            }
        }
    }

    function _isWhitelistedCollateralAt(address collVault, uint index) private view returns (bool) {
        return IDenManager(borrowerOperations.denManagers(index)).collateralToken() == collVault;
    }

    function _validateVaultAndManager(
        IInfraredCollateralVault collVault,
        uint _collIndex,
        IDenManager denManager
    ) internal view returns(IERC20 vaultAsset) {
        require(_isWhitelistedCollateralAt(address(collVault), _collIndex), "Incorrect collateral");
        require(address(denManager.collateralToken()) == address(collVault), "Incorrect DenManager or Vault");
        vaultAsset = IERC20(collVault.asset());
    }


    receive() external payable {}
}