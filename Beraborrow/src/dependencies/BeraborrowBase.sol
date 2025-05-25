// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

/*
 * Base contract for DenManager, BorrowerOperations and StabilityPool. Contains global system constants and
 * common functions.
 */
contract BeraborrowBase {
    uint256 public constant DECIMAL_PRECISION = 1e18;

    // Amount of debt to be locked in gas pool on opening dens
    uint256 public immutable DEBT_GAS_COMPENSATION;

    uint256 public constant PERCENT_DIVISOR = 200; // dividing by 200 yields 0.5%

    constructor(uint256 _gasCompensation) {
        DEBT_GAS_COMPENSATION = _gasCompensation;
    }

    // --- Gas compensation functions ---

    // Returns the composite debt (drawn debt + gas compensation) of a den, for the purpose of ICR calculation
    function _getCompositeDebt(uint256 _debt) internal view returns (uint256) {
        return _debt + DEBT_GAS_COMPENSATION;
    }

    function _getNetDebt(uint256 _debt) internal view returns (uint256) {
        return _debt - DEBT_GAS_COMPENSATION;
    }

    // Return the amount of collateral to be drawn from a den's collateral and sent as gas compensation.
    function _getCollGasCompensation(uint256 _entireColl) internal pure returns (uint256) {
        return _entireColl / PERCENT_DIVISOR;
    }

    function _requireUserAcceptsFee(uint256 _fee, uint256 _amount, uint256 _maxFeePercentage) internal pure {
        uint256 feePercentage = _amount != 0 ? (_fee * DECIMAL_PRECISION) / _amount : 0;
        require(feePercentage <= _maxFeePercentage, "Fee exceeded provided maximum");
    }
}
