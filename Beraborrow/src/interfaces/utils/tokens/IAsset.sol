// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IAsset is IERC20 {
    function decimals() external view returns (uint8);
}