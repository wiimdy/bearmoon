// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC3156FlashBorrower } from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "../interfaces/core/IBorrowerOperations.sol";
import "../interfaces/core/IDebtToken.sol";
import "../interfaces/core/ISortedDens.sol";
import "../interfaces/core/IPriceFeed.sol";
import "../interfaces/core/IFactory.sol";
import "../interfaces/core/ILiquidationManager.sol";
import "../dependencies/SystemStart.sol";
import "../dependencies/BeraborrowBase.sol";
import "../dependencies/BeraborrowMath.sol";
import "../dependencies/BeraborrowOwnable.sol";

/**
    @title Beraborrow Den Manager
    @notice Based on Liquity's `TroveManager`
            https://github.com/liquity/dev/blob/main/packages/contracts/contracts/TroveManager.sol

            Beraborrow's implementation is modified so that multiple `DenManager` and `SortedDens`
            contracts are deployed in tandem, with each pair managing dens of a single collateral
            type.

            Functionality related to liquidations has been moved to `LiquidationManager`. This was
            necessary to avoid the restriction on deployed bytecode size.
 */
contract DenManager is BeraborrowBase, BeraborrowOwnable, SystemStart {
    using SafeERC20 for IERC20;

    // --- Connected contract declarations ---

    address public immutable borrowerOperations;
    address public immutable liquidationManager;
    address immutable gasPoolAddress;
    IDebtToken public immutable debtToken;
    address public immutable brimeDen;
    
    address public collVaultRouter;
    IPriceFeed public priceFeed;
    IERC20 public collateralToken;

    // A doubly linked list of Dens, sorted by their collateral ratios
    ISortedDens public sortedDens;

    // Minimum collateral ratio for individual dens
    uint256 public MCR;

    uint256 constant SECONDS_IN_ONE_MINUTE = 60;
    uint256 constant INTEREST_PRECISION = 1e27;
    uint256 constant SECONDS_IN_YEAR = 365 days;

    uint256 public constant SUNSETTING_INTEREST_RATE = (INTEREST_PRECISION * 5000) / (BP * SECONDS_IN_YEAR); // 50%

    uint256 constant _100pct = 1000000000000000000; // 1e18 == 100%, below this CR it's considered undercollateralized

    /*
     * BETA: 18 digit decimal. Parameter by which to divide the redeemed fraction, in order to calc the new base rate from a redemption.
     * Corresponds to (1 / ALPHA) in the white paper.
     */
    uint256 constant BETA = 2;

    uint16 constant BP = 1e4;

    // --- ERC 3156 Data ---
    bytes32 private constant _RETURN_VALUE = keccak256("ERC3156FlashBorrower.onFlashLoan");

    // commented values are Liquity's fixed settings for each parameter
    uint256 public minuteDecayFactor; // 999037758833783000  (half-life of 12 hours)
    /// @dev Redemption fee floor should be higher than deviation threshold of oracle supporting this collateral
    uint256 public redemptionFeeFloor; // DECIMAL_PRECISION / 1000 * 5  (0.5%)
    uint256 public maxRedemptionFee; // DECIMAL_PRECISION  (100%)
    uint256 public borrowingFeeFloor; // DECIMAL_PRECISION / 1000 * 5  (0.5%)
    uint256 public maxBorrowingFee; // DECIMAL_PRECISION / 100 * 5  (5%)
    uint256 public maxSystemDebt;

    uint256 public interestRate;
    uint256 public activeInterestIndex;
    uint256 public lastActiveIndexUpdate;

    uint256 public systemDeploymentTime;
    bool public sunsetting;
    bool public paused;

    uint256 public baseRate;

    // The timestamp of the latest fee operation (redemption or new debt issuance)
    uint256 public lastFeeOperationTime;

    uint256 public totalStakes;

    // Snapshot of the value of totalStakes, taken immediately after the latest liquidation
    uint256 public totalStakesSnapshot;

    // Snapshot of the total collateral taken immediately after the latest liquidation.
    uint256 public totalCollateralSnapshot;

    /*
     * L_collateral and L_debt track the sums of accumulated liquidation rewards per unit staked. During its lifetime, each stake earns:
     *
     * An collateral gain of ( stake * [L_collateral - L_collateral(0)] )
     * A debt increase  of ( stake * [L_debt - L_debt(0)] )
     *
     * Where L_collateral(0) and L_debt(0) are snapshots of L_collateral and L_debt for the active Den taken at the instant the stake was made
     */
    uint256 public L_collateral;
    uint256 public L_debt;

    // Error trackers for the den redistribution calculation
    uint256 public lastCollateralError_Redistribution;
    uint256 public lastDebtError_Redistribution;

    uint256 internal totalActiveCollateral;
    uint256 internal totalActiveDebt;
    uint256 public interestPayable;

    uint256 public defaultedCollateral;
    uint256 public defaultedDebt;

    mapping(address => Den) public Dens;
    mapping(address => uint256) public surplusBalances;

    // Map addresses with active dens to their RewardSnapshot
    mapping(address => RewardSnapshot) public rewardSnapshots;

    // Array of all active den addresses - used to to compute an approximate hint off-chain, for the sorted list insertion
    address[] DenOwners;

    // Store the necessary data for a den
    struct Den {
        uint256 debt;
        uint256 coll;
        uint256 stake;
        Status status;
        uint128 arrayIndex;
        uint256 activeInterestIndex;
    }

    struct RedemptionTotals {
        uint256 remainingDebt;
        uint256 totalDebtToRedeem;
        uint256 totalCollateralDrawn;
        uint256 collateralFee;
        uint256 collateralToSendToRedeemer;
        uint256 decayedBaseRate;
        uint256 price;
        uint256 totalDebtSupplyAtStart;
    }

    struct SingleRedemptionValues {
        uint256 debtLot;
        uint256 collateralLot;
        bool cancelledPartial;
    }

    // Object containing the collateral and debt snapshots for a given active den
    struct RewardSnapshot {
        uint256 collateral;
        uint256 debt;
    }

    enum DenManagerOperation {
        applyPendingRewards,
        liquidateInNormalMode,
        liquidateInRecoveryMode,
        redeemCollateral
    }

    enum Status {
        nonExistent,
        active,
        closedByOwner,
        closedByLiquidation,
        closedByRedemption
    }

    event NewParameters(IFactory.DeploymentParams params);
    event PriceFeedUpdated(address _priceFeed);
    event DenUpdated(
        address indexed _borrower,
        uint256 _debt,
        uint256 _coll,
        uint256 _stake,
        DenManagerOperation _operation
    );
    event Redemption(
        address indexed _redeemer,
        uint256 _attemptedDebtAmount,
        uint256 _actualDebtAmount,
        uint256 _collateralSent,
        uint256 _collateralFee
    );
    event BaseRateUpdated(uint256 _baseRate);
    event LastFeeOpTimeUpdated(uint256 _lastFeeOpTime);
    event TotalStakesUpdated(uint256 _newTotalStakes);
    event SystemSnapshotsUpdated(uint256 _totalStakesSnapshot, uint256 _totalCollateralSnapshot);
    event LTermsUpdated(uint256 _L_collateral, uint256 _L_debt);
    event DenSnapshotsUpdated(uint256 _L_collateral, uint256 _L_debt);
    event DenIndexUpdated(address _borrower, uint256 _newIndex);
    event CollateralSent(address _to, uint256 _amount);

    modifier whenNotPaused() {
        require(!paused, "Collateral Paused");
        _;
    }

    /// @dev Overrided by PermissionedDenManager to enforce only one den
    function _isPermissionedCheck(address _borrower) internal virtual {}

    constructor(
        address _beraborrowCore,
        address _gasPoolAddress,
        address _debtTokenAddress,
        address _borrowerOperations,
        address _liquidationManager,
        address _brimeDen,
        uint256 _gasCompensation
    ) BeraborrowOwnable(_beraborrowCore) BeraborrowBase(_gasCompensation) SystemStart(_beraborrowCore) {
        if (_beraborrowCore == address(0) || _gasPoolAddress == address(0) || _debtTokenAddress == address(0) || _borrowerOperations == address(0) || _liquidationManager == address(0) || _brimeDen == address(0)) {
            revert("DenManager: 0 address");
        }

        gasPoolAddress = _gasPoolAddress;
        debtToken = IDebtToken(_debtTokenAddress);
        borrowerOperations = _borrowerOperations;
        liquidationManager = _liquidationManager;
        brimeDen = _brimeDen;
    }

    function setAddresses(address _priceFeedAddress, address _sortedDensAddress, address _collateralToken) external {
        require(address(sortedDens) == address(0));
        priceFeed = IPriceFeed(_priceFeedAddress);
        sortedDens = ISortedDens(_sortedDensAddress);
        collateralToken = IERC20(_collateralToken);

        systemDeploymentTime = block.timestamp;
        sunsetting = false;
        activeInterestIndex = INTEREST_PRECISION;
        lastActiveIndexUpdate = block.timestamp;
    }

    /**
     * @notice Sets the pause state for this den manager
     *         Pausing is used to mitigate risks in exceptional circumstances
     *         Functionalities affected by pausing are:
     *         - New borrowing is not possible
     *         - New collateral deposits are not possible
     * @param _paused If true the protocol is paused
     */
    function setPaused(bool _paused) external {
        require((_paused && msg.sender == guardian()) || msg.sender == owner(), "Unauthorized");
        paused = _paused;
    }

    /**
     * @notice Sets a custom price feed for this den manager
     * @param _priceFeedAddress Price feed address
     */
    function setPriceFeed(address _priceFeedAddress) external onlyOwner {
        priceFeed = IPriceFeed(_priceFeedAddress);
        emit PriceFeedUpdated(_priceFeedAddress);
    }

    function setCollVaultRouter(address _collVaultRouter) external onlyOwner {
        collVaultRouter = _collVaultRouter;
    }

    /**
     * @notice Starts sunsetting a collateral
     *         During sunsetting only the following are possible:
               1) Disable collateral handoff to SP
               2) Greatly Increase interest rate to incentivize redemptions
               3) Remove redemptions fees
               4) Disable new loans
        @dev IMPORTANT: When sunsetting a collateral altogether this function should be called on
                        all DM linked to that collateral as well as `StabilityPool.startCollateralSunset`
        @dev IMPORTANT: A peripheral system will ensure users aren't MEVed due to redemptions fees being removed
     */
    function startSunset() external onlyOwner {
        sunsetting = true;
        _accrueActiveInterests();
        interestRate = SUNSETTING_INTEREST_RATE;
        // accrual function doesn't update timestamp if interest was 0
        lastActiveIndexUpdate = block.timestamp;
        redemptionFeeFloor = 0;
        maxSystemDebt = 0;
        baseRate = 0;
        maxRedemptionFee = 0;
    }

    /*
        _minuteDecayFactor is calculated as

            10**18 * (1/2)**(1/n)

        where n = the half-life in minutes
     */
    function setParameters(IFactory.DeploymentParams calldata params) public  {
        require(!sunsetting, "Cannot change after sunset");
        require(params.MCR <= BERABORROW_CORE.CCR() && params.MCR >= 1.1e18, "MCR cannot be > CCR or < 110%");

        if (minuteDecayFactor != 0) {
            require(msg.sender == owner(), "Only owner");
        }
        require(
            params.minuteDecayFactor >= 977159968434245900 && // half-life of 30 minutes
                params.minuteDecayFactor <= 999931237762985000 // half-life of 1 week
        );
        require(params.redemptionFeeFloor <= params.maxRedemptionFee && params.maxRedemptionFee <= DECIMAL_PRECISION);
        require(params.borrowingFeeFloor <= params.maxBorrowingFee && params.maxBorrowingFee <= DECIMAL_PRECISION);

        _decayBaseRate();

        minuteDecayFactor = params.minuteDecayFactor;
        redemptionFeeFloor = params.redemptionFeeFloor;
        maxRedemptionFee = params.maxRedemptionFee;
        borrowingFeeFloor = params.borrowingFeeFloor;
        maxBorrowingFee = params.maxBorrowingFee;
        maxSystemDebt = params.maxDebt;
        collVaultRouter = params.collVaultRouter;

        uint256 newInterestRate = (INTEREST_PRECISION * params.interestRateInBps) / (BP * SECONDS_IN_YEAR);
        if (newInterestRate != interestRate) {
            _accrueActiveInterests();
            // accrual function doesn't update timestamp if interest was 0
            lastActiveIndexUpdate = block.timestamp;
            interestRate = newInterestRate;
        }
        MCR = params.MCR;

        emit NewParameters(params);
    }

    function collectInterests() external {
        uint256 interestPayableCached = interestPayable;
        require(interestPayableCached > 0, "Nothing to collect");
        debtToken.mint(BERABORROW_CORE.feeReceiver(), interestPayableCached);
        interestPayable = 0;
    }

    // --- Getters ---

    function fetchPrice() public view returns (uint256) {
        IPriceFeed _priceFeed = priceFeed;
        if (address(_priceFeed) == address(0)) {
            _priceFeed = IPriceFeed(BERABORROW_CORE.priceFeed());
        }
        return _priceFeed.fetchPrice(address(collateralToken));
    }

    function getDenOwnersCount() external view returns (uint256) {
        return DenOwners.length;
    }

    function getDenFromDenOwnersArray(uint256 _index) external view returns (address) {
        return DenOwners[_index];
    }

    function getDenStatus(address _borrower) external view returns (uint256) {
        return uint256(Dens[_borrower].status);
    }

    function getDenStake(address _borrower) external view returns (uint256) {
        return Dens[_borrower].stake;
    }

    /**
        @notice Get the current total collateral and debt amounts for a den
        @dev Also includes pending rewards from redistribution
     */
    function getDenCollAndDebt(address _borrower) public view returns (uint256 coll, uint256 debt) {
        (debt, coll, , ) = getEntireDebtAndColl(_borrower);
        return (coll, debt);
    }

    /**
        @notice Get the total and pending collateral and debt amounts for a den
        @dev Used by the liquidation manager
     */
    function getEntireDebtAndColl(
        address _borrower
    ) public view returns (uint256 debt, uint256 coll, uint256 pendingDebtReward, uint256 pendingCollateralReward) {
        Den storage t = Dens[_borrower];
        debt = t.debt;
        coll = t.coll;

        (pendingCollateralReward, pendingDebtReward) = getPendingCollAndDebtRewards(_borrower);
        // Accrued den interest for correct liquidation values. This assumes the index to be updated.
        uint256 denInterestIndex = t.activeInterestIndex;
        if (denInterestIndex > 0 && _borrower != brimeDen) {
            (uint256 currentIndex, ) = _calculateInterestIndex();
            debt = (debt * currentIndex) / denInterestIndex;
        }

        debt = debt + pendingDebtReward;
        coll = coll + pendingCollateralReward;
    }

    function getEntireSystemColl() public view returns (uint256) {
        return totalActiveCollateral + defaultedCollateral;
    }

    function getEntireSystemDebt() public view returns (uint256) {
        uint256 currentActiveDebt = totalActiveDebt;
        (, uint256 interestFactor) = _calculateInterestIndex();
        if (interestFactor > 0) {
            uint256 activeInterests = Math.mulDiv(currentActiveDebt, interestFactor, INTEREST_PRECISION);
            currentActiveDebt = currentActiveDebt + activeInterests;
        }
        return currentActiveDebt + defaultedDebt;
    }

    function getEntireSystemBalances() external view returns (uint256, uint256, uint256) {
        return (getEntireSystemColl(), getEntireSystemDebt(), fetchPrice());
    }

    // --- Helper functions ---

    // Return the nominal collateral ratio (ICR) of a given Den, without the price. Takes a den's pending coll and debt rewards from redistributions into account.
    function getNominalICR(address _borrower) public view returns (uint256) {
        (uint256 currentCollateral, uint256 currentDebt) = getDenCollAndDebt(_borrower);

        uint256 NICR = BeraborrowMath._computeNominalCR(currentCollateral, currentDebt);
        return NICR;
    }

    // Return the current collateral ratio (ICR) of a given Den. Takes a den's pending coll and debt rewards from redistributions into account.
    function getCurrentICR(address _borrower, uint256 _price) public view returns (uint256) {
        (uint256 currentCollateral, uint256 currentDebt) = getDenCollAndDebt(_borrower);

        uint256 ICR = BeraborrowMath._computeCR(currentCollateral, currentDebt, _price);
        return ICR;
    }

    function getTotalActiveCollateral() public view returns (uint256) {
        return totalActiveCollateral;
    }

    function getTotalActiveDebt() public view returns (uint256) {
        uint256 currentActiveDebt = totalActiveDebt;
        (, uint256 interestFactor) = _calculateInterestIndex();
        if (interestFactor > 0) {
            uint256 activeInterests = Math.mulDiv(currentActiveDebt, interestFactor, INTEREST_PRECISION);
            currentActiveDebt = currentActiveDebt + activeInterests;
        }
        return currentActiveDebt;
    }

    // Get the borrower's pending accumulated collateral and debt rewards, earned by their stake
    function getPendingCollAndDebtRewards(address _borrower) public view returns (uint256, uint256) {
        RewardSnapshot memory snapshot = rewardSnapshots[_borrower];

        uint256 coll = L_collateral - snapshot.collateral;
        uint256 debt = L_debt - snapshot.debt;

        if (coll + debt == 0 || Dens[_borrower].status != Status.active) return (0, 0);

        uint256 stake = Dens[_borrower].stake;
        return ((stake * coll) / DECIMAL_PRECISION, (stake * debt) / DECIMAL_PRECISION);
    }

    function hasPendingRewards(address _borrower) public view returns (bool) {
        /*
         * A Den has pending rewards if its snapshot is less than the current rewards per-unit-staked sum:
         * this indicates that rewards have occured since the snapshot was made, and the user therefore has
         * pending rewards
         */
        if (Dens[_borrower].status != Status.active) {
            return false;
        }

        return (rewardSnapshots[_borrower].collateral < L_collateral);
    }

    // --- Redemption fee functions ---

    /*
     * This function has two impacts on the baseRate state variable:
     * 1) decays the baseRate based on time passed since last redemption or debt borrowing operation.
     * then,
     * 2) increases the baseRate based on the amount redeemed, as a proportion of total supply
     */
    function _updateBaseRateFromRedemption(
        uint256 _collateralDrawn,
        uint256 _price,
        uint256 _totalDebtSupply
    ) internal returns (uint256) {
        uint256 decayedBaseRate = _calcDecayedBaseRate();

        /* Convert the drawn collateral back to debt at face value rate (1 debt:1 USD), in order to get
         * the fraction of total supply that was redeemed at face value. */
        uint256 redeemedDebtFraction = (_collateralDrawn * _price) / _totalDebtSupply;

        uint256 newBaseRate = decayedBaseRate + (redeemedDebtFraction / BETA);
        newBaseRate = BeraborrowMath._min(newBaseRate, DECIMAL_PRECISION); // cap baseRate at a maximum of 100%

        // Update the baseRate state variable
        baseRate = newBaseRate;
        emit BaseRateUpdated(newBaseRate);

        _updateLastFeeOpTime();

        return newBaseRate;
    }

    function getRedemptionRate() public view returns (uint256) {
        return _calcRedemptionRate(baseRate);
    }

    function getRedemptionRateWithDecay() public view returns (uint256) {
        return _calcRedemptionRate(_calcDecayedBaseRate());
    }

    function _calcRedemptionRate(uint256 _baseRate) internal view returns (uint256) {
        return
            BeraborrowMath._min(
                redemptionFeeFloor + _baseRate,
                maxRedemptionFee
            );
    }

    function getRedemptionFeeWithDecay(uint256 _collateralDrawn) external view returns (uint256) {
        return _calcRedemptionFee(getRedemptionRateWithDecay(), _collateralDrawn);
    }

    function _calcRedemptionFee(uint256 _redemptionRate, uint256 _collateralDrawn) internal pure returns (uint256) {
        uint256 redemptionFee = (_redemptionRate * _collateralDrawn) / DECIMAL_PRECISION;
        require(redemptionFee < _collateralDrawn, "Fee exceeds returned collateral");
        return redemptionFee;
    }

    // --- Borrowing fee functions ---

    function getBorrowingRate() public view returns (uint256) {
        return _calcBorrowingRate(baseRate);
    }

    function getBorrowingRateWithDecay() public view returns (uint256) {
        return _calcBorrowingRate(_calcDecayedBaseRate());
    }

    function _calcBorrowingRate(uint256 _baseRate) internal view returns (uint256) {
        return BeraborrowMath._min(borrowingFeeFloor + _baseRate, maxBorrowingFee);
    }

    function getBorrowingFee(uint256 _debt) external view returns (uint256) {
        return _calcBorrowingFee(getBorrowingRate(), _debt);
    }

    function getBorrowingFeeWithDecay(uint256 _debt) external view returns (uint256) {
        return _calcBorrowingFee(getBorrowingRateWithDecay(), _debt);
    }

    function _calcBorrowingFee(uint256 _borrowingRate, uint256 _debt) internal pure returns (uint256) {
        return (_borrowingRate * _debt) / DECIMAL_PRECISION;
    }

    // --- Internal fee functions ---

    // Update the last fee operation time only if time passed >= decay interval. This prevents base rate griefing.
    function _updateLastFeeOpTime() internal {
        uint256 timePassed = block.timestamp - lastFeeOperationTime;
        if (timePassed >= SECONDS_IN_ONE_MINUTE) {
            lastFeeOperationTime += _minutesPassedSinceLastFeeOp() * SECONDS_IN_ONE_MINUTE;
            emit LastFeeOpTimeUpdated(block.timestamp);
        }
    }

    function _calcDecayedBaseRate() internal view returns (uint256) {
        uint256 minutesPassed = _minutesPassedSinceLastFeeOp();
        uint256 decayFactor = BeraborrowMath._decPow(minuteDecayFactor, minutesPassed);

        return (baseRate * decayFactor) / DECIMAL_PRECISION;
    }

    function _minutesPassedSinceLastFeeOp() internal view returns (uint256) {
        return (block.timestamp - lastFeeOperationTime) / SECONDS_IN_ONE_MINUTE;
    }

    // --- Redemption functions ---

    /* Send _debtAmount debt to the system and redeem the corresponding amount of collateral from as many Dens as are needed to fill the redemption
     * request.  Applies pending rewards to a Den before reducing its debt and coll.
     *
     * Note that if _amount is very large, this function can run out of gas, specially if traversed dens are small. This can be easily avoided by
     * splitting the total _amount in appropriate chunks and calling the function multiple times.
     *
     * Param `_maxIterations` can also be provided, so the loop through Dens is capped (if it’s zero, it will be ignored).This makes it easier to
     * avoid OOG for the frontend, as only knowing approximately the average cost of an iteration is enough, without needing to know the “topology”
     * of the den list. It also avoids the need to set the cap in stone in the contract, nor doing gas calculations, as both gas price and opcode
     * costs can vary.
     *
     * All Dens that are redeemed from -- with the likely exception of the last one -- will end up with no debt left, therefore they will be closed.
     * If the last Den does have some remaining debt, it has a finite ICR, and the reinsertion could be anywhere in the list, therefore it requires a hint.
     * A frontend should use getRedemptionHints() to calculate what the ICR of this Den will be after redemption, and pass a hint for its position
     * in the sortedDens list along with the ICR value that the hint was found for.
     *
     * If another transaction modifies the list between calling getRedemptionHints() and passing the hints to redeemCollateral(), it
     * is very likely that the last (partially) redeemed Den would end up with a different ICR than what the hint is for. In this case the
     * redemption will stop after the last completely redeemed Den and the sender will keep the remaining debt amount, which they can attempt
     * to redeem later.
     */
    function redeemCollateral(
        uint256 _debtAmount,
        address _firstRedemptionHint,
        address _upperPartialRedemptionHint,
        address _lowerPartialRedemptionHint,
        uint256 _partialRedemptionHintNICR,
        uint256 _maxIterations,
        uint256 _maxFeePercentage
    ) external {
        ISortedDens _sortedDensCached = sortedDens;
        RedemptionTotals memory totals;

        require(
            _maxFeePercentage >= redemptionFeeFloor && _maxFeePercentage <= maxRedemptionFee,
            "Max fee not in bounds"
        );
        require(block.timestamp >= systemDeploymentTime + BERABORROW_CORE.dmBootstrapPeriod(), "BOOTSTRAP_PERIOD");
        totals.price = fetchPrice();
        require(IBorrowerOperations(borrowerOperations).getTCR() >= MCR, "Cannot redeem when TCR < MCR");
        require(_debtAmount > 0, "Amount must be greater than zero");
        require(debtToken.balanceOf(msg.sender) >= _debtAmount, "Insufficient balance");
        _updateBalances();
        totals.totalDebtSupplyAtStart = getEntireSystemDebt();

        totals.remainingDebt = _debtAmount;
        address currentBorrower;

        if (_isValidFirstRedemptionHint(_sortedDensCached, _firstRedemptionHint, totals.price)) {
            currentBorrower = _firstRedemptionHint;
        } else {
            currentBorrower = _sortedDensCached.getLast();
            // Find the first den with ICR >= MCR
            while (currentBorrower != address(0) && getCurrentICR(currentBorrower, totals.price) < _100pct) {
                currentBorrower = _sortedDensCached.getPrev(currentBorrower);
            }
        }

        // Loop through the Dens starting from the one with lowest collateral ratio until _amount of debt is exchanged for collateral
        if (_maxIterations == 0) {
            _maxIterations = 100;
        }
        while (currentBorrower != address(0) && totals.remainingDebt > 0 && _maxIterations > 0) {
            _maxIterations--;
            // Save the address of the Den preceding the current one, before potentially modifying the list
            address nextUserToCheck = _sortedDensCached.getPrev(currentBorrower);

            _applyPendingRewards(currentBorrower);
            SingleRedemptionValues memory singleRedemption = _redeemCollateralFromDen(
                _sortedDensCached,
                currentBorrower,
                totals.remainingDebt,
                totals.price,
                _upperPartialRedemptionHint,
                _lowerPartialRedemptionHint,
                _partialRedemptionHintNICR
            );
            if (singleRedemption.cancelledPartial) break; // Partial redemption was cancelled (out-of-date hint, or new net debt < minimum), therefore we could not redeem from the last Den

            totals.totalDebtToRedeem = totals.totalDebtToRedeem + singleRedemption.debtLot;
            totals.totalCollateralDrawn = totals.totalCollateralDrawn + singleRedemption.collateralLot;

            totals.remainingDebt = totals.remainingDebt - singleRedemption.debtLot;
            currentBorrower = nextUserToCheck;
        }
        require(totals.totalCollateralDrawn > 0, "Unable to redeem any amount");

        // Decay the baseRate due to time passed, and then increase it according to the size of this redemption.
        // Use the saved total debt supply value, from before it was reduced by the redemption.
        // only callabe when not sunsetting
        if (!sunsetting) {
            _updateBaseRateFromRedemption(totals.totalCollateralDrawn, totals.price, totals.totalDebtSupplyAtStart);
        }

        // Calculate the collateral fee
        totals.collateralFee = sunsetting ? 0 : _calcRedemptionFee(getRedemptionRate(), totals.totalCollateralDrawn);

        _requireUserAcceptsFee(totals.collateralFee, totals.totalCollateralDrawn, _maxFeePercentage);

        _sendCollateral(BERABORROW_CORE.feeReceiver(), totals.collateralFee);

        totals.collateralToSendToRedeemer = totals.totalCollateralDrawn - totals.collateralFee;

        emit Redemption(msg.sender, _debtAmount, totals.totalDebtToRedeem, totals.totalCollateralDrawn, totals.collateralFee);

        // Burn the total debt that is cancelled with debt, and send the redeemed collateral to msg.sender
        debtToken.burn(msg.sender, totals.totalDebtToRedeem);
        // Update Den Manager debt, and send collateral to account
        totalActiveDebt = totalActiveDebt - totals.totalDebtToRedeem;
        _sendCollateral(msg.sender, totals.collateralToSendToRedeemer);
        _resetState();
    }

    // Redeem as much collateral as possible from _borrower's Den in exchange for debt up to _maxDebtAmount
    function _redeemCollateralFromDen(
        ISortedDens _sortedDensCached,
        address _borrower,
        uint256 _maxDebtAmount,
        uint256 _price,
        address _upperPartialRedemptionHint,
        address _lowerPartialRedemptionHint,
        uint256 _partialRedemptionHintNICR
    ) internal returns (SingleRedemptionValues memory singleRedemption) {
        Den storage t = Dens[_borrower];
        // Determine the remaining amount (lot) to be redeemed, capped by the entire debt of the Den minus the liquidation reserve
        singleRedemption.debtLot = BeraborrowMath._min(_maxDebtAmount, t.debt - DEBT_GAS_COMPENSATION);

        // Get the CollateralLot of equivalent value in USD
        singleRedemption.collateralLot = (singleRedemption.debtLot * DECIMAL_PRECISION) / _price;

        // Decrease the debt and collateral of the current Den according to the debt lot and corresponding collateral to send
        uint256 newDebt = (t.debt) - singleRedemption.debtLot;
        uint256 newColl = (t.coll) - singleRedemption.collateralLot;
        if (newDebt == DEBT_GAS_COMPENSATION) {
            // No debt left in the Den (except for the liquidation reserve), therefore the den gets closed
            _removeStake(_borrower);
            _closeDen(_borrower, Status.closedByRedemption);
            _redeemCloseDen(_borrower, DEBT_GAS_COMPENSATION, newColl);
            emit DenUpdated(_borrower, 0, 0, 0, DenManagerOperation.redeemCollateral);
        } else {
            uint256 newNICR = BeraborrowMath._computeNominalCR(newColl, newDebt);
            /*
             * If the provided hint is out of date, we bail since trying to reinsert without a good hint will almost
             * certainly result in running out of gas.
             *
             * If the resultant net debt of the partial is less than the minimum, net debt we bail.
             */

            {
                // We check if the ICR hint is reasonable up to date, with continuous interest there might be slight differences (<1bps)
                uint256 icrError = _partialRedemptionHintNICR > newNICR
                    ? _partialRedemptionHintNICR - newNICR
                    : newNICR - _partialRedemptionHintNICR;
                if (
                    icrError > 5e14 ||
                    _getNetDebt(newDebt) < IBorrowerOperations(borrowerOperations).minNetDebt()
                ) {
                    singleRedemption.cancelledPartial = true;
                    return singleRedemption;
                }
            }

            _sortedDensCached.reInsert(_borrower, newNICR, _upperPartialRedemptionHint, _lowerPartialRedemptionHint);

            t.debt = newDebt;
            t.coll = newColl;
            _updateStakeAndTotalStakes(t);

            emit DenUpdated(_borrower, newDebt, newColl, t.stake, DenManagerOperation.redeemCollateral);
        }
        return singleRedemption;
    }

    /*
     * Called when a full redemption occurs, and closes the den.
     * The redeemer swaps (debt - liquidation reserve) debt for (debt - liquidation reserve) worth of collateral, so the debt liquidation reserve left corresponds to the remaining debt.
     * In order to close the den, the debt liquidation reserve is burned, and the corresponding debt is removed.
     * The debt recorded on the den's struct is zero'd elswhere, in _closeDen.
     * Any surplus collateral left in the den can be later claimed by the borrower.
     */
    function _redeemCloseDen(address _borrower, uint256 _debt, uint256 _collateral) internal {
        debtToken.burn(gasPoolAddress, _debt);
        totalActiveDebt = totalActiveDebt - _debt;

        surplusBalances[_borrower] += _collateral;
        totalActiveCollateral -= _collateral;
    }

    function _isValidFirstRedemptionHint(
        ISortedDens _sortedDens,
        address _firstRedemptionHint,
        uint256 _price
    ) internal view returns (bool) {
        if (
            _firstRedemptionHint == address(0) ||
            !_sortedDens.contains(_firstRedemptionHint) ||
            getCurrentICR(_firstRedemptionHint, _price) < _100pct
        ) {
            return false;
        }

        address nextDen = _sortedDens.getNext(_firstRedemptionHint);
        return nextDen == address(0) || getCurrentICR(nextDen, _price) < _100pct;
    }

    /**
     * Claim remaining collateral from a redemption or from a liquidation with ICR > MCR in Recovery Mode
     */
    function claimCollateral(address borrower, address _receiver) external {
        if (msg.sender != collVaultRouter) {
            borrower = msg.sender;
        }
        uint256 claimableColl = surplusBalances[borrower];
        require(claimableColl > 0, "No collateral available to claim");

        surplusBalances[borrower] = 0;

        collateralToken.safeTransfer(_receiver, claimableColl);
    }

    // --- Den Adjustment functions ---

    function openDen(
        address _borrower,
        uint256 _collateralAmount,
        uint256 _compositeDebt,
        uint256 NICR,
        address _upperHint,
        address _lowerHint
    ) external whenNotPaused returns (uint256 stake, uint256 arrayIndex) {
        _requireCallerIsBO();
        require(!sunsetting, "Cannot open while sunsetting");
        _isPermissionedCheck(_borrower);

        Den storage t = Dens[_borrower];
        require(t.status != Status.active, "BorrowerOps: Den is active");
        t.status = Status.active;
        t.coll = _collateralAmount;
        t.debt = _compositeDebt;
        uint256 currentInterestIndex = _accrueActiveInterests();
        t.activeInterestIndex = currentInterestIndex;
        _updateDenRewardSnapshots(_borrower);
        stake = _updateStakeAndTotalStakes(t);
        sortedDens.insert(_borrower, NICR, _upperHint, _lowerHint);

        DenOwners.push(_borrower);
        arrayIndex = DenOwners.length - 1;
        t.arrayIndex = uint128(arrayIndex);

        totalActiveCollateral = totalActiveCollateral + _collateralAmount;
        uint256 _newTotalDebt = totalActiveDebt + _compositeDebt;
        require(_newTotalDebt + defaultedDebt <= maxSystemDebt, "Collateral debt limit reached");
        totalActiveDebt = _newTotalDebt;
    }

    function updateDenFromAdjustment(
        bool _isDebtIncrease,
        uint256 _debtChange,
        uint256 _netDebtChange,
        bool _isCollIncrease,
        uint256 _collChange,
        address _upperHint,
        address _lowerHint,
        address _borrower,
        address _receiver
    ) external returns (uint256, uint256, uint256) {
        _requireCallerIsBO();
        if (_isCollIncrease || _isDebtIncrease) {
            require(!paused, "Collateral Paused");
            require(!sunsetting, "Cannot increase while sunsetting");
        }

        Den storage t = Dens[_borrower];
        require(t.status == Status.active, "Den closed or does not exist");

        uint256 newDebt = t.debt;
        if (_debtChange > 0) {
            if (_isDebtIncrease) {
                newDebt = newDebt + _netDebtChange;
                _increaseDebt(_receiver, _netDebtChange, _debtChange);
            } else {
                newDebt = newDebt - _netDebtChange;
                _decreaseDebt(_receiver, _debtChange);
            }
            t.debt = newDebt;
        }

        uint256 newColl = t.coll;
        if (_collChange > 0) {
            if (_isCollIncrease) {
                newColl = newColl + _collChange;
                totalActiveCollateral = totalActiveCollateral + _collChange;
                // trust that BorrowerOperations sent the collateral
            } else {
                newColl = newColl - _collChange;
                _sendCollateral(_receiver, _collChange);
            }
            t.coll = newColl;
        }

        uint256 newNICR = BeraborrowMath._computeNominalCR(newColl, newDebt);
        sortedDens.reInsert(_borrower, newNICR, _upperHint, _lowerHint);

        return (newColl, newDebt, _updateStakeAndTotalStakes(t));
    }

    function closeDen(address _borrower, address _receiver, uint256 collAmount, uint256 debtAmount) external {
        _requireCallerIsBO();
        require(Dens[_borrower].status == Status.active, "Den closed or does not exist");
        _removeStake(_borrower);
        _closeDen(_borrower, Status.closedByOwner);
        totalActiveDebt = totalActiveDebt - debtAmount;
        _sendCollateral(_receiver, collAmount);
        _resetState();
    }

    /**
        @dev Only called from `closeDen` because liquidating the final den is blocked in
             `LiquidationManager`. Many liquidation paths involve redistributing debt and
             collateral to existing dens. If the collateral is being sunset, the final den
             must be closed by repaying the debt or via a redemption.
     */
    function _resetState() private {
        if (DenOwners.length == 0) {
            activeInterestIndex = INTEREST_PRECISION;
            lastActiveIndexUpdate = block.timestamp;
            totalStakes = 0;
            totalStakesSnapshot = 0;
            totalCollateralSnapshot = 0;
            L_collateral = 0;
            L_debt = 0;
            lastCollateralError_Redistribution = 0;
            lastDebtError_Redistribution = 0;
            totalActiveCollateral = 0;
            totalActiveDebt = 0;
            defaultedCollateral = 0;
            defaultedDebt = 0;
        }
    }

    function _closeDen(address _borrower, Status closedStatus) internal {
        uint256 DenOwnersArrayLength = DenOwners.length;

        Den storage t = Dens[_borrower];
        t.status = closedStatus;
        t.coll = 0;
        t.debt = 0;
        t.activeInterestIndex = 0;
        ISortedDens sortedDensCached = sortedDens;
        rewardSnapshots[_borrower].collateral = 0;
        rewardSnapshots[_borrower].debt = 0;
        if (DenOwnersArrayLength > 1 && sortedDensCached.getSize() > 1) {
            // remove den owner from the DenOwners array, not preserving array order
            uint128 index = t.arrayIndex;
            address addressToMove = DenOwners[DenOwnersArrayLength - 1];
            DenOwners[index] = addressToMove;
            Dens[addressToMove].arrayIndex = index;
            emit DenIndexUpdated(addressToMove, index);
        }

        DenOwners.pop();

        sortedDensCached.remove(_borrower);
        t.arrayIndex = 0;
    }

    // Updates the baseRate state variable based on time elapsed since the last redemption or debt borrowing operation.
    function decayBaseRateAndGetBorrowingFee(uint256 _debt) external returns (uint256) {
        _requireCallerIsBO();
        uint256 rate = _decayBaseRate();

        return _calcBorrowingFee(_calcBorrowingRate(rate), _debt);
    }

    function _decayBaseRate() internal returns (uint256) {
        uint256 decayedBaseRate = _calcDecayedBaseRate();

        baseRate = decayedBaseRate;
        emit BaseRateUpdated(decayedBaseRate);

        _updateLastFeeOpTime();

        return decayedBaseRate;
    }

    function applyPendingRewards(address _borrower) external returns (uint256 coll, uint256 debt) {
        _requireCallerIsBO();
        return _applyPendingRewards(_borrower);
    }

    // Add the borrowers's coll and debt rewards earned from redistributions, to their Den
    function _applyPendingRewards(address _borrower) internal returns (uint256 coll, uint256 debt) {
        Den storage t = Dens[_borrower];
        if (t.status == Status.active) {
            uint256 denInterestIndex = t.activeInterestIndex;
            uint256 currentInterestIndex = _accrueActiveInterests();
            debt = t.debt;
            uint256 prevDebt = debt;
            coll = t.coll;
            // We accrue interests for this den if not already updated and borrower is not BrimeDen
            if (denInterestIndex < currentInterestIndex && _borrower != brimeDen) {
                debt = (debt * currentInterestIndex) / denInterestIndex;
                t.activeInterestIndex = currentInterestIndex;
            }

            if (rewardSnapshots[_borrower].collateral < L_collateral) {
                // Compute pending rewards
                (uint256 pendingCollateralReward, uint256 pendingDebtReward) = getPendingCollAndDebtRewards(_borrower);

                // Apply pending rewards to den's state
                coll = coll + pendingCollateralReward;
                t.coll = coll;
                debt = debt + pendingDebtReward;

                _updateDenRewardSnapshots(_borrower);

                _movePendingDenRewardsToActiveBalance(pendingDebtReward, pendingCollateralReward);

                emit DenUpdated(_borrower, debt, coll, t.stake, DenManagerOperation.applyPendingRewards);
            }
            if (prevDebt != debt) {
                t.debt = debt;
            }
        }
        return (coll, debt);
    }

    function _updateDenRewardSnapshots(address _borrower) internal {
        uint256 L_collateralCached = L_collateral;
        uint256 L_debtCached = L_debt;
        rewardSnapshots[_borrower] = RewardSnapshot(L_collateralCached, L_debtCached);
        emit DenSnapshotsUpdated(L_collateralCached, L_debtCached);
    }

    // Remove borrower's stake from the totalStakes sum, and set their stake to 0
    function _removeStake(address _borrower) internal {
        uint256 stake = Dens[_borrower].stake;
        totalStakes = totalStakes - stake;
        Dens[_borrower].stake = 0;
    }

    // Update borrower's stake based on their latest collateral value
    function _updateStakeAndTotalStakes(Den storage t) internal returns (uint256) {
        uint256 newStake = _computeNewStake(t.coll);
        uint256 oldStake = t.stake;
        t.stake = newStake;
        uint256 newTotalStakes = totalStakes - oldStake + newStake;
        totalStakes = newTotalStakes;
        emit TotalStakesUpdated(newTotalStakes);

        return newStake;
    }

    // Calculate a new stake based on the snapshots of the totalStakes and totalCollateral taken at the last liquidation
    function _computeNewStake(uint256 _coll) internal view returns (uint256) {
        uint256 stake;
        uint256 totalCollateralSnapshotCached = totalCollateralSnapshot;
        if (totalCollateralSnapshotCached == 0) {
            stake = _coll;
        } else {
            /*
             * The following assert() holds true because:
             * - The system always contains >= 1 den
             * - When we close or liquidate a den, we redistribute the pending rewards, so if all dens were closed/liquidated,
             * rewards would’ve been emptied and totalCollateralSnapshot would be zero too.
             */
            uint256 totalStakesSnapshotCached = totalStakesSnapshot;
            assert(totalStakesSnapshotCached > 0);
            stake = (_coll * totalStakesSnapshotCached) / totalCollateralSnapshotCached;
        }
        return stake;
    }

    // --- Liquidation Functions ---

    function closeDenByLiquidation(address _borrower) external {
        _requireCallerIsLM();
        _removeStake(_borrower);
        _closeDen(_borrower, Status.closedByLiquidation);
    }

    function movePendingDenRewardsToActiveBalances(uint256 _debt, uint256 _collateral) external {
        _requireCallerIsLM();
        _movePendingDenRewardsToActiveBalance(_debt, _collateral);
    }

    function _movePendingDenRewardsToActiveBalance(uint256 _debt, uint256 _collateral) internal {
        defaultedDebt -= _debt;
        totalActiveDebt += _debt;
        defaultedCollateral -= _collateral;
        totalActiveCollateral += _collateral;
    }

    function addCollateralSurplus(address borrower, uint256 collSurplus) external {
        _requireCallerIsLM();
        surplusBalances[borrower] += collSurplus;
    }

    function finalizeLiquidation(
        address _liquidator,
        uint256 _debt,
        uint256 _coll,
        uint256 _collSurplus,
        uint256 _debtGasComp,
        uint256 _collGasComp
    ) external {
        _requireCallerIsLM();
        // redistribute debt and collateral
        _redistributeDebtAndColl(_debt, _coll);
        uint256 _activeColl = totalActiveCollateral;
        if (_collSurplus > 0) {
            _activeColl -= _collSurplus;
            totalActiveCollateral = _activeColl;
        }
        // update system snapshot
        totalStakesSnapshot = totalStakes;
        totalCollateralSnapshot = _activeColl + defaultedCollateral - _collGasComp;  
        emit SystemSnapshotsUpdated(totalStakesSnapshot, totalCollateralSnapshot);
        
        // Split collateral and debt compensation between liquidator, sNect guage and validator pools.
        // Send compensation tokens to liquidator
        ILiquidationManager.LiquidationFeeData memory data = ILiquidationManager(liquidationManager).liquidationsFeeAndRecipients();
        debtToken.returnFromPool(gasPoolAddress, _liquidator, _debtGasComp * data.liquidatorFee / DECIMAL_PRECISION);
        // Send compensation tokens to sNect Gauge
        debtToken.returnFromPool(gasPoolAddress, data.sNectGauge, _debtGasComp * data.sNectGaugeFee / DECIMAL_PRECISION);
        // Send compensation tokens to validator pool
        debtToken.returnFromPool(gasPoolAddress, data.validatorPool, _debtGasComp * data.poolFee / DECIMAL_PRECISION);

        _sendCollateral(_liquidator, _collGasComp * data.liquidatorFee / DECIMAL_PRECISION);
        _sendCollateral(data.sNectGauge, _collGasComp * data.sNectGaugeFee / DECIMAL_PRECISION);
        _sendCollateral(data.validatorPool, _collGasComp * data.poolFee / DECIMAL_PRECISION);
    }

    function _redistributeDebtAndColl(uint256 _debt, uint256 _coll) internal {
        if (_debt == 0) {
            return;
        }
        /*
         * Add distributed coll and debt rewards-per-unit-staked to the running totals. Division uses a "feedback"
         * error correction, to keep the cumulative error low in the running totals L_collateral and L_debt:
         *
         * 1) Form numerators which compensate for the floor division errors that occurred the last time this
         * function was called.
         * 2) Calculate "per-unit-staked" ratios.
         * 3) Multiply each ratio back by its denominator, to reveal the current floor division error.
         * 4) Store these errors for use in the next correction when this function is called.
         * 5) Note: static analysis tools complain about this "division before multiplication", however, it is intended.
         */
        uint256 collateralNumerator = (_coll * DECIMAL_PRECISION) + lastCollateralError_Redistribution;
        uint256 debtNumerator = (_debt * DECIMAL_PRECISION) + lastDebtError_Redistribution;
        uint256 totalStakesCached = totalStakes;
        // Get the per-unit-staked terms
        uint256 collateralRewardPerUnitStaked = collateralNumerator / totalStakesCached;
        uint256 debtRewardPerUnitStaked = debtNumerator / totalStakesCached;

        lastCollateralError_Redistribution = collateralNumerator - (collateralRewardPerUnitStaked * totalStakesCached);
        lastDebtError_Redistribution = debtNumerator - (debtRewardPerUnitStaked * totalStakesCached);

        // Add per-unit-staked terms to the running totals
        uint256 new_L_collateral = L_collateral + collateralRewardPerUnitStaked;
        uint256 new_L_debt = L_debt + debtRewardPerUnitStaked;
        L_collateral = new_L_collateral;
        L_debt = new_L_debt;

        emit LTermsUpdated(new_L_collateral, new_L_debt);

        totalActiveDebt -= _debt;
        defaultedDebt += _debt;
        defaultedCollateral += _coll;
        totalActiveCollateral -= _coll;
    }

    // --- Den property setters ---

    function _sendCollateral(address _account, uint256 _amount) private {
        if (_amount > 0) {
            totalActiveCollateral = totalActiveCollateral - _amount;
            emit CollateralSent(_account, _amount);

            collateralToken.safeTransfer(_account, _amount);
        }
    }

    function _increaseDebt(address account, uint256 netDebtAmount, uint256 debtAmount) internal {
        uint256 _newTotalDebt = totalActiveDebt + netDebtAmount;
        require(_newTotalDebt + defaultedDebt <= maxSystemDebt, "Collateral debt limit reached");
        totalActiveDebt = _newTotalDebt;
        debtToken.mint(account, debtAmount);
    }

    function decreaseDebtAndSendCollateral(address account, uint256 debt, uint256 coll) external {
        _requireCallerIsLM();
        _decreaseDebt(account, debt);
        _sendCollateral(account, coll);
    }

    function _decreaseDebt(address account, uint256 amount) internal {
        debtToken.burn(account, amount);
        totalActiveDebt = totalActiveDebt - amount;
    }

    // --- Balances and interest ---

    function updateBalances() external {
        _requireCallerIsLM();
        _updateBalances();
    }

    function _updateBalances() private {
        _accrueActiveInterests();
    }

    // This function must be called any time the debt or the interest changes
    function _accrueActiveInterests() internal returns (uint256) {
        (uint256 currentInterestIndex, uint256 interestFactor) = _calculateInterestIndex();
        if (interestFactor > 0) {
            uint256 currentDebt = totalActiveDebt;
            uint256 activeInterests = Math.mulDiv(currentDebt, interestFactor, INTEREST_PRECISION);
            totalActiveDebt = currentDebt + activeInterests;
            interestPayable = interestPayable + activeInterests;
            activeInterestIndex = currentInterestIndex;
            lastActiveIndexUpdate = block.timestamp;
        }
        return currentInterestIndex;
    }

    function _calculateInterestIndex() internal view returns (uint256 currentInterestIndex, uint256 interestFactor) {
        uint256 lastIndexUpdateCached = lastActiveIndexUpdate;
        // Short circuit if we updated in the current block
        if (lastIndexUpdateCached == block.timestamp) return (activeInterestIndex, 0);
        uint256 currentInterest = interestRate;
        currentInterestIndex = activeInterestIndex; // we need to return this if it's already up to date
        if (currentInterest > 0) {
            /*
             * Calculate the interest accumulated and the new index:
             * We compound the index and increase the debt accordingly
             */
            uint256 deltaT = block.timestamp - lastIndexUpdateCached;
            interestFactor = deltaT * currentInterest;
            currentInterestIndex =
                currentInterestIndex +
                Math.mulDiv(currentInterestIndex, interestFactor, INTEREST_PRECISION);
        }
    }

    // --- Requires ---

    function _requireCallerIsBO() internal view {
        require(msg.sender == borrowerOperations, "Caller not BO");
    }

    function _requireCallerIsLM() internal view {
        require(msg.sender == liquidationManager, "Not Liquidation Manager");
    }
}
