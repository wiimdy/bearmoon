// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IStrategy} from "../interfaces/IStrategy.sol";
import {IController} from "../interfaces/IController.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IBGT} from "../interfaces/IBGT.sol";
import {ISwapRouter} from "../interfaces/ISwapRouter.sol";
import {ILpRouter} from "../interfaces/ILpRouter.sol";
import {IZapper} from "../interfaces/IZapper.sol";
import {IWETH} from "../interfaces/exchange/IWETH.sol";
import {SphereXProtected} from "@spherex-xyz/SphereXProtected.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title Strategy Base Contract
/// @notice Base contract for all investment strategies
/// @dev Implements core functionality for strategy contracts including access control and fee management
abstract contract StrategyBase is SphereXProtected, ReentrancyGuard, IStrategy {
    using SafeERC20 for IERC20;
    using Address for address;

    /// @notice Maximum basis points (100%)
    uint16 public constant MAX_FEE_BPS = 10000;
    /// @notice Maximum fee that can be set (50% = 5000 basis points)
    uint16 public constant MAX_PERFORMANCE_FEE = 5000;
    /// @notice Maximum fee that can be set (10% = 1000 basis points)
    uint16 public constant MAX_WITHDRAWAL_FEE = 1000;
    /// @notice Wrapped native token address
    address public immutable wrappedNative;
    /// @notice BGT token address
    IBGT public immutable bgt;

    // **** State Variables **** //

    /// @notice Mapping of addresses authorized to call harvest
    mapping(address => bool) public harvesters;
    /// @notice Performance fee sent to treasury (default 10%)
    uint16 public performanceTreasuryFee = 1000;
    /// @notice Performance fee sent to dev fund (default 0%)
    uint16 public performanceDevFee = 0;
    /// @notice Withdrawal fee sent to treasury (default 0%)
    uint16 public withdrawalTreasuryFee = 0;
    /// @notice Withdrawal fee sent to dev fund (default 0%)
    uint16 public withdrawalDevFundFee = 0;
    /// @notice The asset being managed by this strategy
    IERC20 public asset;
    /// @notice Address with highest privilege (can change governance)
    address public governance;
    /// @notice Address of controller contract that manages this strategy
    address public controller;
    /// @notice Address that can manage strategy parameters
    address public strategist;
    /// @notice Address that can execute time-sensitive operations
    address public timelock;
    /// @notice Swap router address
    ISwapRouter public swapRouter;
    /// @notice LP router address
    ILpRouter public lpRouter;
    /// @notice Zapper contract
    IZapper public zapper;

    constructor(
        address assetAddress,
        address governanceAddress,
        address strategistAddress,
        address controllerAddress,
        address timelockAddress,
        address wrappedNativeAddress,
        address bgtAddress,
        address swapRouterAddress,
        address lpRouterAddress,
        address zapperAddress
    ) {
        if (
            assetAddress == address(0) ||
            governanceAddress == address(0) ||
            strategistAddress == address(0) ||
            controllerAddress == address(0) ||
            timelockAddress == address(0) ||
            bgtAddress == address(0) ||
            wrappedNativeAddress == address(0) ||
            swapRouterAddress == address(0) ||
            lpRouterAddress == address(0) ||
            zapperAddress == address(0)
        ) {
            revert ZeroAddress();
        }

        asset = IERC20(assetAddress);
        governance = governanceAddress;
        strategist = strategistAddress;
        controller = controllerAddress;
        timelock = timelockAddress;
        wrappedNative = wrappedNativeAddress;
        bgt = IBGT(bgtAddress);
        swapRouter = ISwapRouter(swapRouterAddress);
        lpRouter = ILpRouter(lpRouterAddress);
        zapper = IZapper(zapperAddress);
        harvesters[strategistAddress] = true;
        emit HarvesterWhitelisted(strategistAddress);
    }

    receive() external payable {
        if (
            msg.sender != address(bgt) &&
            msg.sender != wrappedNative &&
            msg.sender != address(zapper)
        ) revert EthTransferNotAllowed();
    }

    // **** Modifiers **** //

    /// @notice Restricts function access to authorized harvesters, governance, or strategist
    /// @dev Used to control who can call harvest and other yield-related functions
    modifier onlyBenevolent() {
        _revertOnlyBenevolent();
        _;
    }

    /// @notice Restricts function access to only the controller contract
    /// @dev Used for functions that should only be called through the controller
    modifier onlyController() {
        _revertOnlyController();
        _;
    }

    /// @notice Restricts function access to only the timelock contract
    /// @dev Used for time-sensitive operations and parameter updates
    modifier onlyTimelock() {
        _revertOnlyTimelock();
        _;
    }

    /// @notice Restricts function access to only the governance address
    /// @dev Used for highest privilege operations like changing governance
    modifier onlyGovernance() {
        _revertOnlyGovernance();
        _;
    }

    // **** Views **** //

    /// @notice Returns the balance of the asset token held by this strategy
    /// @return Amount of asset tokens in the strategy
    function balanceOfAsset() public view returns (uint256) {
        return IERC20(asset).balanceOf(address(this));
    }

    /// @notice Returns the balance of assets deployed in external protocols
    /// @dev Must be implemented by specific strategy implementations
    /// @return Amount of assets deployed in yield generating activities
    function balanceOfPool() public view virtual returns (uint256);

    /// @notice Returns the total balance managed by this strategy
    /// @return Sum of assets held directly and deployed in pools
    function balanceOf() public view returns (uint256) {
        return balanceOfAsset() + balanceOfPool();
    }

    // **** Internal Functions **** //

    /// @notice Reverts if the address is zero
    /// @param _address The address to check
    function _revertAddressZero(address _address) internal pure {
        if (_address == address(0)) revert ZeroAddress();
    }

    /// @notice Reverts if the caller is not the governance address
    function _revertOnlyGovernance() internal view {
        if (msg.sender != governance) revert NotGovernance();
    }

    /// @notice Reverts if the caller is not the timelock address
    function _revertOnlyTimelock() internal view {
        if (msg.sender != timelock) revert NotTimelock();
    }

    /// @notice Reverts if the caller is not the controller address
    function _revertOnlyController() internal view {
        if (msg.sender != controller) revert NotController();
    }

    /// @notice Reverts if the caller is not benevolent
    function _revertOnlyBenevolent() internal view {
        if (
            !harvesters[msg.sender] &&
            msg.sender != governance &&
            msg.sender != strategist
        ) revert NotBenevolent();
    }

    /// @notice Claim BGT, convert to BERA and swap to asset using zapper
    /// @return amount Amount of asset received
    function _swapBGTToAsset()
        internal
        sphereXGuardInternal(0x6e7957c8)
        returns (uint256 amount)
    {
        uint256 balance = IERC20(bgt).balanceOf(address(this));
        if (balance > 0) {
            bgt.redeem(address(this), balance);
            uint256 beraBalance = address(this).balance;
            IWETH(wrappedNative).deposit{value: beraBalance}();
            IERC20(wrappedNative).forceApprove(address(zapper), beraBalance);
            (amount, ) = zapper.swapToAssets(
                address(asset),
                address(wrappedNative),
                beraBalance,
                address(this)
            );
        }
    }

    // **** Setters **** //

    /// @notice Adds an address to the list of authorized harvesters
    /// @param harvesterAddress Address to authorize for harvesting
    function whitelistHarvester(
        address harvesterAddress
    ) external sphereXGuardExternal(0x6e38ed4d) onlyBenevolent {
        _revertAddressZero(harvesterAddress);
        harvesters[harvesterAddress] = true;
        emit HarvesterWhitelisted(harvesterAddress);
    }

    /// @notice Removes an address from the list of authorized harvesters
    /// @param harvesterAddress Address to revoke harvesting rights from
    function revokeHarvester(
        address harvesterAddress
    ) external sphereXGuardExternal(0x6f4a07f4) onlyBenevolent {
        _revertAddressZero(harvesterAddress);
        harvesters[harvesterAddress] = false;
        emit HarvesterRevoked(harvesterAddress);
    }

    /// @notice Sets the withdrawal fee percentage for the dev fund
    /// @param fee New fee in basis points (1/100th of a percent)
    function setWithdrawalDevFundFee(
        uint16 fee
    ) external onlyTimelock sphereXGuardExternal(0x219c2d6e) {
        if (fee + withdrawalTreasuryFee > MAX_WITHDRAWAL_FEE)
            revert FeeTooHigh(fee, MAX_WITHDRAWAL_FEE);
        uint16 old = withdrawalDevFundFee;
        withdrawalDevFundFee = fee;
        emit WithdrawalDevFundFeeChanged(old, fee);
    }

    /// @notice Sets the withdrawal fee percentage for the treasury
    /// @param fee New fee in basis points
    function setWithdrawalTreasuryFee(
        uint16 fee
    ) external onlyTimelock sphereXGuardExternal(0x63c66135) {
        if (fee + withdrawalDevFundFee > MAX_WITHDRAWAL_FEE)
            revert FeeTooHigh(fee, MAX_WITHDRAWAL_FEE);
        uint16 old = withdrawalTreasuryFee;
        withdrawalTreasuryFee = fee;
        emit WithdrawalTreasuryFeeChanged(old, fee);
    }

    /// @notice Sets the performance fee percentage for the dev fund
    /// @param fee New fee in basis points
    function setPerformanceDevFee(
        uint16 fee
    ) external onlyTimelock sphereXGuardExternal(0x39189706) {
        if (fee + performanceTreasuryFee > MAX_PERFORMANCE_FEE)
            revert FeeTooHigh(fee, MAX_PERFORMANCE_FEE);
        uint16 old = performanceDevFee;
        performanceDevFee = fee;
        emit PerformanceDevFeeChanged(old, fee);
    }

    /// @notice Sets the performance fee percentage for the treasury
    /// @param fee New fee in basis points
    function setPerformanceTreasuryFee(
        uint16 fee
    ) external onlyTimelock sphereXGuardExternal(0x76672d92) {
        if (fee + performanceDevFee > MAX_PERFORMANCE_FEE)
            revert FeeTooHigh(fee, MAX_PERFORMANCE_FEE);
        uint16 old = performanceTreasuryFee;
        performanceTreasuryFee = fee;
        emit PerformanceTreasuryFeeChanged(old, fee);
    }

    /// @notice Updates the strategist address
    /// @param strategistAddress New strategist address
    function setStrategist(
        address strategistAddress
    ) external onlyGovernance sphereXGuardExternal(0xfbe05f47) {
        _revertAddressZero(strategistAddress);
        address old = strategist;
        strategist = strategistAddress;
        emit StrategistChanged(old, strategistAddress);
    }

    /// @notice Updates the governance address
    /// @param governanceAddress New governance address
    function setGovernance(
        address governanceAddress
    ) external onlyGovernance sphereXGuardExternal(0x1bb893a5) {
        _revertAddressZero(governanceAddress);
        address old = governance;
        governance = governanceAddress;
        emit GovernanceChanged(old, governanceAddress);
    }

    /// @notice Updates the timelock address
    /// @param timelockAddress New timelock address
    function setTimelock(
        address timelockAddress
    ) external onlyTimelock sphereXGuardExternal(0xee3d9cc1) {
        _revertAddressZero(timelockAddress);
        address old = timelock;
        timelock = timelockAddress;
        emit TimelockChanged(old, timelockAddress);
    }

    /// @notice Updates the controller address
    /// @param controllerAddress New controller address
    function setController(
        address controllerAddress
    ) external onlyTimelock sphereXGuardExternal(0x4d05853d) {
        _revertAddressZero(controllerAddress);
        address old = controller;
        controller = controllerAddress;
        emit ControllerChanged(old, controllerAddress);
    }

    /// @notice Sets the swap router address
    /// @param swapRouterAddress New swap router address
    function setSwapRouter(
        address swapRouterAddress
    ) external onlyGovernance sphereXGuardExternal(0xa8988767) {
        _revertAddressZero(swapRouterAddress);
        address old = address(swapRouter);
        swapRouter = ISwapRouter(swapRouterAddress);
        emit SwapRouterChanged(old, swapRouterAddress);
    }

    /// @notice Sets the LP router address
    /// @param lpRouterAddress New LP router address
    function setLpRouter(
        address lpRouterAddress
    ) external onlyGovernance sphereXGuardExternal(0x5c5c6eff) {
        _revertAddressZero(lpRouterAddress);
        address old = address(lpRouter);
        lpRouter = ILpRouter(lpRouterAddress);
        emit LpRouterChanged(old, lpRouterAddress);
    }

    /// @notice Sets the zapper address
    /// @param zapperAddress New zapper address
    function setZapper(
        address zapperAddress
    ) external onlyGovernance sphereXGuardExternal(0x4d0d76be) {
        _revertAddressZero(zapperAddress);
        address old = address(zapper);
        zapper = IZapper(zapperAddress);
        emit ZapperChanged(old, zapperAddress);
    }

    // **** State mutations **** //

    /// @notice Deposits assets into the yield generating protocol
    /// @dev Must be implemented by specific strategy implementations
    function deposit() public virtual;

    /// @notice Returns the harvestable rewards
    /// @return rewards Addresses of reward tokens
    ///@return amounts Amounts of reward tokens available
    function getHarvestable()
        external
        view
        virtual
        returns (address[] memory rewards, uint256[] memory amounts)
    {
        rewards = new address[](1);
        amounts = new uint256[](1);
        rewards[0] = address(bgt);
        amounts[0] = bgt.balanceOf(address(this));
    }

    /// @notice Harvests and compounds rewards from the yield generating protocol
    /// @dev Must be implemented by specific strategy implementations
    function harvest()
        public
        virtual
        nonReentrant
        onlyBenevolent
        sphereXGuardPublic(0x8ab9334c, 0x4641257d)
    {
        uint256 newAssets = _swapBGTToAsset();
        _distributePerformanceFeesBasedAmountAndDeposit(newAssets);
        emit Harvest(block.timestamp, newAssets);
    }

    /// @notice Internal function to withdraw a specific amount from the yield generating protocol
    /// @dev Must be implemented by specific strategy implementations
    /// @param amount Amount of assets to withdraw
    /// @return Amount actually withdrawn
    function _withdrawSome(uint256 amount) internal virtual returns (uint256);

    /// @notice Withdraws dust tokens (non-strategy assets) to the controller
    /// @param token Token address to withdraw
    /// @return balance Amount of tokens withdrawn
    function withdraw(
        address token
    )
        external
        nonReentrant
        onlyController
        sphereXGuardExternal(0xf1588fd0)
        returns (uint256 balance)
    {
        if (address(asset) == address(token)) revert InvalidAsset();
        balance = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(controller, balance);
    }

    /// @notice Withdraws a specific amount of assets, including fees
    /// @param amount Amount of assets to withdraw
    function withdraw(
        uint256 amount
    ) external nonReentrant onlyController sphereXGuardExternal(0xbc6047d4) {
        uint256 balance = IERC20(asset).balanceOf(address(this));
        if (balance < amount) {
            amount = _withdrawSome(amount - balance);
            amount = amount + balance;
        }

        uint256 feeDev = (amount * withdrawalDevFundFee) / MAX_FEE_BPS;
        if (feeDev > 0) {
            IERC20(asset).safeTransfer(
                IController(controller).devfund(),
                feeDev
            );
            emit WithdrawalDevFundFeeCollected(feeDev);
        }

        uint256 feeTreasury = (amount * withdrawalTreasuryFee) / MAX_FEE_BPS;
        if (feeTreasury > 0) {
            IERC20(asset).safeTransfer(
                IController(controller).treasury(),
                feeTreasury
            );
            emit WithdrawalTreasuryFeeCollected(feeTreasury);
        }

        address vault = IController(controller).vaults(address(asset));
        if (vault == address(0)) revert InvalidVault();

        IERC20(asset).safeTransfer(vault, amount - feeDev - feeTreasury);
    }

    /// @notice Withdraws assets for strategy migration
    /// @param amount Amount of assets to withdraw
    /// @return balance Amount actually withdrawn
    function withdrawForSwap(
        uint256 amount
    )
        external
        nonReentrant
        onlyController
        sphereXGuardExternal(0x8f20ccb0)
        returns (uint256 balance)
    {
        _withdrawSome(amount);

        balance = IERC20(asset).balanceOf(address(this));

        address vault = IController(controller).vaults(address(asset));
        if (vault == address(0)) revert InvalidVault();
        IERC20(asset).safeTransfer(vault, balance);
    }

    /// @notice Withdraws all assets from the strategy
    /// @return balance Total amount withdrawn
    function withdrawAll()
        external
        nonReentrant
        onlyController
        sphereXGuardExternal(0xda6c39c3)
        returns (uint256 balance)
    {
        _withdrawAll();

        balance = IERC20(asset).balanceOf(address(this));

        address _vault = IController(controller).vaults(address(asset));
        if (_vault == address(0)) revert InvalidVault();
        if (balance > 0) {
            IERC20(asset).safeTransfer(_vault, balance);
        }
    }

    /// @notice Internal function to withdraw all assets from yield generating protocol
    function _withdrawAll() internal sphereXGuardInternal(0xf0692ab1) {
        _withdrawSome(balanceOfPool());
    }

    /// @notice Executes arbitrary function calls via delegatecall
    /// @dev Used for emergency functions and upgrades
    /// @param target Address of contract to call
    /// @param data Calldata for the function call
    /// @return response Return data from the function call
    function execute(
        address target,
        bytes memory data
    )
        public
        payable
        onlyTimelock
        sphereXGuardPublic(0x3acab6ad, 0x1cff79cd)
        returns (bytes memory response)
    {
        _revertAddressZero(target);

        // call contract in current context
        assembly {
            let succeeded := delegatecall(
                sub(gas(), 5000),
                target,
                add(data, 0x20),
                mload(data),
                0,
                0
            )
            let size := returndatasize()

            response := mload(0x40)
            mstore(
                0x40,
                add(response, and(add(add(size, 0x20), 0x1f), not(0x1f)))
            )
            mstore(response, size)
            returndatacopy(add(response, 0x20), 0, size)

            switch iszero(succeeded)
            case 1 {
                // throw if delegatecall failed
                revert(add(response, 0x20), size)
            }
        }
    }

    /// @notice Distributes performance fees and deposits remaining rewards
    /// @param amount Amount of rewards to distribute
    function _distributePerformanceFeesBasedAmountAndDeposit(
        uint256 amount
    ) internal sphereXGuardInternal(0xff626c51) {
        uint256 assetBalance = IERC20(asset).balanceOf(address(this));

        if (amount > assetBalance) {
            amount = assetBalance;
        }

        if (amount > 0) {
            // Treasury fees
            uint256 treasuryFee = (amount * performanceTreasuryFee) /
                MAX_FEE_BPS;
            if (treasuryFee > 0) {
                IERC20(asset).safeTransfer(
                    IController(controller).treasury(),
                    treasuryFee
                );
                emit PerformanceTreasuryFeeCollected(treasuryFee);
            }

            // Performance fee
            uint256 devFee = (amount * performanceDevFee) / MAX_FEE_BPS;
            if (devFee > 0) {
                IERC20(asset).safeTransfer(
                    IController(controller).devfund(),
                    devFee
                );
                emit PerformanceDevFeeCollected(devFee);
            }

            deposit();
        }
    }
}
