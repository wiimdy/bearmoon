// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/**
 * @title IVault
 * @notice Interface for Contrax Vault functionality
 */
interface IVault is IERC4626 {
    // Errors
    /// @notice Thrown when attempting to set a zero address
    error ZeroAddress();
    /// @notice Thrown when a caller is not the governance address
    error NotGovernance();
    /// @notice Thrown when a caller is not the timelock address
    error NotTimelock();
    /// @notice Thrown when a caller is not the controller address
    error NotController();
    /// @notice Thrown when attempting to set min ratio higher than max
    error MinGreaterThanMax();
    /// @notice Thrown when attempting to harvest the vault's underlying asset
    error CannotHarvestAsset();
    /// @notice Thrown when deposit results in fewer shares than minimum specified
    error InsufficientOutputShares(uint256 shares, uint256 minShares);
    /// @notice Thrown when redemption results in fewer assets than minimum specified
    error InsufficientOutputAssets(uint256 assets, uint256 minAssets);
    /// @notice Thrown when a fee is set that is greater than the maximum allowed
    error FeeTooHigh(uint16 fee, uint16 maxFee);
    /// @notice Thrown when there are no funds to earn
    error NoFundsToEarn();

    // Events
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
    /// @notice Emitted when the minimum ratio is updated
    /// @param oldMin The old minimum ratio
    /// @param newMin The new minimum ratio
    event MinChanged(uint256 oldMin, uint256 newMin);
    /// @notice Emitted when the deposit fee is updated
    /// @param oldFee The old deposit fee
    /// @param newFee The new deposit fee
    event DepositFeeChanged(uint16 oldFee, uint16 newFee);
    /// @notice Emitted when the withdraw fee is updated
    /// @param oldFee The old withdraw fee
    /// @param newFee The new withdraw fee
    event WithdrawFeeChanged(uint16 oldFee, uint16 newFee);

    // Functions
    /// @notice Sends available assets to controller to be invested in strategy
    function earn() external;

    /// @notice Calculates amount of assets available to be sent to strategy
    /// @return uint256 Amount of assets available
    function available() external view returns (uint256);

    /// @notice Deposits assets with minimum shares check
    /// @param assets Amount of assets to deposit
    /// @param receiver Address receiving the shares
    /// @param minShares Minimum shares that must be minted
    /// @return shares Amount of shares minted
    function deposit(
        uint256 assets,
        address receiver,
        uint256 minShares
    ) external returns (uint256 shares);

    /// @notice Redeems shares with minimum assets check
    /// @param shares Amount of shares to redeem
    /// @param receiver Address receiving the assets
    /// @param owner Address that owns the shares
    /// @param minAssets Minimum assets that must be returned
    /// @return assets Amount of assets returned
    function redeem(
        uint256 shares,
        address receiver,
        address owner,
        uint256 minAssets
    ) external returns (uint256 assets);
}
