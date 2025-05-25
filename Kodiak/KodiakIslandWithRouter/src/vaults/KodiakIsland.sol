// SPDX-License-Identifier: GPL-3.0
//
// =========================== Kodiak Island =============================
// =======================================================================
// Modified from Arrakis (https://github.com/ArrakisFinance/vault-v1-core)
// Built for the Beras
// =======================================================================

pragma solidity =0.8.19;

import {IUniswapV3MintCallback} from "./interfaces/IUniswapV3MintCallback.sol";
import {IUniswapV3SwapCallback} from "./interfaces/IUniswapV3SwapCallback.sol";
import {KodiakIslandStorage} from "./abstract/KodiakIslandStorage.sol";
import {TickMath} from "./vendor/uniswap/TickMath.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {FullMath, LiquidityAmounts} from "./vendor/uniswap/LiquidityAmounts.sol";

abstract contract KodiakIsland is IUniswapV3MintCallback, IUniswapV3SwapCallback, KodiakIslandStorage {
    using SafeERC20 for IERC20;
    using TickMath for int24;

    event Minted(address receiver, uint256 mintAmount, uint256 amount0In, uint256 amount1In, uint128 liquidityMinted);

    event Burned(address receiver, uint256 burnAmount, uint256 amount0Out, uint256 amount1Out, uint128 liquidityBurned);

    event Rebalance(address indexed compounder, int24 lowerTick_, int24 upperTick_, uint128 liquidityBefore, uint128 liquidityAfter);

    event FeesEarned(uint256 feesEarned0, uint256 feesEarned1);

    /// @notice Uniswap V3 callback fn, called back on pool.mint
    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata /*_data*/ ) external override {
        require(msg.sender == address(pool), "callback caller");

        if (amount0Owed > 0) token0.safeTransfer(msg.sender, amount0Owed);
        if (amount1Owed > 0) token1.safeTransfer(msg.sender, amount1Owed);
    }

    /// @notice Uniswap v3 callback fn, called back on pool.swap
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata /*data*/ ) external override {
        require(msg.sender == address(pool), "callback caller");

        if (amount0Delta > 0) {
            token0.safeTransfer(msg.sender, uint256(amount0Delta));
        } else if (amount1Delta > 0) {
            token1.safeTransfer(msg.sender, uint256(amount1Delta));
        }
    }

    // User functions => Should be called via a Router

    /// @notice mint KodiakIsland tokens, fractional shares of a Uniswap V3 position/strategy
    /// @dev to compute the amouint of tokens necessary to mint `mintAmount` see getMintAmounts
    /// @param mintAmount The number of shares to mint
    /// @param receiver The account to receive the minted shares
    /// @return amount0 amount of token0 transferred from msg.sender to mint `mintAmount`
    /// @return amount1 amount of token1 transferred from msg.sender to mint `mintAmount`
    /// @return liquidityMinted amount of liquidity added to the underlying Uniswap V3 position
    function mint(uint256 mintAmount, address receiver) external whenNotPaused nonReentrant returns (uint256 amount0, uint256 amount1, uint128 liquidityMinted) {
        require(!restrictedMint || msg.sender == _manager || !isManaged(), "restricted");

        uint256 totalSupply = totalSupply();

        (uint160 sqrtRatioX96,,,,,,) = pool.slot0();

        if (totalSupply > 0) {
            require(mintAmount > 0, "mint 0");
            (uint256 amount0Current, uint256 amount1Current) = getUnderlyingBalances();

            amount0 = FullMath.mulDivRoundingUp(amount0Current, mintAmount, totalSupply);
            amount1 = FullMath.mulDivRoundingUp(amount1Current, mintAmount, totalSupply);
        } else {
            // if supply is 0 mintAmount == liquidity to deposit
            (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(sqrtRatioX96, lowerTick.getSqrtRatioAtTick(), upperTick.getSqrtRatioAtTick(), SafeCast.toUint128(mintAmount));

            _mint(address(0), INITIAL_MINT); // Solution to this issue: https://github.com/transmissions11/solmate/issues/178
            mintAmount = mintAmount - INITIAL_MINT;
        }

        // transfer amounts owed to contract
        if (amount0 > 0) {
            token0.safeTransferFrom(msg.sender, address(this), amount0);
        }
        if (amount1 > 0) {
            token1.safeTransferFrom(msg.sender, address(this), amount1);
        }

        // deposit as much new liquidity as possible
        liquidityMinted = LiquidityAmounts.getLiquidityForAmounts(sqrtRatioX96, lowerTick.getSqrtRatioAtTick(), upperTick.getSqrtRatioAtTick(), amount0, amount1);

        pool.mint(address(this), lowerTick, upperTick, liquidityMinted, "");

        _mint(receiver, mintAmount);
        emit Minted(receiver, mintAmount, amount0, amount1, liquidityMinted);
    }

    /// @notice burn KodiakIsland tokens (shares of a Uniswap V3 position) and receive underlying
    /// @param burnAmount The number of shares to burn
    /// @param receiver The account to receive the underlying amounts of token0 and token1
    /// @return amount0 amount of token0 transferred to receiver for burning `burnAmount`
    /// @return amount1 amount of token1 transferred to receiver for burning `burnAmount`
    /// @return liquidityBurned amount of liquidity removed from the underlying Uniswap V3 position
    function burn(uint256 burnAmount, address receiver) external whenNotPaused nonReentrant returns (uint256 amount0, uint256 amount1, uint128 liquidityBurned) {
        require(burnAmount > 0, "burn 0");

        uint256 totalSupply = totalSupply();

        (uint128 liquidity,,,,) = pool.positions(_getPositionID());

        _burn(msg.sender, burnAmount);

        uint256 liquidityBurned_ = FullMath.mulDiv(burnAmount, liquidity, totalSupply);
        liquidityBurned = SafeCast.toUint128(liquidityBurned_);
        (uint256 burn0, uint256 burn1, uint256 fee0, uint256 fee1) = _withdraw(lowerTick, upperTick, liquidityBurned);
        _applyFees(fee0, fee1);

        amount0 = burn0 + FullMath.mulDiv(token0.balanceOf(address(this)) - burn0 - managerBalance0, burnAmount, totalSupply);
        amount1 = burn1 + FullMath.mulDiv(token1.balanceOf(address(this)) - burn1 - managerBalance1, burnAmount, totalSupply);

        if (amount0 > 0) {
            token0.safeTransfer(receiver, amount0);
        }

        if (amount1 > 0) {
            token1.safeTransfer(receiver, amount1);
        }

        emit Burned(receiver, burnAmount, amount0, amount1, liquidityBurned);
    }

    // Manager Functions => Called by Island Manager

    /// @notice Change the range of underlying UniswapV3 position, only manager can call
    /// @dev When changing the range the inventory of token0 and token1 may be rebalanced
    /// with a swap to deposit as much liquidity as possible into the new position. Swap parameters
    /// can be computed by simulating the whole operation: remove all liquidity, deposit as much
    /// as possible into new position, then observe how much of token0 or token1 is leftover.
    /// Swap a proportion of this leftover to deposit more liquidity into the position, since
    /// any leftover will be unused and sit idle until the next rebalance.
    /// @param newLowerTick The new lower bound of the position's range
    /// @param newUpperTick The new upper bound of the position's range
    /// @param swapThresholdPrice slippage parameter on the swap as a max or min sqrtPriceX96
    /// @param swapAmountBPS amount of token to swap as proportion of total. Pass 0 to ignore swap.
    /// @param zeroForOne Which token to input into the swap (true = token0, false = token1)
    function executiveRebalance(int24 newLowerTick, int24 newUpperTick, uint160 swapThresholdPrice, uint256 swapAmountBPS, bool zeroForOne) external whenNotPaused onlyManager {
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

            _deposit(newLowerTick, newUpperTick, reinvest0, reinvest1, swapThresholdPrice, swapAmountBPS, zeroForOne);

            (newLiquidity,,,,) = pool.positions(_getPositionID());
            require(newLiquidity > 0, "new position 0");
        } else {
            lowerTick = newLowerTick;
            upperTick = newUpperTick;
        }

        emit Rebalance(msg.sender, newLowerTick, newUpperTick, liquidity, newLiquidity);
    }

    // CompounderOrAbove functions => Limited-scope automated functions

    /// @notice Reinvest fees earned into underlying position, anyone call
    /// Position bounds CANNOT be altered, and no swaps occur (fee balance can remain idle)
    function rebalance() external whenNotPaused {
        (uint128 liquidity,,,,) = pool.positions(_getPositionID());
        _rebalance();

        (uint128 newLiquidity,,,,) = pool.positions(_getPositionID());
        require(newLiquidity > liquidity, "liquidity must increase");

        emit Rebalance(msg.sender, lowerTick, upperTick, liquidity, newLiquidity);
    }

    /// @notice withdraw manager fees accrued
    function withdrawManagerBalance() external {
        uint256 amount0 = managerBalance0;
        uint256 amount1 = managerBalance1;

        managerBalance0 = 0;
        managerBalance1 = 0;

        if (amount0 > 0) {
            token0.safeTransfer(managerTreasury, amount0);
        }

        if (amount1 > 0) {
            token1.safeTransfer(managerTreasury, amount1);
        }
    }

    // View functions

    /// @notice compute maximum shares that can be minted from `amount0Max` and `amount1Max`
    /// @param amount0Max The maximum amount of token0 to forward on mint
    /// @param amount0Max The maximum amount of token1 to forward on mint
    /// @return amount0 actual amount of token0 to forward when minting `mintAmount`
    /// @return amount1 actual amount of token1 to forward when minting `mintAmount`
    /// @return mintAmount maximum number of shares mintable
    function getMintAmounts(uint256 amount0Max, uint256 amount1Max) external view returns (uint256 amount0, uint256 amount1, uint256 mintAmount) {
        uint256 totalSupply = totalSupply();
        if (totalSupply > 0) {
            (amount0, amount1, mintAmount) = _computeMintAmounts(totalSupply, amount0Max, amount1Max);
        } else {
            (uint160 sqrtRatioX96,,,,,,) = pool.slot0();
            uint128 newLiquidity = LiquidityAmounts.getLiquidityForAmounts(sqrtRatioX96, lowerTick.getSqrtRatioAtTick(), upperTick.getSqrtRatioAtTick(), amount0Max, amount1Max);
            mintAmount = uint256(newLiquidity);
            (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(sqrtRatioX96, lowerTick.getSqrtRatioAtTick(), upperTick.getSqrtRatioAtTick(), newLiquidity);
        }
    }

    /// @notice compute total underlying holdings of the island token supply
    /// includes current liquidity invested in uniswap position, current fees earned
    /// and any uninvested leftover (but does not include manager fees accrued)
    /// @return amount0Current current total underlying balance of token0
    /// @return amount1Current current total underlying balance of token1
    function getUnderlyingBalances() public view returns (uint256 amount0Current, uint256 amount1Current) {
        (uint160 sqrtRatioX96, int24 tick,,,,,) = pool.slot0();
        return _getUnderlyingBalances(sqrtRatioX96, tick);
    }

    function getUnderlyingBalancesAtPrice(uint160 sqrtRatioX96) external view returns (uint256 amount0Current, uint256 amount1Current) {
        (, int24 tick,,,,,) = pool.slot0();
        return _getUnderlyingBalances(sqrtRatioX96, tick);
    }

    function _getUnderlyingBalances(uint160 sqrtRatioX96, int24 tick) internal view returns (uint256 amount0Current, uint256 amount1Current) {
        (uint128 liquidity, uint256 feeGrowthInside0Last, uint256 feeGrowthInside1Last, uint128 tokensOwed0, uint128 tokensOwed1) = pool.positions(_getPositionID());

        // compute current holdings from liquidity
        (amount0Current, amount1Current) = LiquidityAmounts.getAmountsForLiquidity(sqrtRatioX96, lowerTick.getSqrtRatioAtTick(), upperTick.getSqrtRatioAtTick(), liquidity);

        // compute current fees earned
        uint256 fee0 = _computeFeesEarned(true, feeGrowthInside0Last, tick, liquidity) + uint256(tokensOwed0);
        uint256 fee1 = _computeFeesEarned(false, feeGrowthInside1Last, tick, liquidity) + uint256(tokensOwed1);

        (fee0, fee1) = _subtractManagerFee(fee0, fee1, managerFeeBPS);

        // add any leftover in contract to current holdings
        amount0Current += fee0 + token0.balanceOf(address(this)) - managerBalance0;
        amount1Current += fee1 + token1.balanceOf(address(this)) - managerBalance1;
    }

    // Private functions

    function _rebalance() private {
        (int24 _lowerTick, int24 _upperTick) = (lowerTick, upperTick);

        (,, uint256 fee0, uint256 fee1) = _withdraw(_lowerTick, _upperTick, 0); //withdraw of 0 since range is the same
        _applyFees(fee0, fee1);

        uint256 reinvest0 = token0.balanceOf(address(this)) - managerBalance0;
        uint256 reinvest1 = token1.balanceOf(address(this)) - managerBalance1;

        _mintMaxLiquidity(_lowerTick, _upperTick, reinvest0, reinvest1);
    }

    function _withdraw(int24 lowerTick_, int24 upperTick_, uint128 liquidity) internal returns (uint256 burn0, uint256 burn1, uint256 fee0, uint256 fee1) {
        (burn0, burn1) = pool.burn(lowerTick_, upperTick_, liquidity);
        (uint128 collected0, uint128 collected1) = pool.collect(address(this), lowerTick_, upperTick_, type(uint128).max, type(uint128).max);
        fee0 = uint256(collected0) - burn0;
        fee1 = uint256(collected1) - burn1;
    }

    function _deposit(int24 lowerTick_, int24 upperTick_, uint256 amount0, uint256 amount1, uint160 swapThresholdPrice, uint256 swapAmountBPS, bool zeroForOne) private {
        // First, deposit as much as we can
        (amount0, amount1) = _mintMaxLiquidity(lowerTick_, upperTick_, amount0, amount1);

        int256 swapAmount = SafeCast.toInt256(((zeroForOne ? amount0 : amount1) * swapAmountBPS) / 10000);
        if (swapAmount > 0) {
            (amount0, amount1) = _swap(amount0, amount1, swapAmount, swapThresholdPrice, zeroForOne);

            //Add liquidity a second time
            _mintMaxLiquidity(lowerTick_, upperTick_, amount0, amount1);
        }
    }

    function _swap(uint256 amount0, uint256 amount1, int256 swapAmount, uint160 swapThresholdPrice, bool zeroForOne) private returns (uint256 finalAmount0, uint256 finalAmount1) {
        (int256 amount0Delta, int256 amount1Delta) = pool.swap(address(this), zeroForOne, swapAmount, swapThresholdPrice, "");
        finalAmount0 = uint256(SafeCast.toInt256(amount0) - amount0Delta);
        finalAmount1 = uint256(SafeCast.toInt256(amount1) - amount1Delta);
    }

    function _mintMaxLiquidity(int24 lowerTick_, int24 upperTick_, uint256 maxAmount0, uint256 maxAmount1) internal returns (uint256 amount0, uint256 amount1) {
        (uint160 sqrtRatioX96,,,,,,) = pool.slot0();
        uint128 liquidityMinted = LiquidityAmounts.getLiquidityForAmounts(sqrtRatioX96, lowerTick_.getSqrtRatioAtTick(), upperTick_.getSqrtRatioAtTick(), maxAmount0, maxAmount1);
        if (liquidityMinted > 0) {
            (uint256 deposited0, uint256 deposited1) = pool.mint(address(this), lowerTick_, upperTick_, liquidityMinted, "");
            amount0 = maxAmount0 - deposited0;
            amount1 = maxAmount1 - deposited1;
        }
    }

    function _computeMintAmounts(uint256 totalSupply, uint256 amount0Max, uint256 amount1Max) private view returns (uint256 amount0, uint256 amount1, uint256 mintAmount) {
        (uint256 amount0Current, uint256 amount1Current) = getUnderlyingBalances();

        // compute proportional amount of tokens to mint
        if (amount0Current == 0 && amount1Current > 0) {
            mintAmount = FullMath.mulDiv(amount1Max, totalSupply, amount1Current);
        } else if (amount1Current == 0 && amount0Current > 0) {
            mintAmount = FullMath.mulDiv(amount0Max, totalSupply, amount0Current);
        } else if (amount0Current == 0 && amount1Current == 0) {
            revert("");
        } else {
            // only if both are non-zero
            uint256 amount0Mint = FullMath.mulDiv(amount0Max, totalSupply, amount0Current);
            uint256 amount1Mint = FullMath.mulDiv(amount1Max, totalSupply, amount1Current);
            require(amount0Mint > 0 && amount1Mint > 0, "mint 0");

            mintAmount = amount0Mint < amount1Mint ? amount0Mint : amount1Mint;
        }

        // compute amounts owed to contract
        amount0 = FullMath.mulDivRoundingUp(mintAmount, amount0Current, totalSupply);
        amount1 = FullMath.mulDivRoundingUp(mintAmount, amount1Current, totalSupply);
    }

    function _computeFeesEarned(bool isZero, uint256 feeGrowthInsideLast, int24 tick, uint128 liquidity) private view returns (uint256 fee) {
        uint256 feeGrowthOutsideLower;
        uint256 feeGrowthOutsideUpper;
        uint256 feeGrowthGlobal;
        if (isZero) {
            feeGrowthGlobal = pool.feeGrowthGlobal0X128();
            (,, feeGrowthOutsideLower,,,,,) = pool.ticks(lowerTick);
            (,, feeGrowthOutsideUpper,,,,,) = pool.ticks(upperTick);
        } else {
            feeGrowthGlobal = pool.feeGrowthGlobal1X128();
            (,,, feeGrowthOutsideLower,,,,) = pool.ticks(lowerTick);
            (,,, feeGrowthOutsideUpper,,,,) = pool.ticks(upperTick);
        }

        unchecked {
            // calculate fee growth below
            uint256 feeGrowthBelow;
            if (tick >= lowerTick) {
                feeGrowthBelow = feeGrowthOutsideLower;
            } else {
                feeGrowthBelow = feeGrowthGlobal - feeGrowthOutsideLower;
            }

            // calculate fee growth above
            uint256 feeGrowthAbove;
            if (tick < upperTick) {
                feeGrowthAbove = feeGrowthOutsideUpper;
            } else {
                feeGrowthAbove = feeGrowthGlobal - feeGrowthOutsideUpper;
            }

            uint256 feeGrowthInside = feeGrowthGlobal - feeGrowthBelow - feeGrowthAbove;
            fee = FullMath.mulDiv(liquidity, feeGrowthInside - feeGrowthInsideLast, 0x100000000000000000000000000000000);
        }
    }

    function _applyFees(uint256 _fee0, uint256 _fee1) internal {
        uint16 _managerFeeBPS = managerFeeBPS;

        if (managerFeeBPS > 0) {
            managerBalance0 += _fee0 * _managerFeeBPS / 10000;
            managerBalance1 += _fee1 * _managerFeeBPS / 10000;
            (uint256 fee0, uint256 fee1) = _subtractManagerFee(_fee0, _fee1, _managerFeeBPS);
            emit FeesEarned(fee0, fee1);
        } else {
            emit FeesEarned(_fee0, _fee1);
        }
    }

    function _subtractManagerFee(uint256 _fee0, uint256 _fee1, uint16 _managerFeeBPS) internal pure returns (uint256 fee0, uint256 fee1) {
        fee0 = _fee0 - _fee0 * _managerFeeBPS / 10000;
        fee1 = _fee1 - _fee1 * _managerFeeBPS / 10000;
    }
}
