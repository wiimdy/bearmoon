// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {IMetaBeraborrowCore} from "src/interfaces/core/IMetaBeraborrowCore.sol";

interface IBeraborrowCore {

    // --- Public variables ---
    function metaBeraborrowCore() external view returns (IMetaBeraborrowCore);
    function startTime() external view returns (uint256);
    function CCR() external view returns (uint256);
    function dmBootstrapPeriod() external view returns (uint64);
    function isPeriphery(address peripheryContract) external view returns (bool);

    // --- External functions ---

    function setPeripheryEnabled(address _periphery, bool _enabled) external;
    function setDMBootstrapPeriod(address dm, uint64 _bootstrapPeriod) external;
    function setNewCCR(uint256 _CCR) external;

    function priceFeed() external view returns (address);
    function owner() external view returns (address);
    function pendingOwner() external view returns (address);
    function guardian() external view returns (address);
    function manager() external view returns (address);
    function feeReceiver() external view returns (address);
    function paused() external view returns (bool);
    function lspBootstrapPeriod() external view returns (uint64);
    function getLspEntryFee(address rebalancer) external view returns (uint16);
    function getLspExitFee(address rebalancer) external view returns (uint16);
    function getPeripheryFlashLoanFee(address peripheryContract) external view returns (uint16);

    // --- Events ---
    event CCRSet(uint256 initialCCR);
    event DMBootstrapPeriodSet(address dm, uint64 bootstrapPeriod);
    event PeripheryEnabled(address indexed periphery, bool enabled);
}
