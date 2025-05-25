// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/core/IDenManager.sol";
import "../interfaces/core/IDebtToken.sol";
import "../dependencies/BeraborrowBase.sol";
import "../dependencies/BeraborrowMath.sol";
import "../dependencies/BeraborrowOwnable.sol";
import "../dependencies/DelegatedOps.sol";

/**
    @title Beraborrow Borrower Operations
    @notice Based on Liquity's `BorrowerOperations`
            https://github.com/liquity/dev/blob/main/packages/contracts/contracts/BorrowerOperations.sol

            Beraborrow's implementation is modified to support multiple collaterals. There is a 1:n
            relationship between `BorrowerOperations` and each `DenManager` / `SortedDens` pair.
 */
contract BorrowerOperations is BeraborrowBase, BeraborrowOwnable, DelegatedOps {
    using SafeERC20 for IERC20;

    IDebtToken public immutable debtToken;
    address public immutable factory;
    address public immutable brimeDen;
    uint public immutable brimeMCR;

    uint256 public minNetDebt;

    mapping(IDenManager => DenManagerData) public denManagersData;
    IDenManager[] public denManagers;

    struct DenManagerData {
        IERC20 collateralToken;
        uint16 index;
    }

    struct SystemBalances {
        uint256[] collaterals;
        uint256[] debts;
        uint256[] prices;
    }

    struct LocalVariables_adjustDen {
        uint256 price;
        uint256 totalPricedCollateral;
        uint256 totalDebt;
        uint256 collChange;
        uint256 netDebtChange;
        bool isCollIncrease;
        uint256 debt;
        uint256 coll;
        uint256 newDebt;
        uint256 newColl;
        uint256 stake;
        uint256 debtChange;
        address account;
        uint256 MCR;
    }

    struct LocalVariables_openDen {
        uint256 price;
        uint256 totalPricedCollateral;
        uint256 totalDebt;
        uint256 netDebt;
        uint256 compositeDebt;
        uint256 ICR;
        uint256 NICR;
        uint256 stake;
        uint256 arrayIndex;
    }

    enum BorrowerOperation {
        openDen,
        closeDen,
        adjustDen
    }

    event DenUpdated(
        IDenManager indexed _denManager,
        address indexed _borrower,
        uint256 _debt,
        uint256 _coll,
        uint256 stake,
        BorrowerOperation operation
    );
    event DenCreated(IDenManager indexed denManager, address indexed _borrower, uint256 arrayIndex);
    event BorrowingFeePaid(IDenManager indexed denManager, address indexed borrower, uint256 amount);
    event CollateralConfigured(IDenManager denManager, IERC20 collateralToken);
    event DenManagerRemoved(IDenManager denManager);

    constructor(
        address _beraborrowCore,
        address _debtTokenAddress,
        address _factory,
        address _brimeDen,
        uint256 _brimeMCR,
        uint256 _minNetDebt,
        uint256 _gasCompensation
    ) BeraborrowOwnable(_beraborrowCore) BeraborrowBase(_gasCompensation) DelegatedOps(_beraborrowCore) {
        if (_beraborrowCore == address(0) || _debtTokenAddress == address(0) || _factory == address(0) || _brimeDen == address(0)) {
            revert("BorrowerOperations: 0 address");
        }

        debtToken = IDebtToken(_debtTokenAddress);
        factory = _factory;
        brimeDen = _brimeDen;
        brimeMCR = _brimeMCR;
        _setMinNetDebt(_minNetDebt);
    }

    function setMinNetDebt(uint256 _minNetDebt) public onlyOwner {
        _setMinNetDebt(_minNetDebt);
    }

    function _setMinNetDebt(uint256 _minNetDebt) internal {
        require(_minNetDebt > 0);
        minNetDebt = _minNetDebt;
    }

    function configureCollateral(IDenManager denManager, IERC20 collateralToken) external {
        require(msg.sender == factory, "!factory");
        denManagersData[denManager] = DenManagerData(collateralToken, uint16(denManagers.length));
        denManagers.push(denManager);
        emit CollateralConfigured(denManager, collateralToken);
    }

    function removeDenManager(IDenManager denManager) external {
        DenManagerData memory dmData = denManagersData[denManager];
        require(
            address(dmData.collateralToken) != address(0) &&
                denManager.sunsetting() &&
                denManager.getEntireSystemDebt() == 0,
            "Den Manager cannot be removed"
        );
        delete denManagersData[denManager];
        uint256 lastIndex = denManagers.length - 1;
        if (dmData.index < lastIndex) {
            IDenManager lastDm = denManagers[lastIndex];
            denManagers[dmData.index] = lastDm;
            denManagersData[lastDm].index = dmData.index;
        }

        denManagers.pop();
        emit DenManagerRemoved(denManager);
    }

    /**
        @notice Get the global total collateral ratio
     */
    function getTCR() external view returns (uint256 globalTotalCollateralRatio) {
        SystemBalances memory balances = fetchBalances();
        (globalTotalCollateralRatio, , ) = _getTCRData(balances);
        return globalTotalCollateralRatio;
    }

    /**
        @notice Get total collateral and debt balances for all active collaterals, as well as
                the current collateral prices
     */
    function fetchBalances() public view returns (SystemBalances memory balances) {
        uint256 loopEnd = denManagers.length;
        balances = SystemBalances({
            collaterals: new uint256[](loopEnd),
            debts: new uint256[](loopEnd),
            prices: new uint256[](loopEnd)
        });
        for (uint256 i; i < loopEnd; ) {
            IDenManager denManager = denManagers[i];
            (uint256 collateral, uint256 debt, uint256 price) = denManager.getEntireSystemBalances();
            balances.collaterals[i] = collateral;
            balances.debts[i] = debt;
            balances.prices[i] = price;
            unchecked {
                ++i;
            }
        }
    }

    function checkRecoveryMode(uint256 TCR) public view returns (bool) {
        return TCR < BERABORROW_CORE.CCR();
    }

    function getCompositeDebt(uint256 _debt) external view returns (uint256) {
        return _getCompositeDebt(_debt);
    }

    // --- Borrower Den Operations ---

    function openDen(
        IDenManager denManager,
        address account,
        uint256 _maxFeePercentage,
        uint256 _collateralAmount,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external callerOrDelegated(account) {
        require(!BERABORROW_CORE.paused(), "Deposits are paused");
        IERC20 collateralToken;
        LocalVariables_openDen memory vars;
        bool isRecoveryMode;
        (
            collateralToken,
            vars.price,
            vars.totalPricedCollateral,
            vars.totalDebt,
            isRecoveryMode
        ) = _getCollateralAndTCRData(denManager);

        _requireValidMaxFeePercentage(_maxFeePercentage);

        vars.netDebt = _debtAmount;

        if (!isRecoveryMode) {
            vars.netDebt = vars.netDebt + _triggerBorrowingFee(denManager, account, _maxFeePercentage, _debtAmount);
        }
        _requireAtLeastMinNetDebt(vars.netDebt);

        // ICR is based on the composite debt, i.e. the requested Debt amount + Debt borrowing fee + Debt gas comp.
        vars.compositeDebt = _getCompositeDebt(vars.netDebt);
        vars.ICR = BeraborrowMath._computeCR(_collateralAmount, vars.compositeDebt, vars.price);
        vars.NICR = BeraborrowMath._computeNominalCR(_collateralAmount, vars.compositeDebt);

        if (isRecoveryMode) {
            _requireICRisAboveCCR(vars.ICR);
        } else {
            _requireICRisAboveMCR(vars.ICR, denManager.MCR(), account);
            uint256 newTCR = _getNewTCRFromDenChange(
                vars.totalPricedCollateral,
                vars.totalDebt,
                _collateralAmount * vars.price,
                true,
                vars.compositeDebt,
                true
            ); // bools: coll increase, debt increase
            _requireNewTCRisAboveCCR(newTCR);
        }

        // Create the den
        (vars.stake, vars.arrayIndex) = denManager.openDen(
            account,
            _collateralAmount,
            vars.compositeDebt,
            vars.NICR,
            _upperHint,
            _lowerHint
        );
        emit DenCreated(denManager, account, vars.arrayIndex);

        // Move the collateral to the Den Manager
        collateralToken.safeTransferFrom(msg.sender, address(denManager), _collateralAmount);

        //  and mint the DebtAmount to the caller and gas compensation for Gas Pool
        debtToken.mintWithGasCompensation(msg.sender, _debtAmount);

        emit DenUpdated(denManager, account, vars.compositeDebt, _collateralAmount, vars.stake, BorrowerOperation.openDen);
    }

    // Send collateral to a den
    function addColl(
        IDenManager denManager,
        address account,
        uint256 _collateralAmount,
        address _upperHint,
        address _lowerHint
    ) external callerOrDelegated(account) {
        require(!BERABORROW_CORE.paused(), "Den adjustments are paused");
        _adjustDen(denManager, account, 0, _collateralAmount, 0, 0, false, _upperHint, _lowerHint);
    }

    // Withdraw collateral from a den
    function withdrawColl(
        IDenManager denManager,
        address account,
        uint256 _collWithdrawal,
        address _upperHint,
        address _lowerHint
    ) external callerOrDelegated(account) {
        _adjustDen(denManager, account, 0, 0, _collWithdrawal, 0, false, _upperHint, _lowerHint);
    }

    // Withdraw Debt tokens from a den: mint new Debt tokens to the owner, and increase the den's debt accordingly
    function withdrawDebt(
        IDenManager denManager,
        address account,
        uint256 _maxFeePercentage,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external callerOrDelegated(account) {
        require(!BERABORROW_CORE.paused(), "Withdrawals are paused");
        _adjustDen(denManager, account, _maxFeePercentage, 0, 0, _debtAmount, true, _upperHint, _lowerHint);
    }

    // Repay Debt tokens to a Den: Burn the repaid Debt tokens, and reduce the den's debt accordingly
    function repayDebt(
        IDenManager denManager,
        address account,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external callerOrDelegated(account) {
        _adjustDen(denManager, account, 0, 0, 0, _debtAmount, false, _upperHint, _lowerHint);
    }

    function adjustDen(
        IDenManager denManager,
        address account,
        uint256 _maxFeePercentage,
        uint256 _collDeposit,
        uint256 _collWithdrawal,
        uint256 _debtChange,
        bool _isDebtIncrease,
        address _upperHint,
        address _lowerHint
    ) external callerOrDelegated(account) {
        require((_collDeposit == 0 && !_isDebtIncrease) || !BERABORROW_CORE.paused(), "Den adjustments are paused");
        require(_collDeposit == 0 || _collWithdrawal == 0, "BorrowerOperations: Cannot withdraw and add coll");
        _adjustDen(
            denManager,
            account,
            _maxFeePercentage,
            _collDeposit,
            _collWithdrawal,
            _debtChange,
            _isDebtIncrease,
            _upperHint,
            _lowerHint
        );
    }

    function _adjustDen(
        IDenManager denManager,
        address account,
        uint256 _maxFeePercentage,
        uint256 _collDeposit,
        uint256 _collWithdrawal,
        uint256 _debtChange,
        bool _isDebtIncrease,
        address _upperHint,
        address _lowerHint
    ) internal {
        require(
            _collDeposit != 0 || _collWithdrawal != 0 || _debtChange != 0,
            "BorrowerOps: There must be either a collateral change or a debt change"
        );

        IERC20 collateralToken;
        LocalVariables_adjustDen memory vars;
        bool isRecoveryMode;
        (
            collateralToken,
            vars.price,
            vars.totalPricedCollateral,
            vars.totalDebt,
            isRecoveryMode
        ) = _getCollateralAndTCRData(denManager);

        (vars.coll, vars.debt) = denManager.applyPendingRewards(account);

        // Get the collChange based on whether or not collateral was sent in the transaction
        (vars.collChange, vars.isCollIncrease) = _getCollChange(_collDeposit, _collWithdrawal);
        vars.netDebtChange = _debtChange;
        vars.debtChange = _debtChange;
        vars.account = account;
        vars.MCR = denManager.MCR();

        if (_isDebtIncrease) {
            require(_debtChange > 0, "BorrowerOps: Debt increase requires non-zero debtChange");
            _requireValidMaxFeePercentage(_maxFeePercentage);
            if (!isRecoveryMode) {
                // If the adjustment incorporates a debt increase and system is in Normal Mode, trigger a borrowing fee
                vars.netDebtChange += _triggerBorrowingFee(denManager, account, _maxFeePercentage, _debtChange);
            }
        }

        // Calculate old and new ICRs and check if adjustment satisfies all conditions for the current system mode
        _requireValidAdjustmentInCurrentMode(
            vars.totalPricedCollateral,
            vars.totalDebt,
            isRecoveryMode,
            _collWithdrawal,
            _isDebtIncrease,
            vars
        );

        // When the adjustment is a debt repayment, check it's a valid amount and that the caller has enough Debt
        if (!_isDebtIncrease && _debtChange > 0) {
            _requireAtLeastMinNetDebt(_getNetDebt(vars.debt) - vars.netDebtChange);
        }

        // If we are increasing collateral, send tokens to the den manager prior to adjusting the den
        if (vars.isCollIncrease) collateralToken.safeTransferFrom(msg.sender, address(denManager), vars.collChange);

        (vars.newColl, vars.newDebt, vars.stake) = denManager.updateDenFromAdjustment(
            _isDebtIncrease,
            vars.debtChange,
            vars.netDebtChange,
            vars.isCollIncrease,
            vars.collChange,
            _upperHint,
            _lowerHint,
            vars.account,
            msg.sender
        );

        emit DenUpdated(denManager, vars.account, vars.newDebt, vars.newColl, vars.stake, BorrowerOperation.adjustDen);
    }

    function closeDen(IDenManager denManager, address account) external callerOrDelegated(account) {
        IERC20 collateralToken;

        uint256 price;
        bool isRecoveryMode;
        uint256 totalPricedCollateral;
        uint256 totalDebt;
        (collateralToken, price, totalPricedCollateral, totalDebt, isRecoveryMode) = _getCollateralAndTCRData(
            denManager
        );
        require(!isRecoveryMode, "BorrowerOps: Operation not permitted during Recovery Mode");

        (uint256 coll, uint256 debt) = denManager.applyPendingRewards(account);

        uint256 newTCR = _getNewTCRFromDenChange(totalPricedCollateral, totalDebt, coll * price, false, debt, false);
        _requireNewTCRisAboveCCR(newTCR);

        denManager.closeDen(account, msg.sender, coll, debt);

        emit DenUpdated(denManager, account, 0, 0, 0, BorrowerOperation.closeDen);

        // Burn the repaid Debt from the user's balance and the gas compensation from the Gas Pool
        debtToken.burnWithGasCompensation(msg.sender, debt - DEBT_GAS_COMPENSATION);
    }


    // --- Helper functions ---

    function _triggerBorrowingFee(
        IDenManager _denManager,
        address _caller,
        uint256 _maxFeePercentage,
        uint256 _debtAmount
    ) internal returns (uint256) {
        /// @dev Doesn't update the base rate
        if (_caller == brimeDen) {
            return 0;
        }

        uint256 debtFee = _denManager.decayBaseRateAndGetBorrowingFee(_debtAmount);

        _requireUserAcceptsFee(debtFee, _debtAmount, _maxFeePercentage);

        debtToken.mint(BERABORROW_CORE.feeReceiver(), debtFee);

        emit BorrowingFeePaid(_denManager, _caller, debtFee);

        return debtFee;
    }

    function _getCollChange(
        uint256 _collReceived,
        uint256 _requestedCollWithdrawal
    ) internal pure returns (uint256 collChange, bool isCollIncrease) {
        if (_collReceived != 0) {
            collChange = _collReceived;
            isCollIncrease = true;
        } else {
            collChange = _requestedCollWithdrawal;
        }
    }

    function _requireValidAdjustmentInCurrentMode(
        uint256 totalPricedCollateral,
        uint256 totalDebt,
        bool _isRecoveryMode,
        uint256 _collWithdrawal,
        bool _isDebtIncrease,
        LocalVariables_adjustDen memory _vars
    ) internal view {
        /*
         *In Recovery Mode, only allow:
         *
         * - Pure collateral top-up
         * - Pure debt repayment
         * - Collateral top-up with debt repayment
         * - A debt increase combined with a collateral top-up which makes the ICR >= 150% and improves the ICR (and by extension improves the TCR).
         *
         * In Normal Mode, ensure:
         *
         * - The new ICR is above MCR
         * - The adjustment won't pull the TCR below CCR
         */

        // Get the den's old ICR before the adjustment
        uint256 oldICR = BeraborrowMath._computeCR(_vars.coll, _vars.debt, _vars.price);

        // Get the den's new ICR after the adjustment
        uint256 newICR = _getNewICRFromDenChange(
            _vars.coll,
            _vars.debt,
            _vars.collChange,
            _vars.isCollIncrease,
            _vars.netDebtChange,
            _isDebtIncrease,
            _vars.price
        );

        if (_isRecoveryMode) {
            require(_collWithdrawal == 0, "BorrowerOps: Collateral withdrawal not permitted Recovery Mode");
            if (_isDebtIncrease) {
                _requireICRisAboveCCR(newICR);
                _requireNewICRisAboveOldICR(newICR, oldICR);
            }
        } else {
            // if Normal Mode
            _requireICRisAboveMCR(newICR, _vars.MCR, _vars.account);
            uint256 newTCR = _getNewTCRFromDenChange(
                totalPricedCollateral,
                totalDebt,
                _vars.collChange * _vars.price,
                _vars.isCollIncrease,
                _vars.netDebtChange,
                _isDebtIncrease
            );
            _requireNewTCRisAboveCCR(newTCR);
        }
    }

    function _requireICRisAboveMCR(uint256 _newICR, uint256 MCR, address _account) internal view {
        require(
            _newICR >= (_account != brimeDen ? MCR : brimeMCR),
            "BorrowerOps: An operation that would result in ICR < MCR is not permitted"
        );
    }

    function _requireICRisAboveCCR(uint256 _newICR) internal view {
        require(_newICR >= BERABORROW_CORE.CCR(), "BorrowerOps: Operation must leave den with ICR >= CCR");
    }

    function _requireNewICRisAboveOldICR(uint256 _newICR, uint256 _oldICR) internal pure {
        require(_newICR >= _oldICR, "BorrowerOps: Cannot decrease your Den's ICR in Recovery Mode");
    }

    function _requireNewTCRisAboveCCR(uint256 _newTCR) internal view {
        require(_newTCR >= BERABORROW_CORE.CCR(), "BorrowerOps: An operation that would result in TCR < CCR is not permitted");
    }

    function _requireAtLeastMinNetDebt(uint256 _netDebt) internal view {
        require(_netDebt >= minNetDebt, "BorrowerOps: Den's net debt must be greater than minimum");
    }

    function _requireValidMaxFeePercentage(uint256 _maxFeePercentage) internal pure {
        require(_maxFeePercentage <= DECIMAL_PRECISION, "Max fee percentage must less than or equal to 100%");
    }

    // Compute the new collateral ratio, considering the change in coll and debt. Assumes 0 pending rewards.
    function _getNewICRFromDenChange(
        uint256 _coll,
        uint256 _debt,
        uint256 _collChange,
        bool _isCollIncrease,
        uint256 _debtChange,
        bool _isDebtIncrease,
        uint256 _price
    ) internal pure returns (uint256) {
        (uint256 newColl, uint256 newDebt) = _getNewDenAmounts(
            _coll,
            _debt,
            _collChange,
            _isCollIncrease,
            _debtChange,
            _isDebtIncrease
        );

        uint256 newICR = BeraborrowMath._computeCR(newColl, newDebt, _price);
        return newICR;
    }

    function _getNewDenAmounts(
        uint256 _coll,
        uint256 _debt,
        uint256 _collChange,
        bool _isCollIncrease,
        uint256 _debtChange,
        bool _isDebtIncrease
    ) internal pure returns (uint256, uint256) {
        uint256 newColl = _coll;
        uint256 newDebt = _debt;

        newColl = _isCollIncrease ? _coll + _collChange : _coll - _collChange;
        newDebt = _isDebtIncrease ? _debt + _debtChange : _debt - _debtChange;

        return (newColl, newDebt);
    }

    function _getNewTCRFromDenChange(
        uint256 totalColl,
        uint256 totalDebt,
        uint256 _collChange,
        bool _isCollIncrease,
        uint256 _debtChange,
        bool _isDebtIncrease
    ) internal pure returns (uint256) {
        totalDebt = _isDebtIncrease ? totalDebt + _debtChange : totalDebt - _debtChange;
        totalColl = _isCollIncrease ? totalColl + _collChange : totalColl - _collChange;

        uint256 newTCR = BeraborrowMath._computeCR(totalColl, totalDebt);
        return newTCR;
    }

    function _getTCRData(
        SystemBalances memory balances
    ) internal pure returns (uint256 amount, uint256 totalPricedCollateral, uint256 totalDebt) {
        uint256 loopEnd = balances.collaterals.length;
        for (uint256 i; i < loopEnd; ) {
            totalPricedCollateral += (balances.collaterals[i] * balances.prices[i]);
            totalDebt += balances.debts[i];
            unchecked {
                ++i;
            }
        }
        amount = BeraborrowMath._computeCR(totalPricedCollateral, totalDebt);

        return (amount, totalPricedCollateral, totalDebt);
    }

    function _getCollateralAndTCRData(
        IDenManager denManager
    )
        internal view
        returns (
            IERC20 collateralToken,
            uint256 price,
            uint256 totalPricedCollateral,
            uint256 totalDebt,
            bool isRecoveryMode
        )
    {
        DenManagerData storage t = denManagersData[denManager];
        uint256 index;
        (collateralToken, index) = (t.collateralToken, t.index);

        require(address(collateralToken) != address(0), "Collateral not enabled");

        uint256 amount;
        SystemBalances memory balances = fetchBalances();
        (amount, totalPricedCollateral, totalDebt) = _getTCRData(balances);
        isRecoveryMode = checkRecoveryMode(amount);

        return (collateralToken, balances.prices[index], totalPricedCollateral, totalDebt, isRecoveryMode);
    }

    function getGlobalSystemBalances() external view returns (uint256 totalPricedCollateral, uint256 totalDebt) {
        SystemBalances memory balances = fetchBalances();
        (, totalPricedCollateral, totalDebt) = _getTCRData(balances);
    }

}
