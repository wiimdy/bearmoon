// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "../dependencies/BeraborrowOwnable.sol";
import "../interfaces/core/IDenManager.sol";
import "../interfaces/core/IBorrowerOperations.sol";
import "../interfaces/core/IDebtToken.sol";
import "../interfaces/core/ISortedDens.sol";
import "../interfaces/core/ILiquidStabilityPool.sol";
import "../interfaces/core/ILiquidStabilityPool.sol";
import "../interfaces/core/ILiquidationManager.sol";
import "../interfaces/core/IFactory.sol";

/**
    @title Beraborrow Den Factory
    @notice Deploys cloned pairs of `DenManager` and `SortedDens` in order to
            add new collateral types within the system.
 */
contract Factory is BeraborrowOwnable {
    using Clones for address;

    // fixed single-deployment contracts
    IDebtToken public immutable debtToken;
    ILiquidStabilityPool public immutable liquidStabilityPool;
    ILiquidationManager public immutable liquidationManager;
    IBorrowerOperations public immutable borrowerOperations;

    // implementation contracts, redeployed each time via clone proxy
    address public sortedDensImpl;
    address public denManagerImpl;

    address[] public denManagers;

    event NewDeployment(address collateral, address priceFeed, address denManager, address sortedDens);

    constructor(
        address _beraborrowCore,
        IDebtToken _debtToken,
        ILiquidStabilityPool _liquidStabilityPool,
        IBorrowerOperations _borrowerOperations,
        address _sortedDens,
        address _denManager,
        ILiquidationManager _liquidationManager
    ) BeraborrowOwnable(_beraborrowCore) {
        if (_beraborrowCore == address(0) || address(_debtToken) == address(0) || address(_liquidStabilityPool) == address(0) || address(_borrowerOperations) == address(0) || _sortedDens == address(0) || _denManager == address(0) || address(_liquidationManager) == address(0)) {
            revert("Factory: 0 address");
        }

        debtToken = _debtToken;
        liquidStabilityPool = _liquidStabilityPool;
        borrowerOperations = _borrowerOperations;

        sortedDensImpl = _sortedDens;
        denManagerImpl = _denManager;
        liquidationManager = _liquidationManager;
    }

    modifier onlyOwnerOrManager() {
        require(msg.sender == owner() || msg.sender == BERABORROW_CORE.manager(), "Only owner or manager");
        _;
    }

    function denManagerCount() external view returns (uint256) {
        return denManagers.length;
    }

    /**
        @notice Deploy new instances of `DenManager` and `SortedDens`, adding
                a new collateral type to the system.
        @dev * When using the default `PriceFeed`, ensure it is configured correctly
               prior to calling this function.
             * After calling this function, the owner should also call `Vault.registerReceiver`
               to enable POLLEN emissions on the newly deployed `DenManager`
        @param collateral Collateral token to use in new deployment
        @param priceFeed Custom `PriceFeed` deployment. Leave as `address(0)` to use the default.
        @param customDenManagerImpl Custom `DenManager` implementation to clone from.
                                      Leave as `address(0)` to use the default.
        @param customSortedDensImpl Custom `SortedDens` implementation to clone from.
                                      Leave as `address(0)` to use the default.
        @param params Struct of initial parameters to be set on the new den manager
     */
    function deployNewInstance(
        address collateral,
        address priceFeed,
        address customDenManagerImpl,
        address customSortedDensImpl,
        IFactory.DeploymentParams calldata params,
        uint64 unlockRatePerSecond,
        bool forceThroughLspBalanceCheck
    ) external onlyOwnerOrManager {
        address implementation = customDenManagerImpl == address(0) ? denManagerImpl : customDenManagerImpl;
        address denManager = implementation.cloneDeterministic(bytes32(bytes20(collateral)));
        denManagers.push(denManager);

        implementation = customSortedDensImpl == address(0) ? sortedDensImpl : customSortedDensImpl;
        address sortedDens = implementation.cloneDeterministic(bytes32(bytes20(denManager)));

        IDenManager(denManager).setAddresses(priceFeed, sortedDens, collateral);
        ISortedDens(sortedDens).setAddresses(denManager);

        // verify that the oracle is correctly working
        IDenManager(denManager).fetchPrice();

        liquidStabilityPool.enableCollateral(collateral, unlockRatePerSecond, forceThroughLspBalanceCheck);
        liquidationManager.enableDenManager(denManager);
        debtToken.enableDenManager(denManager);
        borrowerOperations.configureCollateral(denManager, collateral);

        IDenManager(denManager).setParameters(params);

        emit NewDeployment(collateral, priceFeed, denManager, sortedDens);
    }

    function setImplementations(address _denManagerImpl, address _sortedDensImpl) external onlyOwner {
        denManagerImpl = _denManagerImpl;
        sortedDensImpl = _sortedDensImpl;
    }
}
