// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IDexType} from "./IDexType.sol";

import {IBeraPool} from "./exchange/Beraswap.sol";

/**
 * @title ISwapRouter
 * @notice Interface for the SwapRouter contract that handles token swaps across multiple DEXes
 */
interface ISwapRouter is IDexType {
    // Errors
    /// @notice Thrown when router arrays have mismatched lengths
    error InvalidRouterLength();
    /// @notice Thrown when router/factory arrays have mismatched lengths
    error InvalidFactoryLength();
    /// @notice Thrown when path length is less than 2
    error InvalidPathLength();
    /// @notice Thrown when address is zero
    error ZeroAddress();
    /// @notice Thrown when router address is zero
    error ZeroRouterAddress();
    /// @notice Thrown when trying to use an unsupported factory
    error FactoryNotSupported();
    /// @notice Thrown when trying to use an unsupported router
    error RouterNotSupported();
    /// @notice Thrown when no pool is found for a multihop swap
    error NoPoolFoundForMultihopSwap();
    /// @notice Thrown when no pool is found for a multihop quote
    error NoPoolFoundForMultihopQuote();
    /// @notice Thrown when output amount is less than minimum
    /// @param amountOut Actual output amount
    /// @param amountOutMinimum Minimum required output amount
    error InsufficientOutputAmount(uint256 amountOut, uint256 amountOutMinimum);
    /// @notice Thrown when amount is zero
    error ZeroAmount();
    /// @notice Thrown when a function is called by an address that isn't governance
    error NotGovernance();
    /// @notice Thrown when no swap route is found
    error NoSwapRouteFound();
    /// @notice Thrown when path length exceeds the maximum
    error PathLengthExceeded();
    /// @notice Thrown when no pool is found for a token pair
    error NoPoolFound();

    // Events
    /// @notice Emitted when the governance is updated
    event GovernanceUpdated(
        address indexed oldGovernance,
        address indexed newGovernance
    );
    /// @notice Emitted when a router is set for a DEX
    /// @param dex The DEX index
    /// @param router The router address
    event SetRouter(uint8 dex, address indexed router);
    /// @notice Emitted when a factory is set for a DEX
    /// @param dex The DEX index
    /// @param factory The factory address
    event SetFactory(uint8 dex, address indexed factory);
    /// @notice Emitted when a pool is set
    /// @param tokenIn The input token address
    /// @param tokenOut The output token address
    /// @param pool The pool address
    event SetPool(
        address indexed tokenIn,
        address indexed tokenOut,
        address pool
    );
    /// @notice Emitted when a swap route is set
    /// @param tokenIn The input token address
    /// @param tokenOut The output token address
    /// @param path The swap route path
    /// @param reversePath Whether to set the inverse swap route
    event SetSwapRoute(
        address indexed tokenIn,
        address indexed tokenOut,
        SwapRoutePath[] path,
        bool reversePath
    );

    /// @notice Struct for a swap route path
    /// @param tokenIn The input token address
    /// @param tokenOut The output token address
    /// @param dex The DEX type
    /// @param isMultiPath Whether the path is a multi-path swap
    /// @param pool The pool address
    struct SwapRoutePath {
        address tokenIn;
        address tokenOut;
        DexType dex;
        bool isMultiPath;
        address pool;
    }

    // Functions
    /// @notice Returns the wrapped native token address (e.g. WETH)
    /// @return The address of the wrapped native token
    function wrappedNative() external view returns (address);

    /// @notice Returns the router address for a given DEX
    /// @param dex The DEX index
    /// @return The router address
    function routers(uint8 dex) external view returns (address);

    /// @notice Returns the factory address for a given DEX
    /// @param dex The DEX index
    /// @return The factory address
    function factories(uint8 dex) external view returns (address);

    /// @notice Returns the default DEX type used for swaps
    /// @return The default DexType enum value
    function defaultDex() external view returns (DexType);

    /// @notice Swaps tokens using the default DEX
    /// @param tokenIn The input token address
    /// @param tokenOut The output token address
    /// @param amountIn The amount of input tokens
    /// @param amountOutMinimum The minimum amount of output tokens required
    /// @param recipient The address that will receive the output tokens
    /// @return amountOut The amount of output tokens received
    function swapWithDefaultDex(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address recipient
    ) external returns (uint256 amountOut);

    /// @notice Swaps tokens using a specified DEX
    /// @param tokenIn The input token address
    /// @param tokenOut The output token address
    /// @param amountIn The amount of input tokens
    /// @param amountOutMinimum The minimum amount of output tokens required
    /// @param recipient The address that will receive the output tokens
    /// @param dex The DEX to use for the swap
    /// @return amountOut The amount of output tokens received
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address recipient,
        DexType dex
    ) external returns (uint256 amountOut);

    /// @notice Performs a multi-hop swap using the default DEX
    /// @param path Array of token addresses representing the swap path
    /// @param amountIn The amount of input tokens
    /// @param amountOutMinimum The minimum amount of output tokens required
    /// @param recipient The address that will receive the output tokens
    /// @return amountOut The amount of output tokens received
    function swapWithPathWithDefaultDex(
        address[] calldata path,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address recipient
    ) external returns (uint256 amountOut);

    /// @notice Performs a multi-hop swap using a specified DEX
    /// @param path Array of token addresses representing the swap path
    /// @param amountIn The amount of input tokens
    /// @param amountOutMinimum The minimum amount of output tokens required
    /// @param recipient The address that will receive the output tokens
    /// @param dex The DEX to use for the swap
    /// @return amountOut The amount of output tokens received
    function swapWithPath(
        address[] calldata path,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address recipient,
        DexType dex
    ) external returns (uint256 amountOut);

    /// @notice Gets a quote for a swap using the default DEX
    /// @param tokenIn The input token address
    /// @param tokenOut The output token address
    /// @param amountIn The amount of input tokens
    /// @return amountOut The expected amount of output tokens
    function getQuoteWithDefaultDex(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external returns (uint256 amountOut);

    /// @notice Gets a quote for a swap using a specified DEX
    /// @param tokenIn The input token address
    /// @param tokenOut The output token address
    /// @param amountIn The amount of input tokens
    /// @param dex The DEX to use for the quote
    /// @return amountOut The expected amount of output tokens
    function getQuote(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        DexType dex
    ) external returns (uint256 amountOut);

    /// @notice Gets a quote for a multi-hop swap using the default DEX
    /// @param path Array of token addresses representing the swap path
    /// @param amountIn The amount of input tokens
    /// @return amountOut The expected amount of output tokens
    function getQuoteWithPathWithDefaultDex(
        address[] memory path,
        uint256 amountIn
    ) external view returns (uint256 amountOut);

    /// @notice Gets a quote for a multi-hop swap using a specified DEX
    /// @param path Array of token addresses representing the swap path
    /// @param amountIn The amount of input tokens
    /// @param dex The DEX to use for the quote
    /// @return amountOut The expected amount of output tokens
    function getQuoteWithPath(
        address[] memory path,
        uint256 amountIn,
        DexType dex
    ) external view returns (uint256 amountOut);
}
