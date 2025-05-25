// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Errors, Upgradeable} from "src/utils/Upgradeable.sol";

import {IInfrared} from "src/interfaces/IInfrared.sol";
import {IInfraredUpgradeable} from "src/interfaces/IInfraredUpgradeable.sol";

/**
 * @title InfraredUpgradeable
 * @notice This contract provides base upgradeability functionality for Infrared.
 */
abstract contract InfraredUpgradeable is Upgradeable {
    /// @notice Infrared coordinator contract
    IInfrared public infrared;

    // Reserve storage space for upgrades
    uint256[10] private __gap;

    modifier onlyInfrared() {
        if (msg.sender != address(infrared)) revert Errors.NotInfrared();
        _;
    }

    constructor() {
        // prevents implementation contracts from being used
        _disableInitializers();
    }

    function __InfraredUpgradeable_init(address _infrared)
        internal
        onlyInitializing
    {
        // _infrared == address(0) means this is infrared
        infrared = IInfrared(_infrared);
        __Upgradeable_init();
    }
}
