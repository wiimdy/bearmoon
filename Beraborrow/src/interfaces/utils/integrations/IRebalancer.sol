// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

interface IRebalancer {
    function swap(
        address sentCurrency,
        uint sentAmount,
        address receivedCurrency,
        bytes calldata payload
    ) external;
}