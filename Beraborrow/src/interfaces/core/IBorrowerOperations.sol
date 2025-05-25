// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {IBeraborrowCore} from "./IBeraborrowCore.sol";

interface IBorrowerOperations {
    struct Balances {
        uint256[] collaterals;
        uint256[] debts;
        uint256[] prices;
    }

    event BorrowingFeePaid(address indexed borrower, uint256 amount);
    event CollateralConfigured(address denManager, address collateralToken);
    event DenCreated(address indexed _borrower, uint256 arrayIndex);
    event DenManagerRemoved(address denManager);
    event DenUpdated(address indexed _borrower, uint256 _debt, uint256 _coll, uint256 stake, uint8 operation);

    function addColl(
        address denManager,
        address account,
        uint256 _collateralAmount,
        address _upperHint,
        address _lowerHint
    ) external;

    function adjustDen(
        address denManager,
        address account,
        uint256 _maxFeePercentage,
        uint256 _collDeposit,
        uint256 _collWithdrawal,
        uint256 _debtChange,
        bool _isDebtIncrease,
        address _upperHint,
        address _lowerHint
    ) external;

    function brimeDen() external view returns (address);

    function closeDen(address denManager, address account) external;

    function configureCollateral(address denManager, address collateralToken) external;

    function fetchBalances() external view returns (Balances memory balances);

    function getGlobalSystemBalances() external view returns (uint256 totalPricedCollateral, uint256 totalDebt);

    function getTCR() external view returns (uint256 globalTotalCollateralRatio);

    function openDen(
        address denManager,
        address account,
        uint256 _maxFeePercentage,
        uint256 _collateralAmount,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external;

    function removeDenManager(address denManager) external;

    function repayDebt(
        address denManager,
        address account,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external;

    function setDelegateApproval(address _delegate, bool _isApproved) external;

    function setMinNetDebt(uint256 _minNetDebt) external;

    function withdrawColl(
        address denManager,
        address account,
        uint256 _collWithdrawal,
        address _upperHint,
        address _lowerHint
    ) external;

    function withdrawDebt(
        address denManager,
        address account,
        uint256 _maxFeePercentage,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external;

    function denManagers(uint256) external view returns (address);

    function checkRecoveryMode(uint256 TCR) external view returns (bool);

    function DEBT_GAS_COMPENSATION() external view returns (uint256);

    function DECIMAL_PRECISION() external view returns (uint256);

    function PERCENT_DIVISOR() external view returns (uint256);

    function BERABORROW_CORE() external view returns (IBeraborrowCore);

    function debtToken() external view returns (address);

    function factory() external view returns (address);

    function getCompositeDebt(uint256 _debt) external view returns (uint256);

    function guardian() external view returns (address);

    function isApprovedDelegate(address owner, address caller) external view returns (bool isApproved);

    function minNetDebt() external view returns (uint256);

    function owner() external view returns (address);

    function denManagersData(address) external view returns (address collateralToken, uint16 index);

    function brimeMCR() external view returns (uint256);
}
