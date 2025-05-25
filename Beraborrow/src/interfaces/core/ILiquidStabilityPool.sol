// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC1822Proxiable} from "@openzeppelin/contracts/interfaces/draft-IERC1822.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IMetaBeraborrowCore} from "./IMetaBeraborrowCore.sol";
import {IDebtToken} from "./IDebtToken.sol";
import {IDebtToken} from "./IDebtToken.sol";
import {EmissionsLib} from "src/libraries/EmissionsLib.sol";

interface ILiquidStabilityPool is IERC4626, IERC1822Proxiable {
    struct LSPStorage {
        IMetaBeraborrowCore metaBeraborrowCore;
        address feeReceiver;
        /// @notice Array of tokens that have been emitted to the LiquidStabilityPool
        /// @notice Used to track which tokens can be withdrawn to LSP share holders
        /// @dev Doesn't include tokens that are already BeraBorrow's collaterals
        EnumerableSet.AddressSet extraAssets;
        Queue queue;
        address[] collateralTokens;
        mapping(uint16 => SunsetIndex) _sunsetIndexes;
        mapping(address collateral => uint256 index) indexByCollateral;
        mapping(bytes32 => uint) threshold;
        EmissionsLib.BalanceData balanceData;
        mapping(address => bool) factoryProtocol;
        mapping(address => bool) liquidationManagerProtocol;
        // Allowed to withdraw their positions during bootstrap period
        mapping(address => bool) boycoVault;
    }

    struct InitParams {
        IERC20 _asset;
        string _sharesName;
        string _sharesSymbol;
        IMetaBeraborrowCore _metaBeraborrowCore;
        address _liquidationManager;
        address _factory;
        address _feeReceiver;
    }

    struct RebalanceParams {
        address sentCurrency;
        uint sentAmount;
        address receivedCurrency;
        address swapper;
        bytes payload;
    }

    struct SunsetIndex {
        uint128 idx;
        uint128 expiry;
    }

    struct Queue {
        uint16 firstSunsetIndexKey;
        uint16 nextSunsetIndexKey;
    }

    event CollAndEmissionsWithdraw(
        address indexed receiver,
        uint shares,
        uint[] amounts
    );

    struct Arrays {
        uint length;
        address[] collaterals;
        uint collateralsLength;
        uint[] amounts;
    }

    event EmissionTokenAdded(address token);
    event EmissionTokenRemoved(address token);
    event StabilityPoolDebtBalanceUpdated(uint256 newBalance);
    event UserDepositChanged(address indexed depositor, uint256 newDeposit);
    event CollateralOverwritten(address oldCollateral, address newCollateral);

    // PROXY
    function upgradeToAndCall(address newImplementation, bytes calldata data) external;
    function getCurrentImplementation() external view returns (address);

    function SUNSET_DURATION() external view returns (uint128);
    function totalDebtTokenDeposits() external view returns (uint256);
    function enableCollateral(address _collateral, uint64 _unlockRatePerSecond, bool forceThroughBalanceCheck) external;
    function startCollateralSunset(address collateral) external;
    function getTotalDebtTokenDeposits() external view returns (uint256);
    function getCollateralTokens() external view returns (address[] memory);
    function offset(address collateral, uint256 _debtToOffset, uint256 _collToAdd) external;
    function initialize(InitParams calldata params) external;
    function rebalance(RebalanceParams calldata p) external;
    function linearVestingExtraAssets(address token, int amount, address recipient) external;
    function withdraw(
        uint assets,
        address[] calldata preferredUnderlyingTokens,
        address receiver,
        address _owner
    ) external returns (uint shares);
    function redeem(
        uint shares,
        address[] calldata preferredUnderlyingTokens,
        address receiver,
        address _owner
    ) external returns (uint assets);
    function updateProtocol(
        address _liquidationManager, 
        address _factory,
        bool _register
    ) external;
    function addNewExtraAsset(address token, uint64 _unlockRatePerSecond) external;
    function removeEmitedTokens(address token) external;
    function setPairThreshold(address tokenIn, address tokenOut, uint thresholdInBP) external;
    function setUnlockRatePerSecond(address token, uint64 _unlockRatePerSecond) external;
    function getPrice(address token) external view returns (uint);
    function getLockedEmissions(address token) external view returns (uint);
    function extSloads(bytes32[] calldata slots) external view returns (bytes32[] memory res);
    function unlockRatePerSecond(address token) external view returns (uint);
    function removeExtraAsset(address token) external;
}
