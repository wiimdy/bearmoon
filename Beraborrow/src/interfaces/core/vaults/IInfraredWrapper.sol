// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IInfraredWrapper is IERC20 {
    function metaBeraborrowCore() external view returns (address);
    function infraredCollVault() external view returns (address);
    function decimals() external view returns (uint8);
    function depositFor(address account, uint256 amount) external returns (bool);
    function withdrawTo(address account, uint256 amount) external returns (bool);
    function recover(address account) external returns (uint256);
}