// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

interface IFactory {
    // commented values are suggested default parameters
    struct DeploymentParams {
        uint256 minuteDecayFactor; // 999037758833783000  (half life of 12 hours)
        uint256 redemptionFeeFloor; // 1e18 / 1000 * 5  (0.5%)
        uint256 maxRedemptionFee; // 1e18  (100%)
        uint256 borrowingFeeFloor; // 1e18 / 1000 * 5  (0.5%)
        uint256 maxBorrowingFee; // 1e18 / 100 * 5  (5%)
        uint256 interestRateInBps; // 100 (1%)
        uint256 maxDebt;
        uint256 MCR; // 12 * 1e17  (120%)
        address collVaultRouter; // set to address(0) if DenManager coll is not CollateralVault
    }

    event NewDeployment(address collateral, address priceFeed, address denManager, address sortedDens);

    function deployNewInstance(
        address collateral,
        address priceFeed,
        address customDenManagerImpl,
        address customSortedDensImpl,
        DeploymentParams calldata params,
        uint64 unlockRatePerSecond,
        bool forceThroughLspBalanceCheck
    ) external;

    function setImplementations(address _denManagerImpl, address _sortedDensImpl) external;

    function BERABORROW_CORE() external view returns (address);

    function borrowerOperations() external view returns (address);

    function debtToken() external view returns (address);

    function guardian() external view returns (address);

    function liquidationManager() external view returns (address);

    function owner() external view returns (address);

    function sortedDensImpl() external view returns (address);

    function liquidStabilityPool() external view returns (address);

    function denManagerCount() external view returns (uint256);

    function denManagerImpl() external view returns (address);

    function denManagers(uint256) external view returns (address);
}
