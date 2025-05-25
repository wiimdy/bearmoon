// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.19;

import {SwapData} from "./interfaces/IKodiakIslandWithRouter.sol";
import "./KodiakIsland.sol";

contract KodiakIslandWithRouter is KodiakIsland {
    using FullMath for uint256;
    using SafeERC20 for IERC20;
    using TickMath for int24;

    mapping(address => bool) public swapRouter;

    event RouterSet(address indexed router, bool status);

    // ******************************************** Manager Functions *******************************************************

    /// @notice allows manager to add / remove routers, can do while paused
    /// @param _router address that can be used for rebalance
    /// @param _status true to add, false to remove
    function setRouter(address _router, bool _status) external onlyManager {
        require(_router != address(0), "Zero address");
        swapRouter[_router] = _status;
        emit RouterSet(_router, _status);
    }

    /// @notice Similar to executiveRebalance, but uses whitelisted router to facilitate swaps
    /// @param newLowerTick The new lower bound of the position's range
    /// @param newUpperTick The new upper bound of the position's range
    /// @param swapData swap information including: router address, amountIn, amountOutMin, zeroForOne, routeData
    function executiveRebalanceWithRouter(int24 newLowerTick, int24 newUpperTick, SwapData calldata swapData) external whenNotPaused onlyManager {
        require(swapRouter[swapData.router], "Unauthorized router");
        {
            uint256 worstOut = worstAmountOut(swapData.amountIn, compounderSlippageBPS, getAvgPrice(compounderSlippageInterval), swapData.zeroForOne);
            require(swapData.minAmountOut > worstOut, "Set reasonable minAmountOut");
        }

        uint128 liquidity;
        uint128 newLiquidity;

        if (totalSupply() > 0) {
            (liquidity,,,,) = pool.positions(_getPositionID());
            if (liquidity > 0) {
                (,, uint256 fee0, uint256 fee1) = _withdraw(lowerTick, upperTick, liquidity);
                _applyFees(fee0, fee1);
            }

            lowerTick = newLowerTick;
            upperTick = newUpperTick;

            uint256 reinvest0 = token0.balanceOf(address(this)) - managerBalance0;
            uint256 reinvest1 = token1.balanceOf(address(this)) - managerBalance1;

            _depositWithRouter(newLowerTick, newUpperTick, reinvest0, reinvest1, swapData);

            (newLiquidity,,,,) = pool.positions(_getPositionID());
            require(newLiquidity > 0, "new position 0");
        } else {
            lowerTick = newLowerTick;
            upperTick = newUpperTick;
        }

        emit Rebalance(msg.sender, newLowerTick, newUpperTick, liquidity, newLiquidity);
    }

    // ******************************************** View Functions *******************************************************

    function worstAmountOut(uint256 amountIn, uint16 slippageBPS, uint160 avgSqrtPriceX96, bool zeroForOne) public pure returns (uint256) {
        require(slippageBPS <= 10000, "Invalid slippage");
        // Calculate slippage adjustment to the sqrtPriceX96
        uint256 slippage = uint256(avgSqrtPriceX96) * slippageBPS / 10000;

        uint256 sqrtX96 = zeroForOne ? avgSqrtPriceX96 - slippage : avgSqrtPriceX96 + slippage;

        if (sqrtX96 == 0) {
            return 0;
        }

        //Somewhat hacky to avoid overflow issues
        if (zeroForOne) {
            if (sqrtX96 < 2 ** 128 - 1) {
                return amountIn.mulDiv(sqrtX96 ** 2, Q96 ** 2);
            } else {
                return amountIn.mulDiv(sqrtX96, Q96).mulDiv(sqrtX96, Q96);
            }
        } else {
            if (sqrtX96 < 2 ** 128 - 1) {
                return amountIn.mulDiv(Q96 ** 2, sqrtX96 ** 2);
            } else {
                return amountIn.mulDiv(Q96, 1e18).mulDiv(Q96, sqrtX96).mulDiv(1e18, sqrtX96);
            }
        }
    }

    /// @notice get the twap price of the underlying for the specified interval (in seconds)
    function getAvgPrice(uint32 interval) public view returns (uint160 avgSqrtPriceX96) {
        require(interval > 0, "Invalid interval");
        uint32[] memory secondsAgo = new uint32[](2);
        secondsAgo[0] = interval;
        secondsAgo[1] = 0;
        (int56[] memory tickCumulatives,) = pool.observe(secondsAgo);
        require(tickCumulatives.length == 2, "array len");
        unchecked {
            int24 avgTick = int24((tickCumulatives[1] - tickCumulatives[0]) / int56(uint56(interval)));
            avgSqrtPriceX96 = avgTick.getSqrtRatioAtTick();
        }
    }

    // ******************************************** Internal Functions *******************************************************
    function _depositWithRouter(int24 lowerTick_, int24 upperTick_, uint256 amount0, uint256 amount1, SwapData calldata swapData) private {
        // First, deposit as much as we can
        (amount0, amount1) = _mintMaxLiquidity(lowerTick_, upperTick_, amount0, amount1);

        if (swapData.amountIn > 0) {
            require(swapData.amountIn <= (swapData.zeroForOne ? amount0 : amount1), "Swap amount too big");
            (amount0, amount1) = _swapWithRouter(amount0, amount1, swapData);

            //Add liquidity a second time
            _mintMaxLiquidity(lowerTick_, upperTick_, amount0, amount1);
        }
    }

    /// @dev assumes that the router whitelist check has already passed.
    /// Swap using one of the approved routers.
    /// Returns the new token0 and token1 amounts in possession after the swap.
    function _swapWithRouter(uint256 amount0, uint256 amount1, SwapData calldata swapData) internal returns (uint256 finalAmount0, uint256 finalAmount1) {
        IERC20 tokenIn = swapData.zeroForOne ? token0 : token1;
        IERC20 tokenOut = swapData.zeroForOne ? token1 : token0;

        // Capture initial balances
        uint256 balanceIn = tokenIn.balanceOf(address(this));
        uint256 balanceOut = tokenOut.balanceOf(address(this));

        // Approve and perform swap
        tokenIn.safeIncreaseAllowance(swapData.router, swapData.amountIn);
        (bool success,) = swapData.router.call(swapData.routeData);
        require(success, "swap failed");

        // Calculate balance changes and ensure minimum output
        uint256 deltaIn = balanceIn - tokenIn.balanceOf(address(this));
        uint256 deltaOut = tokenOut.balanceOf(address(this)) - balanceOut;
        require(deltaOut >= swapData.minAmountOut, "insufficient tokenOut");

        // Set final amounts based on swap direction
        if (swapData.zeroForOne) {
            finalAmount0 = amount0 - deltaIn;
            finalAmount1 = amount1 + deltaOut;
        } else {
            finalAmount0 = amount0 + deltaOut;
            finalAmount1 = amount1 - deltaIn;
        }
    }
}
