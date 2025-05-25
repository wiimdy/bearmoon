// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBGT is IERC20 {
  function redeem(address receiver, uint256 amount) external;
}
