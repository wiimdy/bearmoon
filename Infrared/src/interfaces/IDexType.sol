// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IDexType {
    /// @notice Enum representing different DEX types
    enum DexType {
        UNISWAP_V2, // 0
        UNISWAP_V3, // 1
        SUSHISWAP_V2, // 2
        SUSHISWAP_V3, // 3
        CAMELOT_V3, // 4
        BEX, // 5
        KODIAK_V3, // 6
        KODIAK_V2, // 7
        STEER, // 8
        GAMMA // 9
    }

    /// @notice Emitted when the default DEX is set
    /// @param dex The DEX index
    event SetDefaultDex(uint8 dex);

    /// @notice Thrown when trying to use an unsupported DEX type
    error UnsupportedDexType();
}
