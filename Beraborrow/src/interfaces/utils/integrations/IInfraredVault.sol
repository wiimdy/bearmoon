// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

interface IInfraredVault {
    function stakingToken() external view returns (address);
    function stake(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getReward() external;
    function getRewardForUser(address account) external;
    function rewardTokens(uint) external view returns (address);
    function getAllRewardTokens() external view returns (address[] memory);
    function earned(address account, address _rewardsToken) external view returns (uint256);
}