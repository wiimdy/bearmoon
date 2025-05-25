// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.19;

import {IIslandRouter, RouterSwapParams} from "./interfaces/IIslandRouter.sol";
import {IKodiakIsland} from "./interfaces/IKodiakIsland.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {IERC20, SafeERC20} from "@openzeppelin-8/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin-8/contracts/utils/Address.sol";

contract IslandRouter is IIslandRouter {
    using Address for address payable;
    using SafeERC20 for IERC20;

    IWETH public immutable wBera;
    address public immutable kodiakRouter;

    constructor(IWETH _wBera, address _kodiakRouter) {
        wBera = _wBera;
        kodiakRouter = _kodiakRouter;
    }

    /// @notice addLiquidity adds liquidity to KodiakIsland of interest (mints Island tokens)
    /// @param island address of KodiakIsland to add liquidity to
    /// @param amount0Max the maximum amount of token0 msg.sender willing to input
    /// @param amount1Max the maximum amount of token1 msg.sender willing to input
    /// @param amount0Min the minimum amount of token0 actually input (slippage protection)
    /// @param amount1Min the minimum amount of token1 actually input (slippage protection)
    /// @param amountSharesMin the minimum amount of shares minted (slippage protection)
    /// @param receiver account to receive minted KodiakIsland tokens
    /// @return amount0 amount of token0 transferred from msg.sender to mint `mintAmount`
    /// @return amount1 amount of token1 transferred from msg.sender to mint `mintAmount`
    /// @return mintAmount amount of KodiakIsland tokens minted and transferred to `receiver`
    function addLiquidity(
        IKodiakIsland island,
        uint256 amount0Max,
        uint256 amount1Max,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 amountSharesMin,
        address receiver
    ) external override returns (uint256 amount0, uint256 amount1, uint256 mintAmount) {
        return _addLiquidity(island, amount0Max, amount1Max, amount0Min, amount1Min, amountSharesMin, receiver);
    }

    /// @notice addLiquidityNative same as addLiquidity but expects Bera transfers (instead of Wbera)
    function addLiquidityNative(
        IKodiakIsland island,
        uint256 amount0Max,
        uint256 amount1Max,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 amountSharesMin,
        address receiver
    ) external payable override returns (uint256 amount0, uint256 amount1, uint256 mintAmount) {
        return _addLiquidityNative(island, amount0Max, amount1Max, amount0Min, amount1Min, amountSharesMin, receiver);
    }

    /// @notice addLiquiditySingleNative adds liquidity to KodiakIsland with native token. Native token is wrapped and swapped for the other token. Returns unused wBera as native token back to msg.sender
    /// @param island address of KodiakIsland to add liquidity. One of the underlying island tokens must be wBera
    /// @param amountSharesMin the minimum amount of shares minted (slippage protection)
    /// @param maxStakingSlippageBPS the maximum slippage allowed for staking (in BPS)
    /// @param swapData the swap data for swapping wBera for token0 or token1
    /// @param receiver account to receive minted KodiakIsland tokens
    /// @return amount0 - amount of token0 transferred from msg.sender to mint `mintAmount`
    /// @return amount1 - amount of token1 transferred from msg.sender to mint `mintAmount`
    /// @return mintAmount - amount of KodiakIsland tokens minted and transferred to `receiver`
    function addLiquiditySingleNative(
        IKodiakIsland island,
        uint256 amountSharesMin,
        uint256 maxStakingSlippageBPS,
        RouterSwapParams calldata swapData,
        address receiver
    ) external payable override returns (uint256 amount0, uint256 amount1, uint256 mintAmount) {
        require(maxStakingSlippageBPS <= 10000, "staking slippage too high");
        wBera.deposit{value: msg.value}();
        IERC20 token0 = island.token0();
        IERC20 token1 = island.token1();

        // This also verifies that one of the tokens is wBera
        bool __isToken0WBera = _isToken0WBera(address(token0), address(token1));

        (uint256 token0Balance, uint256 token1Balance) = _swapAndVerify(token0, token1, IERC20(address(wBera)), swapData);

        (amount0, amount1, mintAmount) = island.getMintAmounts(token0Balance, token1Balance);
        require(mintAmount >= amountSharesMin, "Staking: below min share amount");

        token0Balance -= amount0;
        token1Balance -= amount1;

        if (__isToken0WBera) {
            require(amount1 >= (token1Balance + amount1) * (10000 - maxStakingSlippageBPS) / 10000, "Staking Slippage: below min amounts");
            _deposit(island, amount0, amount1, mintAmount, receiver);
            if (token0Balance > 0) {
                wBera.withdraw(token0Balance);
                payable(msg.sender).sendValue(token0Balance);
            }
            if (token1Balance > 0) token1.safeTransfer(msg.sender, token1Balance);
        } else {
            require(amount0 >= (token0Balance + amount0) * (10000 - maxStakingSlippageBPS) / 10000, "Staking Slippage: below min amounts");
            _deposit(island, amount0, amount1, mintAmount, receiver);
            if (token1Balance > 0) {
                wBera.withdraw(token1Balance);
                payable(msg.sender).sendValue(token1Balance);
            }
            if (token0Balance > 0) token0.safeTransfer(msg.sender, token0Balance);
        }
    }

    /// @notice addLiquiditySingle adds liquidity to KodiakIsland with one of the underlying Island tokens. Tokens are swapped for the other token to deposit into the island
    /// @param island address of KodiakIsland to add liquidity
    /// @param totalAmountIn the total amount of tokenIn transferred from msg.sender
    /// @param amountSharesMin the minimum amount of shares minted (slippage protection)
    /// @param maxStakingSlippageBPS the maximum slippage allowed for staking (in BPS)
    /// @param swapData the swap data for swapping tokenIn for token0 or token1
    /// @param receiver account to receive minted KodiakIsland tokens
    /// @return amount0 - amount of token0 transferred from msg.sender to mint `mintAmount`
    /// @return amount1 - amount of token1 transferred from msg.sender to mint `mintAmount`
    /// @return mintAmount - amount of KodiakIsland tokens minted and transferred to `receiver`
    function addLiquiditySingle(
        IKodiakIsland island,
        uint256 totalAmountIn,
        uint256 amountSharesMin,
        uint256 maxStakingSlippageBPS,
        RouterSwapParams calldata swapData,
        address receiver
    ) external override returns (uint256 amount0, uint256 amount1, uint256 mintAmount) {
        require(maxStakingSlippageBPS <= 10000, "staking slippage too high");
        IERC20 token0 = island.token0();
        IERC20 token1 = island.token1();
        IERC20 tokenIn = swapData.zeroForOne ? token0 : token1;
        tokenIn.safeTransferFrom(msg.sender, address(this), totalAmountIn);
        (uint256 token0Balance, uint256 token1Balance) = _swapAndVerify(token0, token1, tokenIn, swapData);
        //Find the amounts needed to mint
        (amount0, amount1, mintAmount) = island.getMintAmounts(token0Balance, token1Balance);
        require(mintAmount >= amountSharesMin, "Staking: below min share amount");

        if (swapData.zeroForOne) require(amount1 >= token1Balance * (10000 - maxStakingSlippageBPS) / 10000, "Staking Slippage: below min amounts");
        else require(amount0 >= token0Balance * (10000 - maxStakingSlippageBPS) / 10000, "Staking Slippage: below min amounts");

        token0Balance -= amount0;
        token1Balance -= amount1;

        _deposit(island, amount0, amount1, mintAmount, receiver);

        // refunds unused tokens
        if (token0Balance > 0) token0.safeTransfer(msg.sender, token0Balance);
        if (token1Balance > 0) token1.safeTransfer(msg.sender, token1Balance);
    }

    /// @notice removeLiquidity removes liquidity from a KodiakIsland and burns LP tokens
    /// @param burnAmount The number of KodiakIsland tokens to burn
    /// @param amount0Min Minimum amount of token0 received after burn (slippage protection)
    /// @param amount1Min Minimum amount of token1 received after burn (slippage protection)
    /// @param receiver The account to receive the underlying amounts of token0 and token1
    /// @return amount0 actual amount of token0 transferred to receiver for burning `burnAmount`
    /// @return amount1 actual amount of token1 transferred to receiver for burning `burnAmount`
    /// @return liquidityBurned amount of liquidity removed from the underlying Uniswap V3 position
    function removeLiquidity(
        IKodiakIsland island,
        uint256 burnAmount,
        uint256 amount0Min,
        uint256 amount1Min,
        address receiver
    ) external override returns (uint256 amount0, uint256 amount1, uint128 liquidityBurned) {
        IERC20(address(island)).safeTransferFrom(msg.sender, address(this), burnAmount);
        (amount0, amount1, liquidityBurned) = island.burn(burnAmount, receiver);
        require(amount0 >= amount0Min && amount1 >= amount1Min, "received below minimum");
    }

    /// @notice removeLiquidityNative same as removeLiquidity
    /// except this function unwraps Wbera and sends Bera to receiver account
    function removeLiquidityNative(
        IKodiakIsland island,
        uint256 burnAmount,
        uint256 amount0Min,
        uint256 amount1Min,
        address payable receiver
    ) external override returns (uint256 amount0, uint256 amount1, uint128 liquidityBurned) {
        IERC20 token0 = island.token0();
        IERC20 token1 = island.token1();

        bool wBeraToken0 = _isToken0WBera(address(token0), address(token1));

        IERC20(address(island)).safeTransferFrom(msg.sender, address(this), burnAmount);
        (amount0, amount1, liquidityBurned) = island.burn(burnAmount, address(this));
        require(amount0 >= amount0Min && amount1 >= amount1Min, "received below minimum");

        if (wBeraToken0) {
            if (amount0 > 0) {
                wBera.withdraw(amount0);
                receiver.sendValue(amount0);
            }
            if (amount1 > 0) token1.safeTransfer(receiver, amount1);
        } else {
            if (amount1 > 0) {
                wBera.withdraw(amount1);
                receiver.sendValue(amount1);
            }
            if (amount0 > 0) token0.safeTransfer(receiver, amount0);
        }
    }

    //// Fallback function
    receive() external payable {}

    //// Internal functions

    function _addLiquidity(
        IKodiakIsland island,
        uint256 amount0Max,
        uint256 amount1Max,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 amountSharesMin,
        address receiver
    ) internal returns (uint256 amount0, uint256 amount1, uint256 mintAmount) {
        IERC20 token0 = island.token0();
        IERC20 token1 = island.token1();
        (uint256 amount0In, uint256 amount1In, uint256 _mintAmount) = island.getMintAmounts(amount0Max, amount1Max);
        require(amount0In >= amount0Min && amount1In >= amount1Min && _mintAmount >= amountSharesMin, "below min amounts");

        if (amount0In > 0) token0.safeTransferFrom(msg.sender, address(this), amount0In);
        if (amount1In > 0) token1.safeTransferFrom(msg.sender, address(this), amount1In);

        return _deposit(island, amount0In, amount1In, _mintAmount, receiver);
    }

    function _addLiquidityNative(
        IKodiakIsland island,
        uint256 amount0Max,
        uint256 amount1Max,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 amountSharesMin,
        address receiver
    ) internal returns (uint256 amount0, uint256 amount1, uint256 mintAmount) {
        IERC20 token0 = island.token0();
        IERC20 token1 = island.token1();

        (uint256 amount0In, uint256 amount1In, uint256 _mintAmount) = island.getMintAmounts(amount0Max, amount1Max);
        require(amount0In >= amount0Min && amount1In >= amount1Min && _mintAmount >= amountSharesMin, "below min amounts");

        if (_isToken0WBera(address(token0), address(token1))) {
            require(amount0Max == msg.value, "not enough bera");
            if (amount0In > 0) wBera.deposit{value: amount0In}();
            if (amount1In > 0) token1.safeTransferFrom(msg.sender, address(this), amount1In);
        } else {
            require(amount1Max == msg.value, "not enough bera");
            if (amount1In > 0) wBera.deposit{value: amount1In}();
            if (amount0In > 0) token0.safeTransferFrom(msg.sender, address(this), amount0In);
        }

        (amount0, amount1, mintAmount) = _deposit(island, amount0In, amount1In, _mintAmount, receiver);

        if (_isToken0WBera(address(token0), address(token1))) {
            if (amount0Max > amount0) payable(msg.sender).sendValue(amount0Max - amount0);
        } else if (amount1Max > amount1) payable(msg.sender).sendValue(amount1Max - amount1);
    }

    function _deposit(
        IKodiakIsland island,
        uint256 amount0In,
        uint256 amount1In,
        uint256 _mintAmount,
        address receiver
    ) internal returns (uint256 amount0, uint256 amount1, uint256 mintAmount) {
        if (amount0In > 0) island.token0().safeIncreaseAllowance(address(island), amount0In);
        if (amount1In > 0) island.token1().safeIncreaseAllowance(address(island), amount1In);

        (amount0, amount1,) = island.mint(_mintAmount, receiver);
        require(amount0 == amount0In && amount1 == amount1In, "unexpected amounts deposited");
        mintAmount = _mintAmount;
    }

    function _isToken0WBera(address token0, address token1) internal view returns (bool wBeraToken0) {
        if (token0 == address(wBera)) wBeraToken0 = true;
        else if (token1 == address(wBera)) wBeraToken0 = false;
        else revert("one island token must be wBera");
    }

    /// @notice _swapAndVerify swaps tokenIn for token0 or token1
    /// @param token0 the first token of the island
    /// @param token1 the second token of the island
    /// @param tokenIn the token to swap
    /// @param swapData the swap
    /// @return token0Balance the balance of token0 after the swap
    /// @return token1Balance the balance of token1 after the swap
    function _swapAndVerify(IERC20 token0, IERC20 token1, IERC20 tokenIn, RouterSwapParams calldata swapData) internal returns (uint256 token0Balance, uint256 token1Balance) {
        tokenIn.safeIncreaseAllowance(kodiakRouter, swapData.amountIn);
        (bool success,) = kodiakRouter.call(swapData.routeData);
        require(success, "Swap: swap failed");
        token0Balance = token0.balanceOf(address(this));
        token1Balance = token1.balanceOf(address(this));
        if (address(token0) == address(tokenIn)) require(token1Balance >= swapData.minAmountOut, "Swap: insufficient tokenOut");
        else require(token0Balance >= swapData.minAmountOut, "Swap: insufficient tokenOut");
    }
}
