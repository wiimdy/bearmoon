// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title Controller Interface
/// @notice Interface for the Controller contract which manages vaults and strategies
/// @dev Handles the relationship between assets, vaults, and their associated strategies
interface IController {
    // Errors
    /// @notice Thrown when a function is called with a zero address
    error ZeroAddress();
    /// @notice Thrown when a function is called by an address that isn't governance
    error NotGovernance();
    /// @notice Thrown when a function is called by an address that isn't timelock
    error NotTimelock();
    /// @notice Thrown when a function is called by an address that isn't strategist or governance
    error NotStrategist();
    /// @notice Thrown when a function is called by an address that isn't the vault
    error NotVault();
    /// @notice Thrown when a strategy is not found for an asset
    error StrategyNotFound();
    /// @notice Thrown when trying to set a vault for a asset that already has one
    error VaultAlreadySet();
    /// @notice Thrown when trying to use a strategy that hasn't been approved
    error StrategyNotApproved();
    /// @notice Thrown when trying to revoke the currently active strategy
    error CannotRevokeActiveStrategy();

    // Events
    /// @notice Emitted when the dev fund is updated
    event DevFundChanged(
        address indexed oldDevFund,
        address indexed newDevFund
    );
    /// @notice Emitted when the treasury is updated
    event TreasuryChanged(
        address indexed oldTreasury,
        address indexed newTreasury
    );
    /// @notice Emitted when the strategist is updated
    event StrategistChanged(
        address indexed oldStrategist,
        address indexed newStrategist
    );
    /// @notice Emitted when the governance is updated
    event GovernanceChanged(
        address indexed oldGovernance,
        address indexed newGovernance
    );
    /// @notice Emitted when the timelock is updated
    event TimelockChanged(
        address indexed oldTimelock,
        address indexed newTimelock
    );
    /// @notice Emitted when a vault is set for an asset
    event VaultSet(address indexed asset, address indexed vault);
    /// @notice Emitted when a strategy is approved for an asset
    event StrategyApproved(address indexed asset, address indexed strategy);
    /// @notice Emitted when a strategy is revoked for an asset
    event StrategyRevoked(address indexed asset, address indexed strategy);
    /// @notice Emitted when a strategy is set for an asset
    event StrategySet(address indexed asset, address indexed strategy);
    /// @notice Emitted when assets are earned
    event Earned(address indexed asset, uint256 amount);
    /// @notice Emitted when assets are withdrawn
    event Withdrawn(address indexed asset, uint256 amount);
    /// @notice Emitted when all assets are withdrawn
    event WithdrawnAll(address indexed asset);
    /// @notice Emitted when tokens are recovered
    event TokensRecovered(address indexed asset, uint256 amount);
    /// @notice Emitted when strategy tokens are recovered
    event StrategyTokensRecovered(
        address indexed strategy,
        address indexed asset
    );

    // Functions
    /// @notice View function to get the treasury address
    function treasury() external view returns (address);

    /// @notice View function to get the developer fund address
    function devfund() external view returns (address);

    /// @notice View function to get the strategist address
    function strategist() external view returns (address);

    /// @notice View function to get the governance address
    function governance() external view returns (address);

    /// @notice View function to get the timelock address
    function timelock() external view returns (address);

    /// @notice Maps asset addresses to their associated vault addresses
    function vaults(address) external view returns (address);

    /// @notice Maps asset addresses to their associated strategy addresses
    function strategies(address) external view returns (address);

    /// @notice Checks if a strategy is approved for a given asset
    function approvedStrategies(address, address) external view returns (bool);

    /// @notice Gets the balance of a asset in its strategy
    function balanceOf(address) external view returns (uint256);

    /// @notice Withdraws assets from a strategy
    function withdraw(address, uint256) external;

    /// @notice Moves assets from the controller to the strategy
    function earn(address, uint256) external;

    /// @notice Associates a vault with a asset
    function setVault(address asset, address vault) external;

    /// @notice Approves a strategy for a asset
    function approveStrategy(address asset, address strategy) external;

    /// @notice Revokes approval for a strategy
    function revokeStrategy(address asset, address strategy) external;

    /// @notice Sets the active strategy for a asset
    function setStrategy(address asset, address strategy) external;

    /// @notice Sets a new strategist address
    function setStrategist(address strategist) external;

    /// @notice Sets a new governance address
    function setGovernance(address governance) external;

    /// @notice Sets a new timelock address
    function setTimelock(address timelock) external;
}
