// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {ILiquidStabilityPool} from "../interfaces/core/ILiquidStabilityPool.sol";

library EmissionsLib {
    using SafeCast for uint256;
    uint64 constant internal DEFAULT_UNLOCK_RATE = 1e11; // 10% per second
    uint64 constant internal MAX_UNLOCK_RATE = 1e12; // 100%

    struct BalanceData {
        mapping(address token => uint) balance;
        mapping(address token => EmissionSchedule) emissionSchedule;
    }

    struct EmissionSchedule {
        uint128 emissions;
        uint64 lockTimestamp;
        uint64 _unlockRatePerSecond; // rate points
    }

    error AmountCannotBeZero();
    error EmissionRateExceedsMax();
    // error UnsupportedEmissionConfig();

    event EmissionsAdded(address indexed token, uint128 amount);
    event EmissionsSub(address indexed token, uint128 amount);
    event NewUnlockRatePerSecond(address indexed token, uint64 unlockRatePerSecond);

    /// @dev zero _unlockRatePerSecond parameter resets rate back to DEFAULT_UNLOCK_RATE
    function setUnlockRatePerSecond(BalanceData storage $, address token, uint64 _unlockRatePerSecond) internal {
        if (_unlockRatePerSecond > MAX_UNLOCK_RATE) revert EmissionRateExceedsMax();
        _addEmissions($, token, 0); // update lockTimestamp and emissions
        $.emissionSchedule[token]._unlockRatePerSecond = _unlockRatePerSecond;

        emit NewUnlockRatePerSecond(token, _unlockRatePerSecond);
    }

    function addEmissions(BalanceData storage $, address token, uint128 amount) internal {
        if (amount == 0) revert AmountCannotBeZero();
        _addEmissions($, token, amount);

        emit EmissionsAdded(token, amount);
    }

    function _addEmissions(BalanceData storage $, address token, uint128 amount) private {        
        EmissionSchedule memory schedule = $.emissionSchedule[token];

        uint256 _unlockTimestamp = unlockTimestamp(schedule);
        uint128 nextEmissions = (lockedEmissions(schedule, _unlockTimestamp) + amount).toUint128();

        schedule.emissions = nextEmissions;
        schedule.lockTimestamp = block.timestamp.toUint64();
        $.balance[token] += amount;

        $.emissionSchedule[token] = schedule;
    }

    function subEmissions(BalanceData storage $, address token, uint128 amount) internal {
        if (amount == 0) revert AmountCannotBeZero();
        _subEmissions($, token, amount);

        emit EmissionsSub(token, amount);
    }

    function _subEmissions(BalanceData storage $, address token, uint128 amount) private {
        EmissionSchedule memory schedule = $.emissionSchedule[token];

        uint256 _unlockTimestamp = unlockTimestamp(schedule);
        uint128 nextEmissions = (lockedEmissions(schedule, _unlockTimestamp) - amount).toUint128();

        schedule.emissions = nextEmissions;
        schedule.lockTimestamp = block.timestamp.toUint64();
        $.balance[token] -= amount;

        $.emissionSchedule[token] = schedule;
    }

    /// @dev Doesn't include locked emissions
    function unlockedEmissions(EmissionSchedule memory schedule) internal view returns (uint256) {
        return schedule.emissions - lockedEmissions(schedule, unlockTimestamp(schedule));
    }

    function balanceOfWithFutureEmissions(BalanceData storage $, address token) internal view returns (uint256) {
        return $.balance[token];
    }

    /**
     * @notice Returns the unlocked token emissions
     */
    function balanceOf(BalanceData storage $, address token) internal view returns (uint256) {
        EmissionSchedule memory schedule = $.emissionSchedule[token];
        return $.balance[token] - lockedEmissions(schedule, unlockTimestamp(schedule));
    }

    /**
     * @notice Returns locked emissions
     */
    function lockedEmissions(EmissionSchedule memory schedule, uint256 _unlockTimestamp) internal view returns (uint256) {
        if (block.timestamp >= _unlockTimestamp) {
            // all emissions were unlocked 
            return 0;
        } else {
            // emissions are still unlocking, calculate the amount of already unlocked emissions
            uint256 secondsSinceLockup = block.timestamp - schedule.lockTimestamp;
            // design decision - use dimensionless 'unlock rate units' to unlock emissions over a fixed time window 
            uint256 ratePointsUnlocked = unlockRatePerSecond(schedule) * secondsSinceLockup;
            // emissions remainder is designed to be added to balance in unlockTimestamp
            return schedule.emissions - ratePointsUnlocked * schedule.emissions / MAX_UNLOCK_RATE;
        }
    } 

    // timestamp at which all emissions are fully unlocked
    function unlockTimestamp(EmissionSchedule memory schedule) internal pure returns (uint256) {
        // ceil to account for remainder seconds left after integer division
        return divRoundUp(MAX_UNLOCK_RATE, unlockRatePerSecond(schedule)) + schedule.lockTimestamp; 
    }

    function unlockRatePerSecond(EmissionSchedule memory schedule) internal pure returns (uint256) {
        return schedule._unlockRatePerSecond == 0 ? DEFAULT_UNLOCK_RATE : schedule._unlockRatePerSecond;
    }

    function divRoundUp(uint256 dividend, uint256 divisor) internal pure returns (uint256) {
        return (dividend + divisor - 1) / divisor;
    }
}