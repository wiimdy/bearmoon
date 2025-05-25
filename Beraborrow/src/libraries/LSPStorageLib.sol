// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

/*  Helper library for grabbing LSP data from offchain. Not part of the core Beraborrow system. */
library LSPStorageLib {
    uint private constant LiquidStabilityPoolStorageLocation = 0x3c2bbd5b01c023780ac7877400fd851b17fd98c152afdb1efc02015acd68a300;

    /* SLOTS */
    uint internal constant META_BERABORROW_CORE_SLOT = 0;
    uint internal constant FEE_RECEIVER_SLOT = 1;
    uint internal constant EXTRA_ASSETS_VALUES_SLOT = 2; // length of array
    uint internal constant EXTRA_ASSETS_INDEXES_MAPPING_SLOT = 3;
    uint internal constant FIRST_SUNSET_AND_EXT_SUNSET_INDEX_KEYS_SLOT = 4;
    uint internal constant COLLATERAL_TOKENS_SLOT = 5; // length of array
    uint internal constant SUNSET_INDEXES_MAPPING_SLOT = 6;
    uint internal constant INDEX_BY_COLLATERAL_MAPPING_SLOT = 7;
    uint internal constant THRESHOLD_MAPPING_SLOT = 8;
    uint internal constant BALANCE_MAPPING_SLOT = 9;
    uint internal constant EMISSION_SCHEDULE_MAPPING_SLOT = 10;
    uint internal constant FACTORY_PRTOCOL_MAPPING_SLOT = 11;
    uint internal constant LIQUIDATION_MANAGER_PROTOCOL_MAPPING_SLOT = 12;

    /* SLOTS_OFFSETS */
    uint internal constant EXTRA_ASSETS_ARRAY_SLOT = uint(keccak256(abi.encode(LiquidStabilityPoolStorageLocation + EXTRA_ASSETS_VALUES_SLOT)));
    uint internal constant COLLATERAL_TOKENS_ARRAY_SLOT = uint(keccak256(abi.encode(LiquidStabilityPoolStorageLocation + COLLATERAL_TOKENS_SLOT)));
    
    /* BITS_OFFSETS */
    // ILiquidStabilityPool.Queue
    uint internal constant FIRST_SUNSET_INDEX_KEY_BITS = 0;
    uint internal constant EXT_SUNSET_INDEX_KEY_BITS = 16;

    // ILiquidStabilityPool.SunsetIndex
    uint internal constant IDX = 0;
    uint internal constant EXPIRY = 128;

    // ILiquidStabilityPool.EmissionSchedule
    uint internal constant EMISSIONS = 0;
    uint internal constant LOCK_TIMESTAMP = 128;
    uint internal constant UNLOCK_RATE_PER_SECOND = 192;

    /* SLOTS GETTERS */

    function metaBeraborrowCoreSlot() internal pure returns (bytes32) {
        return bytes32(LiquidStabilityPoolStorageLocation + META_BERABORROW_CORE_SLOT);
    }

    function feeReceiverSlot() internal pure returns (bytes32) {
        return bytes32(LiquidStabilityPoolStorageLocation + FEE_RECEIVER_SLOT);
    }

    function extraAssetsValuesSlot() internal pure returns (bytes32) {
        return bytes32(LiquidStabilityPoolStorageLocation + EXTRA_ASSETS_VALUES_SLOT);
    }

    function extraAssetsArrayValuesSlot(uint index) internal pure returns (bytes32) {
        return bytes32(EXTRA_ASSETS_ARRAY_SLOT + index);
    }

    function extraAssetsIndexesMappingSlot(bytes32 value) internal pure returns (bytes32) {
        bytes32 slot = bytes32(LiquidStabilityPoolStorageLocation + EXTRA_ASSETS_INDEXES_MAPPING_SLOT);
        bytes memory data = abi.encode(value, slot);
        return keccak256(data);
    }

    function firstSunsetAndExtSunsetIndexKeysSlot() internal pure returns (bytes32) {
        return bytes32(LiquidStabilityPoolStorageLocation + FIRST_SUNSET_AND_EXT_SUNSET_INDEX_KEYS_SLOT);
    }

    function collateralTokensSlot() internal pure returns (bytes32) {
        return bytes32(LiquidStabilityPoolStorageLocation + COLLATERAL_TOKENS_SLOT);
    }

    function collateralTokensArraySlot(uint index) internal pure returns (bytes32) {
        return bytes32(COLLATERAL_TOKENS_ARRAY_SLOT + index);
    }

    function sunsetIndexesMappingSlot(uint16 value) internal pure returns (bytes32) {
        bytes32 slot = bytes32(LiquidStabilityPoolStorageLocation + SUNSET_INDEXES_MAPPING_SLOT);
        bytes memory data = abi.encode(value, slot);
        return keccak256(data);
    }

    function indexByCollateralMappingSlot(address value) internal pure returns (bytes32) {
        bytes32 slot = bytes32(LiquidStabilityPoolStorageLocation + INDEX_BY_COLLATERAL_MAPPING_SLOT);
        bytes memory data = abi.encode(value, slot);
        return keccak256(data);
    }

    function thresholdMappingSlot(bytes32 value) internal pure returns (bytes32) {
        bytes32 slot = bytes32(LiquidStabilityPoolStorageLocation + THRESHOLD_MAPPING_SLOT);
        bytes memory data = abi.encode(value, slot);
        return keccak256(data);
    }

    function balanceMappingSlot(address value) internal pure returns (bytes32) {
        bytes32 slot = bytes32(LiquidStabilityPoolStorageLocation + BALANCE_MAPPING_SLOT);
        bytes memory data = abi.encode(value, slot);
        return keccak256(data);
    }

    function emissionScheduleMappingSlot(address value) internal pure returns (bytes32) {
        bytes32 slot = bytes32(LiquidStabilityPoolStorageLocation + EMISSION_SCHEDULE_MAPPING_SLOT);
        bytes memory data = abi.encode(value, slot);
        return bytes32(uint(keccak256(data)));
    }

    function factoryProtocolMappingSlot(address value) internal pure returns (bytes32) {
        bytes32 slot = bytes32(LiquidStabilityPoolStorageLocation + FACTORY_PRTOCOL_MAPPING_SLOT);
        bytes memory data = abi.encode(value, slot);
        return bytes32(uint(keccak256(data)));
    }

    function liquidationManagerProtocolMappingSlot(address value) internal pure returns (bytes32) {
        bytes32 slot = bytes32(LiquidStabilityPoolStorageLocation + LIQUIDATION_MANAGER_PROTOCOL_MAPPING_SLOT);
        bytes memory data = abi.encode(value, slot);
        return bytes32(uint(keccak256(data)));
    }
}