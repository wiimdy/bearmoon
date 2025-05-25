// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {DynamicArrayLib} from "solady/utils/DynamicArrayLib.sol";
import {PriceLib} from "../libraries/PriceLib.sol";
import {IMetaBeraborrowCore} from "../interfaces/core/IMetaBeraborrowCore.sol";
import {TokenValidationLib} from "../libraries/TokenValidationLib.sol";
import {ILiquidStabilityPool} from "../interfaces/core/ILiquidStabilityPool.sol";
import {ILiquidStabilityPoolGetters} from "../interfaces/core/helpers/ILSPGetters.sol";
import {IInfraredCollateralVault} from "../interfaces/core/vaults/IInfraredCollateralVault.sol";
import {IPriceFeed} from "../interfaces/core/IPriceFeed.sol";
import {IAsset} from "../interfaces/utils/tokens/IAsset.sol";
import {ICollVaultRouter} from "../interfaces/periphery/ICollVaultRouter.sol";
import {ILSPRouter} from "../interfaces/periphery/ILSPRouter.sol";
import {IOBRouter} from "../interfaces/utils/integrations/IOBRouter.sol";
import {IWBera} from "../interfaces/utils/tokens/IWBERA.sol";
import {UtilsLib} from "../libraries/UtilsLib.sol";


