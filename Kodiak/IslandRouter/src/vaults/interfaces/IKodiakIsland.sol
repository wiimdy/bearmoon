// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.19;
import {IERC20} from "@openzeppelin-8/contracts/interfaces/IERC20.sol";
import {IUniswapV3Pool} from "./IUniswapV3Pool.sol";

interface IKodiakIsland {
    function mint(uint256 mintAmount, address receiver) external returns (uint256 amount0, uint256 amount1, uint128 liquidityMinted);
    function burn(uint256 burnAmount, address receiver) external returns (uint256 amount0, uint256 amount1, uint128 liquidityBurned);
    function getMintAmounts(uint256 amount0Max, uint256 amount1Max) external view returns (uint256 amount0, uint256 amount1, uint256 mintAmount);
    function token0() external view returns (IERC20);
    function token1() external view returns (IERC20);
    function getUnderlyingBalances() external view returns (uint256 amount0, uint256 amount1);
    // Additional view functions that might be useful to expose:
    function totalSupply() external view returns (uint256);
    function pool() external view returns (IUniswapV3Pool);
    function lowerTick() external view returns (int24);
    function upperTick() external view returns (int24);
    function managerFeeBPS() external view returns (uint16);
    function managerBalance0() external view returns (uint256);
    function managerBalance1() external view returns (uint256);
    function managerTreasury() external view returns (address);
    function compounderSlippageInterval() external view returns (uint32);
    function compounderSlippageBPS() external view returns (uint16);
}
