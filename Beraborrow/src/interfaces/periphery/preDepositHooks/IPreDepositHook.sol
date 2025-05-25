// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

interface IPreDepositHook {
    function preDepositHook(address owner, bytes calldata data) external payable;
}