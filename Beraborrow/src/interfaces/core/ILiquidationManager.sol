// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ILiquidationManager {
    /// @notice Liquidation coll and debt gas compensation redistribution shares and recipients
    /// @dev Fees are in WAD
    struct LiquidationFeeData {
        uint256 liquidatorFee;
        uint256 sNectGaugeFee;
        uint256 poolFee;
        address validatorPool;
        address sNectGauge;
    }

    function batchLiquidateDens(address denManager, address[] calldata _denArray, address liquidator) external;

    function enableDenManager(address _denManager) external;

    function liquidate(address denManager, address borrower, address liquidator) external;

    function liquidateDens(address denManager, uint256 maxDensToLiquidate, uint256 maxICR, address liquidator) external;

    function DEBT_GAS_COMPENSATION() external view returns (uint256);

    function DECIMAL_PRECISION() external view returns (uint256);

    function PERCENT_DIVISOR() external view returns (uint256);

    function borrowerOperations() external view returns (address);

    function factory() external view returns (address);

    function liquidStabilityPool() external view returns (address);

    function liquidationsFeeAndRecipients() external view returns (LiquidationFeeData memory);

    function liquidatorLiquidationFee() external view returns(uint256 feeBps);

    function sNectGaugeLiquidationFee() external view returns(address recipient, uint256 feeBps);

    function poolLiquidationFee() external view returns(address recipient, uint256 feeBps);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
}
