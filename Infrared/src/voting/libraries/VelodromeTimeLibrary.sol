// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

library VelodromeTimeLibrary {
    uint256 internal constant WEEK = 7 days;

    /**
     * @notice Calculate the start of the current epoch based on the timestamp provided
     * @dev Epochs are aligned to weekly intervals, with each epoch starting at midnight UTC.
     * @param timestamp The current timestamp to align
     * @return The start timestamp of the epoch week
     */
    function epochStart(uint256 timestamp) internal pure returns (uint256) {
        unchecked {
            return timestamp - (timestamp % WEEK);
        }
    }

    /**
     * @notice Calculate the start of the next epoch or end of the current epoch
     * @dev Returns the timestamp at the start of the next weekly epoch following the given timestamp.
     * @param timestamp The current timestamp
     * @return The start timestamp of the next epoch
     */
    function epochNext(uint256 timestamp) internal pure returns (uint256) {
        unchecked {
            return timestamp - (timestamp % WEEK) + WEEK;
        }
    }

    /**
     * @notice Determine the start of the voting window for the current epoch
     * @dev Voting windows start one hour into the weekly epoch.
     * @param timestamp The timestamp to calculate from
     * @return The start timestamp of the voting window within the epoch
     */
    function epochVoteStart(uint256 timestamp)
        internal
        pure
        returns (uint256)
    {
        unchecked {
            return timestamp - (timestamp % WEEK) + 1 hours;
        }
    }

    /**
     * @notice Calculate the end of the voting window within the current epoch
     * @dev Voting windows close one hour before the next epoch begins.
     * @param timestamp The timestamp to calculate from
     * @return The end timestamp of the voting window within the epoch
     */
    function epochVoteEnd(uint256 timestamp) internal pure returns (uint256) {
        unchecked {
            return timestamp - (timestamp % WEEK) + WEEK - 1 hours;
        }
    }
}
