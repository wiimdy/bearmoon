// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {BeraborrowMath} from "../../dependencies/BeraborrowMath.sol";
import {ILiquidStabilityPool} from "../../interfaces/core/ILiquidStabilityPool.sol";
import {LSPStorageLib} from "../../libraries/LSPStorageLib.sol";
import {EmissionsLib} from "../../libraries/EmissionsLib.sol";

/*  Helper contract for grabbing LSP data from offchain. Not part of the core Beraborrow system. */
contract LiquidStabilityPoolGetters {
    ILiquidStabilityPool public immutable lsp;

    constructor(ILiquidStabilityPool _lsp) {
        lsp = _lsp;
    }

    function beraborrowCore() external view returns (address) {
        bytes32[] memory slot = _array(LSPStorageLib.metaBeraborrowCoreSlot());
        return address(uint160(uint(lsp.extSloads(slot)[0])));
    }

    // Previously named getFeeReceiver
    function feeReceiver() external view returns (address) {
        bytes32[] memory slot = _array(LSPStorageLib.feeReceiverSlot());
        return address(uint160(uint(lsp.extSloads(slot)[0])));
    }

    // Previously named getExtraAssets
    function extraAssets() public view returns (address[] memory res) {
        bytes32[] memory slot = _array(LSPStorageLib.extraAssetsValuesSlot());
        uint256 len = uint(lsp.extSloads(slot)[0]);

        res = new address[](len);
        for (uint256 i; i < len; i++) {
            slot = _array(bytes32(LSPStorageLib.extraAssetsArrayValuesSlot(i)));
            res[i] = address(uint160(uint(lsp.extSloads(slot)[0])));
        }
    }

    function extraAssetsIndex(address asset) public view returns (uint256) {
        bytes32 value = bytes32(uint(uint160(asset)));
        bytes32[] memory slot = _array(LSPStorageLib.extraAssetsIndexesMappingSlot(value));
        return uint(lsp.extSloads(slot)[0]);
    }

    function firstSunsetIndexKey() external view returns (uint16) {
        bytes32[] memory slot = _array(LSPStorageLib.firstSunsetAndExtSunsetIndexKeysSlot());
        return uint16(uint(lsp.extSloads(slot)[0]));
    }

    function nextSunsetIndexKey() external view returns (uint16) {
        bytes32[] memory slot = _array(LSPStorageLib.firstSunsetAndExtSunsetIndexKeysSlot());
        return uint16(uint(lsp.extSloads(slot)[0] >> LSPStorageLib.EXT_SUNSET_INDEX_KEY_BITS));
    }

    function collateralTokens() external view returns (address[] memory res) {
        bytes32[] memory slot = _array(LSPStorageLib.collateralTokensSlot());
        uint256 len = uint(lsp.extSloads(slot)[0]);

        res = new address[](len);
        for (uint256 i; i < len; i++) {
            slot = _array(bytes32(LSPStorageLib.collateralTokensArraySlot(i)));
            res[i] = address(uint160(uint(lsp.extSloads(slot)[0])));
        }
    }

    function sunsetIndexIdx(uint16 index) external view returns (uint128) {
        bytes32[] memory slot = _array(LSPStorageLib.sunsetIndexesMappingSlot(index));
        return uint128(uint(lsp.extSloads(slot)[0]));
    }

    function sunsetIndexExpiry(uint16 index) external view returns (uint128) {
        bytes32[] memory slot = _array(LSPStorageLib.sunsetIndexesMappingSlot(index));
        return uint128(uint(lsp.extSloads(slot)[0] >> LSPStorageLib.EXPIRY));
    }

    // Previously named getIndexByCollateral
    function indexByCollateral(address collateral) external view returns (uint256) {
        bytes32[] memory slot = _array(LSPStorageLib.indexByCollateralMappingSlot(collateral));
        return uint(lsp.extSloads(slot)[0]);
    }

    function balance(address account) public view returns (uint256) {
        bytes32[] memory slot = _array(LSPStorageLib.balanceMappingSlot(account));
        return uint(lsp.extSloads(slot)[0]);
    }

    function threshold(bytes32 key) public view returns (uint256) {
        bytes32[] memory slot = _array(LSPStorageLib.thresholdMappingSlot(key));
        return uint(lsp.extSloads(slot)[0]);
    }

    function emissionScheduleEmissions(address token) public view returns (uint128) {
        bytes32[] memory slot = _array(LSPStorageLib.emissionScheduleMappingSlot(token));
        return uint128(uint(lsp.extSloads(slot)[0]));
    }

    // Previously named getLastTimestampUpdate
    function emissionScheduleLockTimestamp(address token) public view returns (uint64) {
        bytes32[] memory slot = _array(LSPStorageLib.emissionScheduleMappingSlot(token));
        return uint64(uint(lsp.extSloads(slot)[0] >> LSPStorageLib.LOCK_TIMESTAMP));
    }

    // Previously named getUnlockRatePerSecond
    function emissionScheduleUnlockRatePerSecond(address token) public view returns (uint64) {
        bytes32[] memory slot = _array(LSPStorageLib.emissionScheduleMappingSlot(token));
        return uint64(uint(lsp.extSloads(slot)[0] >> LSPStorageLib.UNLOCK_RATE_PER_SECOND));
    }

    function isFactory(address factory) external view returns (bool) {
        bytes32[] memory slot = _array(LSPStorageLib.factoryProtocolMappingSlot(factory));
        return uint(lsp.extSloads(slot)[0]) == 1;
    }

    function isLiquidationManager(address liquidationManager) external view returns (bool) {
        bytes32[] memory slot = _array(LSPStorageLib.liquidationManagerProtocolMappingSlot(liquidationManager));
        return uint(lsp.extSloads(slot)[0]) == 1;
    }

    // Helper functions

    function getFullProfitUnlockTimestamp(address token) external view returns (uint) {
        // If 0 is because it's unused on EmissionsLib function
        EmissionsLib.EmissionSchedule memory schedule = EmissionsLib.EmissionSchedule({
            emissions: 0,
            lockTimestamp: emissionScheduleLockTimestamp(token),
            _unlockRatePerSecond: emissionScheduleUnlockRatePerSecond(token)
        });

        return EmissionsLib.unlockTimestamp(schedule);
    }

    function unlockedEmissions(address token) external view returns (uint) {
        EmissionsLib.EmissionSchedule memory schedule = EmissionsLib.EmissionSchedule({
            emissions: emissionScheduleEmissions(token),
            lockTimestamp: emissionScheduleLockTimestamp(token),
            _unlockRatePerSecond: emissionScheduleUnlockRatePerSecond(token)
        });

        return EmissionsLib.unlockedEmissions(schedule);
    }

    function unlockRatePerSecond(address token) external view returns (uint) {
        EmissionsLib.EmissionSchedule memory schedule = EmissionsLib.EmissionSchedule({
            emissions: 0,
            lockTimestamp: 0,
            _unlockRatePerSecond: emissionScheduleUnlockRatePerSecond(token)
        });

        return EmissionsLib.unlockRatePerSecond(schedule);
    }

    function getBalanceOfWithFutureEmissions(address token) external view returns (uint) {
        return balance(token);
    }

    function getThreshold(address tokenIn, address tokenOut) external view returns (uint) {
        bytes32 hash = keccak256(abi.encodePacked(tokenIn, tokenOut));
        return threshold(hash);
    }

    /**
     * @notice Unlocked collateral and extra assets balances
     */
    function getTokenVirtualBalance(address token) public view returns (uint) {
        EmissionsLib.EmissionSchedule memory schedule = EmissionsLib.EmissionSchedule({
            emissions: emissionScheduleEmissions(token),
            lockTimestamp: emissionScheduleLockTimestamp(token),
            _unlockRatePerSecond: emissionScheduleUnlockRatePerSecond(token)
        });

        return balance(token) - EmissionsLib.lockedEmissions(schedule, EmissionsLib.unlockTimestamp(schedule));
    }

    function containsExtraAsset(address token) external view returns (bool) {
        return extraAssetsIndex(token) != 0;
    }

    function _array(bytes32 x) private pure returns (bytes32[] memory) {
        bytes32[] memory res = new bytes32[](1);
        res[0] = x;
        return res;
    }
}