// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IDexType} from "./IDexType.sol";

interface ILpRouter is IDexType {
    /// @notice Thrown when router arrays have mismatched lengths
    error InvalidRouterLength();

    /// @notice Thrown when router address is zero
    error ZeroRouterAddress();

    /// @notice Thrown when address is zero
    error ZeroAddress();

    /// @notice Thrown when a function is called by an address that isn't governance
    error NotGovernance();

    /// @notice Thrown when total ratio is zero
    error TotalRatioZero();

    /// @notice Emitted when the governance is updated
    event GovernanceUpdated(
        address indexed oldGovernance,
        address indexed newGovernance
    );

    /// @notice Emitted when a router is set for a DEX
    /// @param dex The DEX index
    /// @param router The router address
    event SetRouter(uint8 dex, address indexed router);

    /// @notice Emitted when a swap router is set
    /// @param swapRouter The swap router address
    event SetSwapRouter(address indexed old, address indexed swapRouter);

    struct LiquidityAddInfo {
        address lp;
        address token0;
        address token1;
        uint256 amount0;
        uint256 amount1;
    }

    struct LiquidityRemoveInfo {
        address lp;
        uint256 lpAmount;
        address token0;
        address token1;
        address recipient;
    }

    function addLiquidity(
        address lp,
        address tokenIn,
        uint256 amountIn,
        address recipient,
        DexType dexType
    ) external returns (uint256 lpAmountOut);

    function removeLiquidity(
        address lp,
        uint256 lpAmount,
        address recipient,
        address tokenOut,
        DexType dexType
    ) external returns (uint256 tokenOutAmount);
}
