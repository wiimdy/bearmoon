// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import "../interfaces/core/IBeraborrowCore.sol";

/**
    @title Beraborrow Ownable
    @notice Contracts inheriting `BeraborrowOwnable` have the same owner as `BeraborrowCore`.
            The ownership cannot be independently modified or renounced.
    @dev In the contracts that use BERABORROW_CORE to interact with protocol instance specific parameters,
            the immutable will be instanced with BeraborrowCore.sol, eitherway, it will be MetaBeraborrowCore.sol
 */
contract BeraborrowOwnable {
    IBeraborrowCore public immutable BERABORROW_CORE;

    constructor(address _beraborrowCore) {
        BERABORROW_CORE = IBeraborrowCore(_beraborrowCore);
    }

    modifier onlyOwner() {
        require(msg.sender == BERABORROW_CORE.owner(), "Only owner");
        _;
    }

    function owner() public view returns (address) {
        return BERABORROW_CORE.owner();
    }

    function guardian() public view returns (address) {
        return BERABORROW_CORE.guardian();
    }
}
