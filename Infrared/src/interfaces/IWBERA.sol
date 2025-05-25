// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @notice The deposit function allows users to deposit EVM balance (BERA) into the contract.
 * It mints an equivalent amount of WBERA tokens and assigns them to the sender.
 */
interface IWBERA is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}
