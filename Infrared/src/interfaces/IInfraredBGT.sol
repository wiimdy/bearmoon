// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20Mintable} from "./IERC20Mintable.sol";

interface IInfraredBGT is IERC20Mintable, IAccessControl {
    function burn(uint256 amount) external;
}
