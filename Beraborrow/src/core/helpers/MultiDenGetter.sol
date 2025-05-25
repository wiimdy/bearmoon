// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import "../../interfaces/core/IDenManager.sol";
import "../../interfaces/core/ISortedDens.sol";
import "../../interfaces/core/IFactory.sol";

/*  Helper contract for grabbing Den data for the front end. Not part of the core Beraborrow system. */
contract MultiDenGetter {
    struct CombinedDenData {
        address owner;
        uint256 debt;
        uint256 coll;
        uint256 stake;
        uint256 snapshotCollateral;
        uint256 snapshotDebt;
    }

    constructor() {}

    function getMultipleSortedDens(
        IDenManager denManager,
        int _startIdx,
        uint256 _count
    ) external view returns (CombinedDenData[] memory _dens) {
        ISortedDens sortedDens = ISortedDens(denManager.sortedDens());
        uint256 startIdx;
        bool descend;

        if (_startIdx >= 0) {
            startIdx = uint256(_startIdx);
            descend = true;
        } else {
            startIdx = uint256(-(_startIdx + 1));
            descend = false;
        }

        uint256 sortedDensSize = sortedDens.getSize();

        if (startIdx >= sortedDensSize) {
            _dens = new CombinedDenData[](0);
        } else {
            uint256 maxCount = sortedDensSize - startIdx;

            if (_count > maxCount) {
                _count = maxCount;
            }

            if (descend) {
                _dens = _getMultipleSortedDensFromHead(denManager, sortedDens, startIdx, _count);
            } else {
                _dens = _getMultipleSortedDensFromTail(denManager, sortedDens, startIdx, _count);
            }
        }
    }

    function _getMultipleSortedDensFromHead(
        IDenManager denManager,
        ISortedDens sortedDens,
        uint256 _startIdx,
        uint256 _count
    ) internal view returns (CombinedDenData[] memory _dens) {
        address currentDenowner = sortedDens.getFirst();

        for (uint256 idx = 0; idx < _startIdx; ++idx) {
            currentDenowner = sortedDens.getNext(currentDenowner);
        }

        _dens = new CombinedDenData[](_count);

        for (uint256 idx = 0; idx < _count; ++idx) {
            _dens[idx].owner = currentDenowner;
            (
                _dens[idx].debt,
                _dens[idx].coll,
                _dens[idx].stake,
                /* status */
                /* arrayIndex */
                /* interestIndex */
                ,
                ,

            ) = denManager.Dens(currentDenowner);
            (_dens[idx].snapshotCollateral, _dens[idx].snapshotDebt) = denManager.rewardSnapshots(
                currentDenowner
            );

            currentDenowner = sortedDens.getNext(currentDenowner);
        }
    }

    function _getMultipleSortedDensFromTail(
        IDenManager denManager,
        ISortedDens sortedDens,
        uint256 _startIdx,
        uint256 _count
    ) internal view returns (CombinedDenData[] memory _dens) {
        address currentDenowner = sortedDens.getLast();

        for (uint256 idx = 0; idx < _startIdx; ++idx) {
            currentDenowner = sortedDens.getPrev(currentDenowner);
        }

        _dens = new CombinedDenData[](_count);

        for (uint256 idx = 0; idx < _count; ++idx) {
            _dens[idx].owner = currentDenowner;
            (
                _dens[idx].debt,
                _dens[idx].coll,
                _dens[idx].stake,
                /* status */
                /* arrayIndex */
                /* interestIndex */
                ,
                ,

            ) = denManager.Dens(currentDenowner);
            (_dens[idx].snapshotCollateral, _dens[idx].snapshotDebt) = denManager.rewardSnapshots(
                currentDenowner
            );

            currentDenowner = sortedDens.getPrev(currentDenowner);
        }
    }
}
