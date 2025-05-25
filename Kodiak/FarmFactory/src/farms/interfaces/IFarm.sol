// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

interface IFarm {

    function initialize(
        address _owner,
        address _stakingToken,
        address[] memory _rewardTokens,
        address[] memory _rewardManagers,
        uint256[] memory _rewardRates,
        bytes calldata _data
    ) external;
}