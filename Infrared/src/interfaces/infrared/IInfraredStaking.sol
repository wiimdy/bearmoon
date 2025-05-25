// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IInfraredStaking {
    function stakingToken() external view returns (IERC20);

    function rewardTokens(uint256 index) external view returns (address);

    function rewardTokensLength() external view returns (uint256);

    function userRewardPerTokenPaid(
        address user,
        address rewardToken
    ) external view returns (uint256);

    function rewards(
        address user,
        address rewardToken
    ) external view returns (uint256);

    function rewardsVault() external view returns (address);

    function totalSupply() external view returns (uint256);

    function balanceOf(
        address account
    ) external view returns (uint256 _balance);

    function lastTimeRewardApplicable(
        address _rewardsToken
    ) external view returns (uint256);

    function rewardPerToken(
        address _rewardsToken
    ) external view returns (uint256);

    function earned(
        address account,
        address _rewardsToken
    ) external view returns (uint256);

    function getRewardForDuration(
        address _rewardsToken
    ) external view returns (uint256);

    function getRewardForUser(address _user) external view returns (uint256);

    function getReward() external;

    function stake(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function exit() external;
}
