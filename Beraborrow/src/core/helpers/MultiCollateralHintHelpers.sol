// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import "../../interfaces/core/IBorrowerOperations.sol";
import "../../interfaces/core/IDenManager.sol";
import "../../interfaces/core/ISortedDens.sol";
import "../../interfaces/core/IFactory.sol";
import "../../dependencies/BeraborrowBase.sol";
import "../../dependencies/BeraborrowMath.sol";

contract MultiCollateralHintHelpers is BeraborrowBase {
    IBorrowerOperations public immutable borrowerOperations;

    constructor(address _borrowerOperationsAddress, uint256 _gasCompensation) BeraborrowBase(_gasCompensation) {
        borrowerOperations = IBorrowerOperations(_borrowerOperationsAddress);
    }

    // --- Functions ---

    /* getRedemptionHints() - Helper function for finding the right hints to pass to redeemCollateral().
     *
     * It simulates a redemption of `_debtAmount` to figure out where the redemption sequence will start and what state the final Den
     * of the sequence will end up in.
     *
     * Returns three hints:
     *  - `firstRedemptionHint` is the address of the first Den with ICR >= MCR (i.e. the first Den that will be redeemed).
     *  - `partialRedemptionHintNICR` is the final nominal ICR of the last Den of the sequence after being hit by partial redemption,
     *     or zero in case of no partial redemption.
     *  - `truncatedDebtAmount` is the maximum amount that can be redeemed out of the the provided `_debtAmount`. This can be lower than
     *    `_debtAmount` when redeeming the full amount would leave the last Den of the redemption sequence with less net debt than the
     *    minimum allowed value (i.e. MIN_NET_DEBT).
     *
     * The number of Dens to consider for redemption can be capped by passing a non-zero value as `_maxIterations`, while passing zero
     * will leave it uncapped.
     */

    function getRedemptionHints(
        IDenManager denManager,
        uint256 _debtAmount,
        uint256 _price,
        uint256 _maxIterations
    )
        external
        view
        returns (address firstRedemptionHint, uint256 partialRedemptionHintNICR, uint256 truncatedDebtAmount)
    {
        ISortedDens sortedDensCached = ISortedDens(denManager.sortedDens());

        uint256 remainingDebt = _debtAmount;
        address currentDenuser = sortedDensCached.getLast();
        uint256 MCR = denManager.MCR();

        while (currentDenuser != address(0) && denManager.getCurrentICR(currentDenuser, _price) < MCR) {
            currentDenuser = sortedDensCached.getPrev(currentDenuser);
        }

        firstRedemptionHint = currentDenuser;

        if (_maxIterations == 0) {
            _maxIterations = type(uint256).max;
        }

        uint256 minNetDebt = borrowerOperations.minNetDebt();
        while (currentDenuser != address(0) && remainingDebt > 0 && _maxIterations-- > 0) {
            (uint256 debt, uint256 coll, , ) = denManager.getEntireDebtAndColl(currentDenuser);
            uint256 netDebt = _getNetDebt(debt);

            if (netDebt > remainingDebt) {
                if (netDebt > minNetDebt) {
                    uint256 maxRedeemableDebt = BeraborrowMath._min(remainingDebt, netDebt - minNetDebt);

                    uint256 newColl = coll - ((maxRedeemableDebt * DECIMAL_PRECISION) / _price);
                    uint256 newDebt = netDebt - maxRedeemableDebt;

                    uint256 compositeDebt = _getCompositeDebt(newDebt);
                    partialRedemptionHintNICR = BeraborrowMath._computeNominalCR(newColl, compositeDebt);

                    remainingDebt = remainingDebt - maxRedeemableDebt;
                }
                break;
            } else {
                remainingDebt = remainingDebt - netDebt;
            }
            // Otherwise, _maxIterations-- underflows
            require(_maxIterations != 0, "Hints not found");

            currentDenuser = sortedDensCached.getPrev(currentDenuser);
        }

        truncatedDebtAmount = _debtAmount - remainingDebt;
    }

    /* getApproxHint() - return address of a Den that is, on average, (length / numTrials) positions away in the
    sortedDens list from the correct insert position of the Den to be inserted.

    Note: The output address is worst-case O(n) positions away from the correct insert position, however, the function
    is probabilistic. Input can be tuned to guarantee results to a high degree of confidence, e.g:

    Submitting numTrials = k * sqrt(length), with k = 15 makes it very, very likely that the ouput address will
    be <= sqrt(length) positions away from the correct insert position.
    */
    function getApproxHint(
        IDenManager denManager,
        uint256 _CR,
        uint256 _numTrials,
        uint256 _inputRandomSeed
    ) external view returns (address hintAddress, uint256 diff, uint256 latestRandomSeed) {
        ISortedDens sortedDens = ISortedDens(denManager.sortedDens());
        uint256 arrayLength = denManager.getDenOwnersCount();

        if (arrayLength == 0) {
            return (address(0), 0, _inputRandomSeed);
        }

        hintAddress = sortedDens.getLast();
        diff = BeraborrowMath._getAbsoluteDifference(_CR, denManager.getNominalICR(hintAddress));
        latestRandomSeed = _inputRandomSeed;

        uint256 i = 1;

        while (i < _numTrials) {
            latestRandomSeed = uint256(keccak256(abi.encodePacked(latestRandomSeed)));

            uint256 arrayIndex = latestRandomSeed % arrayLength;
            address currentAddress = denManager.getDenFromDenOwnersArray(arrayIndex);
            uint256 currentNICR = denManager.getNominalICR(currentAddress);

            // check if abs(current - CR) > abs(closest - CR), and update closest if current is closer
            uint256 currentDiff = BeraborrowMath._getAbsoluteDifference(currentNICR, _CR);

            if (currentDiff < diff) {
                diff = currentDiff;
                hintAddress = currentAddress;
            }
            i++;
        }
    }

    function computeNominalCR(uint256 _coll, uint256 _debt) external pure returns (uint256) {
        return BeraborrowMath._computeNominalCR(_coll, _debt);
    }

    function computeCR(uint256 _coll, uint256 _debt, uint256 _price) external pure returns (uint256) {
        return BeraborrowMath._computeCR(_coll, _debt, _price);
    }
}
