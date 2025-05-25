// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.19;

import {IKodiakIsland} from "./IKodiakIsland.sol";

struct SwapData {
    address router;
    uint256 amountIn;
    uint256 minAmountOut;
    bool zeroForOne;
    bytes routeData;
}

interface IKodiakIslandWithRouter is IKodiakIsland {
    // Manager Functions
    function setRouter(address swapRouter, bool enabled) external;

    function executiveRebalanceWithRouter(int24 newLowerTick, int24 newUpperTick, SwapData calldata swapData) external;

    // View Functions
    function swapRouter(address router) external view returns (bool);

    function worstAmountOut(uint256 amountIn, uint16 slippageBPS, uint160 avgSqrtPriceX96, bool zeroForOne) external pure returns (uint256);

    function getAvgPrice(uint32 interval) external view returns (uint160 avgSqrtPriceX96);

}
