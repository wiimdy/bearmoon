// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {DynamicArrayLib} from "solady/utils/DynamicArrayLib.sol";
import {IInfraredCollateralVault} from "src/interfaces/core/vaults/IInfraredCollateralVault.sol";

library TokenValidationLib {
    using DynamicArrayLib for DynamicArrayLib.DynamicArray;
    using DynamicArrayLib for address[];
    using DynamicArrayLib for uint[];

    error DuplicateToken();
    error InvalidToken();

    function checkForDuplicates(address[] memory tokens, uint length) internal pure {
        for (uint i; i < length; i++) {
            for (uint j = i + 1; j < length; j++) {
                if (tokens[i] == tokens[j]) revert DuplicateToken();
            }
        }
    }

    function checkValidToken(address token, address[] memory collaterals, uint collateralsLength, address nect, bool isExtraAsset) internal pure {
        if (isExtraAsset || token == nect) {
            return;
        }

        bool isCollateral;
        for (uint j; j < collateralsLength; j++) {
            if (collaterals[j] == token) {
                isCollateral = true;
                break;
            }
        }
        if (!isCollateral) revert InvalidToken();
    }

    function aggregateIfNotExistent(
        address token,
        uint amount, 
        DynamicArrayLib.DynamicArray memory tokens,
        DynamicArrayLib.DynamicArray memory amounts
    ) internal pure {
        uint index = tokens.indexOf(token);
        if (index != DynamicArrayLib.NOT_FOUND) {
            uint existingAmount = amounts.getUint256(index);
            amounts.set(index, existingAmount + amount);
        } else {
            tokens.p(token);
            amounts.p(amount);
        }
    }

    function contains(address[] memory tokenArray, address targetToken) internal pure returns (uint256) {
        uint256 length = tokenArray.length;
        for (uint256 i; i < length; ++i) {
            if (tokenArray[i] == targetToken) {
                return i + 1;
            }
        }
        return 0;
    }

    /// @dev If the ibgtVault is included in the rewardTokens list, it returns a new reward array that includes the rewardToken list from the ibgtVault.
    function tryGetRewardedTokensIncludingIbgtVault(
        address[] memory rewardTokens, 
        address collVaultAsset, 
        IInfraredCollateralVault ibgtVault
    ) internal view returns (address[] memory, uint256) {
        // Gets a new rewardToken array that includes collVaultAsset.
        (address[] memory newRewardTokens, uint256 length) = underlyingCollVaultAssets(rewardTokens, collVaultAsset);

        uint256 ibgtVaultIdx = contains(newRewardTokens, address(ibgtVault));
        // returns when ibgtVault is not included in rewardTokens array
        if(ibgtVaultIdx == 0) {
            return (newRewardTokens, length);
        }
        
        // replace ibgtVault with ibgt
        newRewardTokens[ibgtVaultIdx - 1] = ibgtVault.asset();

        address[] memory ibgtVaultRewardTokens = tryGetRewardedTokens(ibgtVault);

        if(ibgtVaultRewardTokens.length == 0) {
            return (newRewardTokens, length);
        }

        // finalRewardTokens length shouldn't be bigger than (length + ibgtVaultLength)
        uint256 ibgtVaultLength = ibgtVaultRewardTokens.length;
        address[] memory finalRewardTokens = new address[](length + ibgtVaultLength);
        uint256 finalLength;

        // Merge two arrays using the union set method
        for(uint256 i; i < length; ++i) {
            if(contains(ibgtVaultRewardTokens, newRewardTokens[i]) == 0) {
                finalRewardTokens[finalLength] = newRewardTokens[i];
                ++finalLength;
            }
        }

        for(uint256 i; i < ibgtVaultLength; ++i) {
            finalRewardTokens[finalLength] = ibgtVaultRewardTokens[i];
            ++finalLength;
        }

        assembly {
            mstore(finalRewardTokens, finalLength)
        }

        return (finalRewardTokens, finalLength);
    }

    /// @dev Checks if asset is included in reward tokens array (e.g. BBiBGT)
    /// @dev CollVault main asset goes at index (len - 1), if it is not included in reward tokens
    /// @dev The ordering is inlined with the `CollVaultRouter::previewRedeemUnderlying()` function
    function underlyingCollVaultAssets(address[] memory rewardTokens, address collVaultAsset) 
        internal 
        pure 
        returns (address[] memory, uint256) 
    {
        uint256 originalLength = rewardTokens.length;

        if(contains(rewardTokens, collVaultAsset) > 0) {
            return (rewardTokens, originalLength);
        }

        address[] memory _rewardTokens = new address[](originalLength + 1);

        for (uint i; i < originalLength; ++i) {
            _rewardTokens[i] = rewardTokens[i];
        }

        _rewardTokens[originalLength] = collVaultAsset;

        return (_rewardTokens, originalLength + 1);
    }

    /// @dev Vaults in LSP could still not have been upgrade to InfraredCollateralVault if there is no InfraredVault to earn PoL deployed yet
    function tryGetRewardedTokens(IInfraredCollateralVault collVault) internal view returns (address[] memory) {
        address[] memory rewardedTokens;
        try collVault.rewardedTokens() returns (address[] memory _rewardedTokens) {
            rewardedTokens = _rewardedTokens;
        } catch {}
        return rewardedTokens;
    }

    function underlyingAmounts(address[] calldata tokens, address account) internal view returns (uint[] memory amounts) {
        amounts = new uint[](tokens.length);
        
        for (uint i; i < tokens.length; i++) {
            amounts[i] = IERC20(tokens[i]).balanceOf(account);
        }
    }
}