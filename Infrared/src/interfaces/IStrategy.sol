// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Strategy Interface
/// @notice Interface for investment strategy contracts
/// @dev All strategies must implement these methods
interface IStrategy {
    // Errors
    /// @notice Thrown when a zero address is provided
    error ZeroAddress();
    /// @notice Thrown when caller is not authorized as benevolent (harvester, governance, or strategist)
    error NotBenevolent();
    /// @notice Thrown when caller is not the controller
    error NotController();
    /// @notice Thrown when caller is not the timelock
    error NotTimelock();
    /// @notice Thrown when caller is not governance
    error NotGovernance();
    /// @notice Thrown when trying to withdraw the strategy's main asset
    error CannotWithdrawAsset();
    /// @notice Thrown when vault address is not found for asset
    error VaultNotFound();
    /// @notice Thrown when target address for execute function is zero
    error InvalidTarget();
    /// @notice Thrown when trying to withdraw the strategy's main asset
    error InvalidAsset();
    /// @notice Thrown when vault address is zero
    error InvalidVault();
    /// @notice Thrown when ETH transfer is not allowed
    error EthTransferNotAllowed();
    /// @notice Thrown when fee is too high
    error FeeTooHigh(uint16 fee, uint16 maxFee);

    // Events
    /// @notice Emitted when harvest is called successfully
    /// @param timestamp Block timestamp when harvest occurred
    /// @param amount Amount of rewards harvested
    event Harvest(uint256 timestamp, uint256 amount);
    /// @notice Emitted when the strategist address is updated
    /// @param oldStrategist The old strategist address
    /// @param newStrategist The new strategist address
    event StrategistChanged(
        address indexed oldStrategist,
        address indexed newStrategist
    );
    /// @notice Emitted when the governance address is updated
    /// @param oldGovernance The old governance address
    /// @param newGovernance The new governance address
    event GovernanceChanged(
        address indexed oldGovernance,
        address indexed newGovernance
    );
    /// @notice Emitted when the timelock address is updated
    /// @param oldTimelock The old timelock address
    /// @param newTimelock The new timelock address
    event TimelockChanged(
        address indexed oldTimelock,
        address indexed newTimelock
    );
    /// @notice Emitted when the controller address is updated
    /// @param oldController The old controller address
    /// @param newController The new controller address
    event ControllerChanged(
        address indexed oldController,
        address indexed newController
    );
    /// @notice Emitted when a harvester is whitelisted
    /// @param harvester The address of the whitelisted harvester
    event HarvesterWhitelisted(address indexed harvester);
    /// @notice Emitted when a harvester is revoked
    /// @param harvester The address of the revoked harvester
    event HarvesterRevoked(address indexed harvester);
    /// @notice Emitted when the withdrawal dev fund fee is updated
    /// @param oldFee The old fee value
    /// @param newFee The new fee value
    event WithdrawalDevFundFeeChanged(uint16 oldFee, uint16 newFee);
    /// @notice Emitted when the withdrawal treasury fee is updated
    /// @param oldFee The old fee value
    /// @param newFee The new fee value
    event WithdrawalTreasuryFeeChanged(uint16 oldFee, uint16 newFee);
    /// @notice Emitted when the performance dev fund fee is updated
    /// @param oldFee The old fee value
    /// @param newFee The new fee value
    event PerformanceDevFeeChanged(uint16 oldFee, uint16 newFee);
    /// @notice Emitted when the performance treasury fee is updated
    /// @param oldFee The old fee value
    /// @param newFee The new fee value
    event PerformanceTreasuryFeeChanged(uint16 oldFee, uint16 newFee);
    /// @notice Emitted when the wrapped native token is updated
    /// @param oldWrappedNative The old wrapped native token address
    /// @param newWrappedNative The new wrapped native token address
    event WrappedNativeChanged(
        address indexed oldWrappedNative,
        address indexed newWrappedNative
    );
    /// @notice Emitted when the BGT token is updated
    /// @param oldBgt The old BGT token address
    /// @param newBgt The new BGT token address
    event BgtChanged(address indexed oldBgt, address indexed newBgt);
    /// @notice Emitted when the swap router is updated
    /// @param oldSwapRouter The old swap router address
    /// @param newSwapRouter The new swap router address
    event SwapRouterChanged(
        address indexed oldSwapRouter,
        address indexed newSwapRouter
    );
    /// @notice Emitted when the LP router is updated
    /// @param oldLpRouter The old LP router address
    /// @param newLpRouter The new LP router address
    event LpRouterChanged(
        address indexed oldLpRouter,
        address indexed newLpRouter
    );
    /// @notice Emitted when the zapper is updated
    /// @param oldZapper The old zapper address
    /// @param newZapper The new zapper address
    event ZapperChanged(address indexed oldZapper, address indexed newZapper);
    /// @notice Emitted when a fee is collected
    /// @param feeType The type of fee collected
    /// @param amount The amount of fee collected
    event FeeCollected(string feeType, uint256 amount);
    /// @notice Emitted when the withdrawal dev fund fee is collected
    /// @param amount The amount of fee collected
    event WithdrawalDevFundFeeCollected(uint256 amount);
    /// @notice Emitted when the withdrawal treasury fee is collected
    /// @param amount The amount of fee collected
    event WithdrawalTreasuryFeeCollected(uint256 amount);
    /// @notice Emitted when the performance dev fund fee is collected
    /// @param amount The amount of fee collected
    event PerformanceDevFeeCollected(uint256 amount);
    /// @notice Emitted when the performance treasury fee is collected
    /// @param amount The amount of fee collected
    event PerformanceTreasuryFeeCollected(uint256 amount);

    // Functions
    /// @notice Returns the asset token managed by this strategy
    function asset() external view returns (IERC20);

    /// @notice Returns the timelock address
    function timelock() external view returns (address);

    /// @notice Returns the governance address
    function governance() external view returns (address);

    /// @notice Returns the strategist address
    function strategist() external view returns (address);

    /// @notice Returns the controller address
    function controller() external view returns (address);

    /// @notice Deposits assets into yield generating platform
    function deposit() external;

    /// @notice Withdraws assets for strategy swap
    /// @param amount Amount to withdraw
    /// @return Amount actually withdrawn
    function withdrawForSwap(uint256 amount) external returns (uint256);

    /// @notice Withdraws assets back to vault
    /// @param amount Amount to withdraw
    function withdraw(uint256 amount) external;

    /// @notice Withdraws other tokens (not main asset)
    /// @param token Address of token to withdraw
    /// @return Amount withdrawn
    function withdraw(address token) external returns (uint256);

    /// @notice Withdraws all assets back to vault
    /// @return Amount withdrawn
    function withdrawAll() external returns (uint256);

    /// @notice Returns total balance of assets managed by strategy
    /// @return Total balance
    function balanceOf() external view returns (uint256);

    /// @notice Returns harvestable rewards info
    /// @return rewards Addresses of reward tokens
    /// @return amounts Amounts of rewards available
    function getHarvestable()
        external
        view
        returns (address[] memory rewards, uint256[] memory amounts);

    /// @notice Harvests and compounds rewards
    function harvest() external;

    /// @notice Sets new timelock address
    /// @param newTimelock Address of new timelock
    function setTimelock(address newTimelock) external;

    /// @notice Sets new controller address
    /// @param newController Address of new controller
    function setController(address newController) external;

    /// @notice Executes arbitrary function calls (for emergency use)
    /// @param target Address to call
    /// @param data Calldata to send
    /// @return response Return data from call
    function execute(
        address target,
        bytes calldata data
    ) external payable returns (bytes memory response);
}
