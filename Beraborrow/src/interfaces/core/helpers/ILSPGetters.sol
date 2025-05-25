// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface ILiquidStabilityPoolGetters {
    function beraborrowCore() external view returns (address);
    function liquidationManager() external view returns (address);
    function factory() external view returns (address);
    function feeReceiver() external view returns (address);
    function extraAssets() external view returns (address[] memory);
    function extraAssetsIndex(address asset) external view returns (uint256);
    function firstSunsetIndexKey() external view returns (uint16);
    function nextSunsetIndexKey() external view returns (uint16);
    function collateralTokens() external view returns (address[] memory);
    function sunsetIndexIdx(uint16 index) external view returns (uint128);
    function sunsetIndexExpiry(uint16 index) external view returns (uint128);
    function indexByCollateral(address collateral) external view returns (uint256);
    function balance(address account) external view returns (uint256);
    function threshold(bytes32 key) external view returns (uint256);
    function emissionScheduleEmissions(address token) external view returns (uint128);
    function emissionScheduleLockTimestamp(address token) external view returns (uint64);
    function emissionScheduleUnlockRatePerSecond(address token) external view returns (uint64);
    function getFullProfitUnlockTimestamp(address token) external view returns (uint);
    function unlockedEmissions(address token) external view returns (uint);
    function getBalanceOfWithFutureEmissions(address token) external view returns (uint);
    function getThreshold(address tokenIn, address tokenOut) external view returns (uint);
    function unlockedTokenEmissions(address token) external view returns (uint);
    function getTokenVirtualBalance(address token) external view returns (uint);
    function containsExtraAsset(address token) external view returns (bool);
}
