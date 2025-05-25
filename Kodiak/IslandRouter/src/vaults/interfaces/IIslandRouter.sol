// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.19;

import {IKodiakIsland} from "./IKodiakIsland.sol";
import {IWETH} from "./IWETH.sol";
struct RouterSwapParams {
    uint256 amountIn;
    uint256 minAmountOut;
    bool zeroForOne;
    bytes routeData;
}

interface IIslandRouter {
    function addLiquidity(
        IKodiakIsland island,
        uint256 amount0Max,
        uint256 amount1Max,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 amountSharesMin,
        address receiver
    ) external returns (uint256 amount0, uint256 amount1, uint256 mintAmount);

    function addLiquidityNative(
        IKodiakIsland island,
        uint256 amount0Max,
        uint256 amount1Max,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 amountSharesMin,
        address receiver
    ) external payable returns (uint256 amount0, uint256 amount1, uint256 mintAmount);

    function removeLiquidity(
        IKodiakIsland island,
        uint256 burnAmount,
        uint256 amount0Min,
        uint256 amount1Min,
        address receiver
    ) external returns (uint256 amount0, uint256 amount1, uint128 liquidityBurned);

    function removeLiquidityNative(
        IKodiakIsland island,
        uint256 burnAmount,
        uint256 amount0Min,
        uint256 amount1Min,
        address payable receiver
    ) external returns (uint256 amount0, uint256 amount1, uint128 liquidityBurned);

    function addLiquiditySingle(
        IKodiakIsland island,
        uint256 totalAmountIn,
        uint256 amountSharesMin,
        uint256 maxStakingSlippageBPS,
        RouterSwapParams calldata swapData,
        address receiver
    ) external returns (uint256 amount0, uint256 amount1, uint256 mintAmount);

    function addLiquiditySingleNative(
        IKodiakIsland island,
        uint256 amountSharesMin,
        uint256 maxStakingSlippageBPS,
        RouterSwapParams calldata swapData,
        address receiver
    ) external payable returns (uint256 amount0, uint256 amount1, uint256 mintAmount);

    function kodiakRouter() external view returns (address);

    function wBera() external view returns (IWETH);
}
