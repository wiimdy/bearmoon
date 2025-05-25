// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {IBeraborrowCore} from "src/interfaces/core/IBeraborrowCore.sol";
import {IMetaBeraborrowCore} from "src/interfaces/core/IMetaBeraborrowCore.sol";
import {IFactory} from "src/interfaces/core/IFactory.sol";
import {IDenManager} from "src/interfaces/core/IDenManager.sol";

/**
    @title Beraborrow Core
    @notice Single source of truth for protocol-wide values and contract ownership.
            Other ownable Beraborrow contracts inherit their ownership from this contract
            using `BeraborrowOwnable`.
    @dev Offers specific per protocol instance beacon variables such as startTime, CCR, dmBootstrapPeriod.
 */
contract BeraborrowCore is IBeraborrowCore {
    // System-wide start time, rounded down the nearest epoch week.
    // Other contracts that require access to this should inherit `SystemStart`.
    uint256 public immutable startTime;

    IMetaBeraborrowCore public immutable metaBeraborrowCore;

    uint256 public CCR; 

    // During bootstrap period collateral redemptions are not allowed in LSP
    mapping(address => uint64) internal _dmBootstrapPeriod;

    // Beacon-looked at by inherited DelegatedOps
    mapping(address peripheryContract => bool) public isPeriphery;

    constructor(address _metaBeraborrowCore, uint256 _initialCCR) {
        if (_metaBeraborrowCore == address(0)) {
            revert("BeraborrowCore: 0 address");
        }
        metaBeraborrowCore = IMetaBeraborrowCore(_metaBeraborrowCore);
        startTime = (block.timestamp / 1 weeks) * 1 weeks;
        CCR = _initialCCR;

        emit CCRSet(_initialCCR);
    }

    modifier onlyOwner() {
        require(msg.sender == metaBeraborrowCore.owner(), "Only owner");
        _;
    }

    function setPeripheryEnabled(address _periphery, bool _enabled) external onlyOwner {
        isPeriphery[_periphery] = _enabled;
        emit PeripheryEnabled(_periphery, _enabled);
    }

    /// @notice Bootstrap period is added to denManager deployed timestamp
    function setDMBootstrapPeriod(address denManager, uint64 _bootstrapPeriod) external onlyOwner {
        _dmBootstrapPeriod[denManager] = _bootstrapPeriod;

        emit DMBootstrapPeriodSet(denManager, _bootstrapPeriod);
    }

    /**
     * @notice Updates the Critical Collateral Ratio (CCR) to a new value
     * @dev Only callable by the contract owner
     * @dev Values lower than current CCR will be notified by public comms and called through a timelock
     * @param newCCR The new Critical Collateral Ratio value to set
     * @custom:emits CCRSet 
     */
    function setNewCCR(uint newCCR) external onlyOwner {
        require(newCCR > 0, "Invalid CCR");        
        CCR = newCCR;
        emit CCRSet(newCCR);
    }

    /// @notice Enables each DenManager to set their own redemptions bootstrap period
    /// @dev Specific for DenManager fetches
    function dmBootstrapPeriod() external view returns (uint64) {
        return _dmBootstrapPeriod[msg.sender];
    }

    function priceFeed() external view returns (address) {
        return metaBeraborrowCore.priceFeed();
    }

    function owner() external view returns (address) {
        return metaBeraborrowCore.owner();
    }

    function pendingOwner() external view returns (address) {
        return metaBeraborrowCore.pendingOwner();
    }

    function guardian() external view returns (address) {
        return metaBeraborrowCore.guardian();
    }

    function manager() external view returns (address) {
        return metaBeraborrowCore.manager();
    }

    function feeReceiver() external view returns (address) {
        return metaBeraborrowCore.feeReceiver();
    }

    function paused() external view returns (bool) {
        return metaBeraborrowCore.paused();
    }

    function lspBootstrapPeriod() external view returns (uint64) {
        return metaBeraborrowCore.lspBootstrapPeriod();
    }

    function getLspEntryFee(address rebalancer) external view returns (uint16) {
        return metaBeraborrowCore.getLspEntryFee(rebalancer);
    }

    function getLspExitFee(address rebalancer) external view returns (uint16) {
        return metaBeraborrowCore.getLspExitFee(rebalancer);
    }

    function getPeripheryFlashLoanFee(address peripheryContract) external view returns (uint16) {
        return metaBeraborrowCore.getPeripheryFlashLoanFee(peripheryContract);
    }
}