/// @dev Doesn't have DelegatedOps functionality
contract LSPRouter is ILSPRouter {
    using SafeERC20 for IERC20;
    using PriceLib for uint;
    using TokenValidationLib for address;
    using TokenValidationLib for IInfraredCollateralVault;
    using TokenValidationLib for address[];
    using DynamicArrayLib for DynamicArrayLib.DynamicArray;
    using DynamicArrayLib for address[];
    using DynamicArrayLib for uint[];
    using UtilsLib for bytes;

    IWBera immutable wBera;
    ILiquidStabilityPool immutable lsp;
    ILiquidStabilityPoolGetters immutable lspGetters;
    ICollVaultRouter immutable collVaultRouter;
    address immutable nect;
    IInfraredCollateralVault immutable IbgtVault;
    uint8 immutable nectDecimals;
    IPriceFeed immutable priceFeed;
    IMetaBeraborrowCore immutable metaBeraborrowCore;
    IOBRouter immutable obRouter;

    struct Arr {
        uint length;
        uint[] prevAmounts;
        address receiver;
    }

    constructor(address _lsp, address _lspGetters, address _collVaultRouter, address _priceFeed, address _metaBeraborrowCore, address _obRouter, address _wBera, address _IbgtVault) {
        if (_lsp == address(0) || _lspGetters == address(0) || _collVaultRouter == address(0) || _priceFeed == address(0) || _metaBeraborrowCore == address(0) || _obRouter == address(0) || _wBera == address(0) || _IbgtVault == address(0)) {
            revert("LSPRouter: 0 address");
        }

        lsp = ILiquidStabilityPool(_lsp);
        lspGetters = ILiquidStabilityPoolGetters(_lspGetters);
        collVaultRouter = ICollVaultRouter(_collVaultRouter);
        priceFeed = IPriceFeed(_priceFeed);
        metaBeraborrowCore = IMetaBeraborrowCore(_metaBeraborrowCore);
        obRouter = IOBRouter(_obRouter);
        wBera = IWBera(_wBera);

        IbgtVault = IInfraredCollateralVault(_IbgtVault);
        nect = lsp.asset();
        nectDecimals = IAsset(nect).decimals();
    }

    /**
     * @notice Redeems sNECT for preferred underlying tokens, features unwrapping and multiple levels of slippage protection
     * @dev If no unwrapping, tokens are directly sent to the receiver, if unwrapping, tokens are sent to the receiver after unwrapping
     * @dev If any token does calls, a griefer could get control of the transaction flow and potentially withdraw locked tokens by increasing the amount received when not unwrapping
     * 
     * @param params Struct containing the following parameters:
     * - shares: Amount of sNECT to burn
     * - preferredUnderlyingTokens: Array sorted by preference of withdrawal
     * - receiver: Address to receive the underlying tokens
     * - _owner: Address of the sNECT owner
     * - minAssetsWithdrawn: Minimum expected of assets denominated in $NECT to be withdrawn
     * - minUnderlyingWithdrawn: Array of minimum expected amounts of collVaults underlying tokens to be withdrawn, index corresponds to preferredUnderlyingTokens, set 0 if not collVault, and empty if not unwrapping
     * - unwrap: Whether to unwrap collVaults underlying tokens
     */
    function redeemPreferredUnderlying(
        ILSPRouter.RedeemPreferredUnderlyingParams calldata params
    ) external returns (uint assets, address[] memory tokens, uint[] memory amounts) {
        Arr memory arr = _initArr(params.preferredUnderlyingTokens, params.unwrap ? address(this) : params.receiver);

        assets = lsp.redeem(params.shares, params.preferredUnderlyingTokens, arr.receiver, msg.sender);
        require(assets >= params.minAssetsWithdrawn, "LSPRouter: assetsWithdrawn < minAssetsWithdrawn");
    
        address[] memory _tokens = new address[](params.redeemedTokensLength);    
        uint[] memory _amounts = new uint[](params.redeemedTokensLength);
        uint[] memory currAmounts = params.preferredUnderlyingTokens.underlyingAmounts(arr.receiver);
        bool firstCollVaultFound;
        
        if (params.unwrap) {
            for (uint i; i < arr.length; i++) {
                uint amount = currAmounts[i] - arr.prevAmounts[i];
                if (amount > 0) {
                    if (priceFeed.isCollVault(params.preferredUnderlyingTokens[i])) {
                        if (!firstCollVaultFound) {
                            _addIbgtVaultRewardTokens(_tokens);
                            firstCollVaultFound = true;
                        }
                        IInfraredCollateralVault collVault = IInfraredCollateralVault(params.preferredUnderlyingTokens[i]);

                        _withdrawUnderlyingCollVaultAssets(
                            collVault,
                            amount,
                            params.minUnderlyingWithdrawn[i],
                            _tokens
                        );
                    } else {
                        _aggregateIfNotExistentWithoutAmounts(_tokens, params.preferredUnderlyingTokens[i]);
                    }
                }
            }
            uint tokensLength = _tokens.length;
            for (uint i; i < tokensLength; i++) {
                // It may transfer additional dust amount left in the contract          
                _amounts[i] = IERC20(_tokens[i]).balanceOf(address(this));
                IERC20(_tokens[i]).safeTransfer(params.receiver, _amounts[i]);
            }
            tokens = _tokens;
            amounts = _amounts;
        } else {
            tokens = params.preferredUnderlyingTokens;
            amounts = new uint[](arr.length);
            for (uint i; i < arr.length; i++) {
                amounts[i] = currAmounts[i] - arr.prevAmounts[i];
            }
        }
    }

    /// @notice First token of `params.preferredUnderlyingTokens` is the target token, if it's a collVault, it's the asset token of the collVault
    /// @dev Auto unwraps and swaps all to the target token
    function redeemPreferredUnderlyingToOne(
        ILSPRouter.RedeemPreferredUnderlyingToOneParams calldata params
    ) external returns (uint assets, uint totalAmountOut) {
        require(params.preferredUnderlyingTokens.length > 0, "tokens length is zero");
        Arr memory arr = _initArr(params.preferredUnderlyingTokens, address(this));

        assets = lsp.redeem(params.shares, params.preferredUnderlyingTokens, arr.receiver, msg.sender);
        require(assets >= params.minAssetsWithdrawn, "LSPRouter: assetsWithdrawn < minAssetsWithdrawn");
        address[] memory _tokens = new address[](params.redeemedTokensLength);
        bool firstCollVaultFound;

        uint[] memory currAmounts = params.preferredUnderlyingTokens.underlyingAmounts(address(this));
        for (uint i; i < arr.length; i++) {
            uint amount = currAmounts[i] - arr.prevAmounts[i];
            if (amount > 0) {
                if (priceFeed.isCollVault(params.preferredUnderlyingTokens[i])) {
                    if (!firstCollVaultFound) {
                        _addIbgtVaultRewardTokens(_tokens);
                        firstCollVaultFound = true;
                    }
                    IInfraredCollateralVault collVault = IInfraredCollateralVault(params.preferredUnderlyingTokens[i]);

                    _withdrawUnderlyingCollVaultAssets(
                        collVault,
                        amount,
                        params.minUnderlyingWithdrawn[i],
                        _tokens
                    );
                } else {
                    _aggregateIfNotExistentWithoutAmounts(_tokens,  params.preferredUnderlyingTokens[i]);
                }
            } 
        }       

        uint[] memory swapAmounts = new uint[](params.redeemedTokensLength);        
        for (uint i; i < params.redeemedTokensLength; i++) {
            swapAmounts[i] = IERC20(_tokens[i]).balanceOf(address(this));
        }
   
        totalAmountOut = _swapToTargetToken(
            params.targetToken,
            ILSPRouter.SwapAllTokensToOneParams({
                receiver: params.receiver,
                pathDefinitions: params.pathDefinitions,
                minOutputs: params.minOutputs,
                quoteAmounts: params.quoteAmounts,
                minTargetTokenAmount: params.minTargetTokenAmount,
                executor: params.executor,
                referralCode: params.referralCode
            }),
            _tokens,
            swapAmounts
        );
    }
    
    function redeem(
        ILSPRouter.RedeemWithoutPrederredUnderlyingParams calldata params
    ) external returns (uint assets, address[] memory tokens, uint[] memory amounts) {
        // Get collateral tokens directly from LSP
        Arr memory arr = _initArr(params.tokensToClaim, params.unwrap ? address(this) : params.receiver);
        // Call redeem without preferred tokens
        assets = lsp.redeem(params.shares, arr.receiver, msg.sender);
        require(assets >= params.minAssetsWithdrawn, "LSPRouter: assetsWithdrawn < minAssetsWithdrawn");

        uint length = params.unwrap ? params.receivedTokensLengthHint : params.tokensToClaim.length;
        address[] memory _tokens = new address[](length);
        uint[] memory _amounts = new uint[](length);
        uint[] memory currAmounts = params.tokensToClaim.underlyingAmounts(arr.receiver);

        if (params.unwrap) {
            _addIbgtVaultRewardTokens(_tokens);
            for (uint i; i < arr.length; i++) {
                uint amount = currAmounts[i] - arr.prevAmounts[i];
                if (amount > 0) {           
                    if (priceFeed.isCollVault(params.tokensToClaim[i])) {
                        IInfraredCollateralVault collVault = IInfraredCollateralVault(params.tokensToClaim[i]);
                
                        _withdrawUnderlyingCollVaultAssets(
                            collVault,
                            amount,
                            params.minUnderlyingWithdrawn[i],
                            _tokens
                        );
                    } else {
                        _aggregateIfNotExistentWithoutAmounts(_tokens, params.tokensToClaim[i]);
                    }
                }
            }
            for (uint i; i < length; i++) {                
                _amounts[i] = IERC20(_tokens[i]).balanceOf(address(this));          
                IERC20(_tokens[i]).safeTransfer(params.receiver, _amounts[i]);
            }
            tokens = _tokens;
            amounts = _amounts;
        } else {
            tokens = params.tokensToClaim;
            amounts = new uint[](arr.length);
            for (uint i; i < arr.length; i++) {
                amounts[i] = currAmounts[i] - arr.prevAmounts[i];
            }
        }
    }

    function withdraw(
        ILSPRouter.WithdrawFromlspParams calldata params
    ) external returns (uint shares, address[] memory tokens, uint[] memory amounts) {
        // Get collateral tokens directly from LSP
        // maybe not received but claimed
        Arr memory arr = _initArr(params.tokensToClaim, params.unwrap ? address(this) : params.receiver);
        // Call redeem without preferred tokens
        shares = lsp.withdraw(params.assets, arr.receiver, msg.sender);
        require(shares <= params.maxSharesWithdrawn, "LSPRouter: sharesWithdrawn > maxSharesWithdrawn");  

        uint length = params.unwrap ? params.receivedTokensLengthHint : params.tokensToClaim.length;
        address[] memory _tokens = new address[](length);
        uint[] memory _amounts = new uint[](length);
        uint[] memory currAmounts = params.tokensToClaim.underlyingAmounts(arr.receiver);

        if (params.unwrap) {
            _addIbgtVaultRewardTokens(_tokens);
            for (uint i; i < arr.length; i++) {
                uint amount = currAmounts[i] - arr.prevAmounts[i];
                if (amount > 0) {           
                    if (priceFeed.isCollVault(params.tokensToClaim[i])) {
                        IInfraredCollateralVault collVault = IInfraredCollateralVault(params.tokensToClaim[i]);
                
                        _withdrawUnderlyingCollVaultAssets(
                            collVault,
                            amount,
                            params.minUnderlyingWithdrawn[i],
                            _tokens
                        );
                    } else {
                        _aggregateIfNotExistentWithoutAmounts(_tokens, params.tokensToClaim[i]);
                    }
                }
            }
            for (uint i; i < length; i++) {                
                _amounts[i] = IERC20(_tokens[i]).balanceOf(address(this));          
                IERC20(_tokens[i]).safeTransfer(params.receiver, _amounts[i]);
            }
            tokens = _tokens;
            amounts = _amounts;
        } else {
            tokens = params.tokensToClaim;
            amounts = new uint[](arr.length);
            for (uint i; i < arr.length; i++) {
                amounts[i] = currAmounts[i] - arr.prevAmounts[i];
            }
        }
    }
 
    function deposit(
        DepositTokenParams calldata params
    ) external payable returns (uint shares) {
        require(params.dexCalldata.getSelector() == IOBRouter.swap.selector, "LSPRouter: Invalid dex selector");
        address assetToken = nect;
        uint assets;

        if (msg.value != 0) {
            require(params.inputToken == address(wBera), "Passed msg.value with non-WBERA");
            require(msg.value == params.inputAmount, "msg.value != inputAmount");
            wBera.deposit{value: params.inputAmount}();
        } else {
            IERC20(params.inputToken).safeTransferFrom(msg.sender, address(this), params.inputAmount);
        }

        // If input token is not nect, swap it to nect
        if (params.inputToken != assetToken) {
            IERC20(params.inputToken).safeIncreaseAllowance(address(obRouter), params.inputAmount);            
            uint prevBalance = IERC20(assetToken).balanceOf(address(this));

            (bool success, bytes memory retData) = address(obRouter).call(params.dexCalldata);
            if (!success) {
                retData.bubbleUpRevert();
            }               

            assets = IERC20(assetToken).balanceOf(address(this)) - prevBalance;
        } else {
            assets = params.inputAmount;
        }

        IERC20(assetToken).approve(address(lsp), assets);
        shares = lsp.deposit(assets, params.receiver);
        require(shares >= params.minSharesReceived, "LSPRouter: received shares less than minimum");
    }

    function _swapToTargetToken(
        address targetToken,
        ILSPRouter.SwapAllTokensToOneParams memory params,
        address[] memory _tokens,
        uint[] memory _amounts
    ) private returns (uint targetTokenAmountOut) {
        uint tokensLength = _tokens.length;

        uint prevTargetTokenAmount = IERC20(targetToken).balanceOf(params.receiver);

        for (uint i; i < tokensLength; i++) {
            uint amount = _amounts[i];
            address _token = _tokens[i];
            if (_token != targetToken) {
                if (params.pathDefinitions[i].length > 0) {                   
                    IOBRouter.swapTokenInfo memory tokenInfo = IOBRouter.swapTokenInfo({
                        inputToken: _token,
                        inputAmount: amount,
                        outputToken: targetToken,
                        outputQuote: params.quoteAmounts[i],
                        outputMin: params.minOutputs[i],
                        outputReceiver: params.receiver
                    });

                    IERC20(_token).safeIncreaseAllowance(address(obRouter), amount);
                    obRouter.swap(tokenInfo, params.pathDefinitions[i], params.executor, params.referralCode);
                }
            } else {
                IERC20(targetToken).safeTransfer(params.receiver, amount);
            }
        }

        targetTokenAmountOut = IERC20(targetToken).balanceOf(params.receiver) - prevTargetTokenAmount;
        require(targetTokenAmountOut >= params.minTargetTokenAmount, "LSPRouter: targetTokenAmountOut < minTargetTokenAmount");
    }

    function _withdrawUnderlyingCollVaultAssets(
        IInfraredCollateralVault collVault,
        uint amount,
        uint minUnderlyingWithdrawn,
        address[] memory tokens
    ) private {
        // Note: We acknowledge that it may not have track of newly added tokens to the underlying InfraredVault
        address[] memory underlyingTokens = collVault.tryGetRewardedTokens();
        (address[] memory rewardTokens, uint length) = underlyingTokens.underlyingCollVaultAssets(collVault.asset());        

        {
            uint collVaultAssetsWithdrawn = collVault.redeem(amount, address(this), address(this));
            require(collVaultAssetsWithdrawn >= minUnderlyingWithdrawn, "LSPRouter: collVaultAssetsWithdrawn < minUnderlyingWithdrawn");
        }        

        for (uint i; i < length; i++) {        
            // if token is ibgtvault continue as it is unwrapped at vault lvl
            if (rewardTokens[i] == address(IbgtVault)) continue;
            _aggregateIfNotExistentWithoutAmounts(tokens, rewardTokens[i]); 
        }
    }

    function previewRedeemPreferredUnderlying(uint shares, address[] calldata preferredUnderlyingTokens, bool unwrap) external view returns (uint assets, address[] memory tokens, uint[] memory amounts) {
        uint length = preferredUnderlyingTokens.length;
        
        // Get sNECT collateral + extra assets + NECT withdraw amounts based on share amount
        assets = lsp.previewRedeem(shares);
        uint[] memory expectedAmounts = _simulateWithdrawPreferredUnderlying(assets, preferredUnderlyingTokens);       

        DynamicArrayLib.DynamicArray memory _tokens;
        DynamicArrayLib.DynamicArray memory _amounts;
        bool firstCollVaultFound;

        if (unwrap) {
            for (uint i; i < length; i++) {
                address token = preferredUnderlyingTokens[i];
                if (expectedAmounts[i] > 0) {
                    if (priceFeed.isCollVault(token)) {
                        // If first collVault found, add ibgtVault reward tokens, since all collVaults deposit iBGT into iBGTVault
                        if (!firstCollVaultFound) {
                            address[] memory ibgtRewardedTokens = IbgtVault.tryGetRewardedTokens();
                            uint ibgtRewardedLength = ibgtRewardedTokens.length;
                            for (uint j; j < ibgtRewardedLength; j++) {
                                TokenValidationLib.aggregateIfNotExistent(ibgtRewardedTokens[j], 0, _tokens, _amounts);
                            }
                            firstCollVaultFound = true;
                        }
                        IInfraredCollateralVault collVault = IInfraredCollateralVault(token);

                        _previewWithdrawUnderlyingCollVaultAssets(
                            collVault,
                            expectedAmounts[i],
                            _tokens,
                            _amounts
                        );
                    } else {
                        TokenValidationLib.aggregateIfNotExistent(token, expectedAmounts[i], _tokens, _amounts);
                    }
                }
            }

            tokens = _tokens.asAddressArray();
            amounts = _amounts.asUint256Array();
         
        } else {
            for (uint i; i < length; i++) {
                if (expectedAmounts[i] > 0) {
                    TokenValidationLib.aggregateIfNotExistent(preferredUnderlyingTokens[i], expectedAmounts[i], _tokens, _amounts);
                }
            }
            tokens = _tokens.asAddressArray();
            amounts = _amounts.asUint256Array();
        }        
   

    }

    /// @dev Reproduces the internal function `LSP::_withdrawPreferredUnderlying`
    /// @dev Remaining assets should always be 0 after the loop
    function _simulateWithdrawPreferredUnderlying(uint assets, address[] memory preferredUnderlyingTokens) private view returns (uint[] memory amounts) {
        address[] memory collaterals = lsp.getCollateralTokens();
        address[] memory extraAssets = lspGetters.extraAssets();
        uint collateralsLength = collaterals.length;
        uint length = preferredUnderlyingTokens.length;
        amounts = new uint[](length);
        
        require(length == collateralsLength + extraAssets.length + 1, "LSPRouter: preferredUnderlyingTokens length mismatch");
        require(preferredUnderlyingTokens[length - 1] == nect, "LSPRouter: Last token must be NECT");
        preferredUnderlyingTokens.checkForDuplicates(length);

        uint remainingAssets = assets;
        uint nectPrice = priceFeed.fetchPrice(nect);

        for (uint i; i < length && remainingAssets != 0; i++) {
            address token = preferredUnderlyingTokens[i];

            token.checkValidToken(collaterals, collateralsLength, nect, lspGetters.containsExtraAsset(token));

            uint unlockedBalance = lspGetters.getTokenVirtualBalance(token);
            if (unlockedBalance == 0) continue;
            uint tokenPrice = priceFeed.fetchPrice(token);
            if (tokenPrice == 0) continue;
            uint8 tokenDecimals = IAsset(token).decimals();

            uint amount = remainingAssets.convertAssetsToCollAmount(
                tokenPrice,
                nectPrice,
                nectDecimals,
                tokenDecimals,
                Math.Rounding.Down
            );

            if (unlockedBalance >= amount) {
                remainingAssets = 0;
            } else {
                uint remainingColl = amount - unlockedBalance;
                remainingAssets = remainingColl.convertCollAmountToAssets(
                    tokenPrice,
                    nectPrice,
                    nectDecimals,
                    tokenDecimals
                );
                amount = unlockedBalance;
            }

            if (amount > 0) {
                amounts[i] = amount;
            }
        }
    }

    function _previewWithdrawUnderlyingCollVaultAssets(
        IInfraredCollateralVault collVault,
        uint amount,
        DynamicArrayLib.DynamicArray memory tokens,
        DynamicArrayLib.DynamicArray memory amounts
    ) private view {
        (address[] memory _expectedTokens, uint[] memory _expectedAmounts) = collVaultRouter.previewRedeemUnderlying(collVault, amount);
        uint length = _expectedTokens.length;

        for (uint i; i < length; i++) {
            uint vaultUnderlyingAmount = _expectedAmounts[i];
            address token = _expectedTokens[i];

            if (vaultUnderlyingAmount > 0) {
                TokenValidationLib.aggregateIfNotExistent(token, vaultUnderlyingAmount, tokens, amounts);
            }
        }
    }

    function lspUnderlyingTokens() external view returns (address[] memory tokens) {
        address[] memory collaterals = lspGetters.collateralTokens();
        address[] memory extraAssets = lspGetters.extraAssets();
        uint collateralsLength = collaterals.length;
        uint extraAssetsLength = extraAssets.length;
        uint length = collateralsLength + extraAssetsLength + 1;

        tokens = new address[](length);

        for (uint i; i < collateralsLength; i++) {
            tokens[i] = collaterals[i];
        }

        for (uint i = collateralsLength; i < length - 1; i++) {
            tokens[i] = extraAssets[i - collateralsLength];
        }

        tokens[length - 1] = nect;
    }

    function claimLockedTokens(IERC20[] calldata tokens, uint[] calldata amounts) external {
        require(msg.sender == metaBeraborrowCore.owner(), "Only owner");

        uint length = tokens.length;
        for (uint i; i < length; i++) {
            if (address(tokens[i]) == address(0)) {
                (bool success,) = metaBeraborrowCore.feeReceiver().call{value: amounts[i]}("");
                require(success, "ETH transfer failed");
            } else {
                tokens[i].safeTransfer(metaBeraborrowCore.feeReceiver(), amounts[i]);
            }
        }
    }

    /// @notice Aggregates token if not in the array
    /// @dev Warning, modifies memory references
    function _aggregateIfNotExistentWithoutAmounts(
        address[] memory tokens,
        address token
    ) internal pure {
        uint length = tokens.length;
        for (uint i; i < length; i++) {
            if (tokens[i] == token) {
                return;
            }
            if (tokens[i] == address(0)) {
                tokens[i] = token;
                return;
            }
        }
        revert("LSPRouter: array full");
    }

    function _addIbgtVaultRewardTokens(address[] memory tokens) internal view {
        address[] memory ibgtRewardedTokens = IbgtVault.tryGetRewardedTokens();        
        for (uint i; i < ibgtRewardedTokens.length; i++) {
            _aggregateIfNotExistentWithoutAmounts(tokens, ibgtRewardedTokens[i]);
        }
    }

    function _initArr(address[] calldata preferredUnderlyingTokens, address account) private view returns (Arr memory arr) {
        arr.length = preferredUnderlyingTokens.length;
        arr.prevAmounts = preferredUnderlyingTokens.underlyingAmounts(account);
        arr.receiver = account;
    }
}