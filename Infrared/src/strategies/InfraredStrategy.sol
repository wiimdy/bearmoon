// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {StrategyBase} from "./StrategyBase.sol";
import {IInfraredStaking} from "../interfaces/infrared/IInfraredStaking.sol";
import {ISwapRouter} from "../interfaces/ISwapRouter.sol";
import {ILpRouter} from "../interfaces/ILpRouter.sol";

/**
 * @title InfraredStrategy
 * @notice A strategy contract for managing Infrared LP positions
 * @dev This strategy is a basic implementation that holds Infrared LP tokens without additional staking
 * It inherits from StrategyBase and overrides the required functions
 */
contract InfraredStrategy is StrategyBase {
    using SafeERC20 for IERC20;

    IInfraredStaking public staking;
    uint256 public rewardTokensLength;

    event RewardTokensLengthChanged(uint256 rewardTokensLength);
    event ChangedStaking(address staking);

    /**
     * @notice Initializes the Infrared strategy
     * @param assetAddress Address of the LP token this strategy manages
     * @param governanceAddress Address of the governance controller
     * @param strategistAddress Address of the strategist
     * @param controllerAddress Address of the controller contract
     * @param timelockAddress Address of the timelock contract
     * @param wrappedNativeAddress Address of the wrapped native token
     * @param bgtAddress Address of the BGT token
     * @param swapRouterAddress Address of the swap router
     * @param lpRouterAddress Address of the lp router
     * @param stakingAddress Address of the staking contract
     * @param rewardTokensCount Length of the reward tokens array
     */
    constructor(
        address assetAddress,
        address governanceAddress,
        address strategistAddress,
        address controllerAddress,
        address timelockAddress,
        address wrappedNativeAddress,
        address bgtAddress,
        address swapRouterAddress,
        address lpRouterAddress,
        address zapperAddress,
        address stakingAddress,
        uint256 rewardTokensCount
    )
        StrategyBase(
            assetAddress,
            governanceAddress,
            strategistAddress,
            controllerAddress,
            timelockAddress,
            wrappedNativeAddress,
            bgtAddress,
            swapRouterAddress,
            lpRouterAddress,
            zapperAddress
        )
    {
        _revertAddressZero(stakingAddress);
        staking = IInfraredStaking(stakingAddress);
        rewardTokensLength = rewardTokensCount;
        emit RewardTokensLengthChanged(rewardTokensCount);
    }

    /**
     * @notice Deposits tokens into the strategy
     */
    function deposit()
        public
        override
        nonReentrant
        sphereXGuardPublic(0x05a57b80, 0xd0e30db0)
    {
        uint256 balance = asset.balanceOf(address(this));
        asset.approve(address(staking), balance);
        staking.stake(balance);
    }

    /**
     * @notice Returns the harvestable rewards
     * @return rewards Addresses of reward tokens
     * @return amounts Amounts of reward tokens available
     */
    function getHarvestable()
        external
        view
        override
        returns (address[] memory rewards, uint256[] memory amounts)
    {
        rewards = new address[](rewardTokensLength + 1);
        amounts = new uint256[](rewardTokensLength + 1);
        for (uint256 i = 0; i < rewardTokensLength; i++) {
            rewards[i] = staking.rewardTokens(i);
            amounts[i] = staking.earned(address(this), rewards[i]);
        }
        rewards[rewardTokensLength] = address(bgt);
        amounts[rewardTokensLength] = bgt.balanceOf(address(this));
    }

    /**
     * @notice Harvests any available rewards
     */
    function harvest()
        public
        override
        onlyBenevolent
        sphereXGuardPublic(0xdb542a34, 0x4641257d)
    {
        uint256 newAssets = _swapBGTToAsset();
        staking.getReward();
        for (uint256 i = 0; i < rewardTokensLength; i++) {
            address rewardToken = staking.rewardTokens(i);
            uint256 rewardAmount = IERC20(rewardToken).balanceOf(address(this));
            if (rewardToken == address(asset)) {
                newAssets = rewardAmount;
            } else if (rewardAmount > 0 && rewardToken != wrappedNative) {
                IERC20(rewardToken).safeTransfer(
                    address(swapRouter),
                    rewardAmount
                );
                swapRouter.swapWithDefaultDex(
                    rewardToken,
                    wrappedNative,
                    rewardAmount,
                    0,
                    address(this)
                );
            }
        }
        uint256 balance = IERC20(wrappedNative).balanceOf(address(this));
        if (balance > 0) {
            IERC20(wrappedNative).forceApprove(address(zapper), balance);
            (uint256 amount, ) = zapper.swapToAssets(
                address(asset),
                address(wrappedNative),
                balance,
                address(this)
            );
            newAssets += amount;
        }

        _distributePerformanceFeesBasedAmountAndDeposit(newAssets);
        emit Harvest(block.timestamp, newAssets);
    }

    /**
     * @notice Returns the balance of tokens in the strategy's staking pool
     * @return Amount of tokens in the pool
     */
    function balanceOfPool() public view virtual override returns (uint256) {
        return staking.balanceOf(address(this));
    }

    /**
     * @notice Internal function to withdraw tokens from the strategy
     * @param amount Amount of tokens to withdraw
     * @return The amount of tokens withdrawn
     */
    function _withdrawSome(
        uint256 amount
    )
        internal
        virtual
        override
        sphereXGuardInternal(0xe455d75b)
        returns (uint256)
    {
        if (amount != 0) {
            staking.withdraw(amount);
        }
        return amount;
    }

    function setRewardTokensLength(
        uint256 newRewardTokensLength
    ) external onlyGovernance sphereXGuardExternal(0xa2c045a3) {
        rewardTokensLength = newRewardTokensLength;
        emit RewardTokensLengthChanged(newRewardTokensLength);
    }

    function setStaking(address newStaking) external onlyGovernance {
        _revertAddressZero(newStaking);
        staking = IInfraredStaking(newStaking);
        emit ChangedStaking(newStaking);
    }
}
