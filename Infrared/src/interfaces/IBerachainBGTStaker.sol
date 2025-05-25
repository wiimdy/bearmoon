// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBGTStaker} from "@berachain/pol/interfaces/IBGTStaker.sol";

interface IBerachainBGTStaker is IBGTStaker {
    /// @dev Temp override of interface to include left out reward token
    function rewardToken() external view returns (address);
}
