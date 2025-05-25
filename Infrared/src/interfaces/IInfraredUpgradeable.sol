// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

interface IInfraredUpgradeable is IAccessControl {
    /// @notice Access control for keeper role
    function KEEPER_ROLE() external view returns (bytes32);

    /// @notice Access control for governance role
    function GOVERNANCE_ROLE() external view returns (bytes32);

    /// @notice Infrared coordinator contract
    function infrared() external view returns (address);
}
