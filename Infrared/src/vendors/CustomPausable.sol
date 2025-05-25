// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/extensions/ERC20Pausable.sol)

pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @dev ERC-20 token with pausable token transfers, minting and burning.
 *
 * Useful for scenarios such as preventing trades until the end of an evaluation
 * period, or having an emergency switch for freezing all token transfers in the
 * event of a large bug.
 *
 * IMPORTANT: This contract does not include public pause and unpause functions. In
 * addition to inheriting this contract, you must define both functions, invoking the
 * {Pausable-_pause} and {Pausable-_unpause} internal functions, with appropriate
 * access control, e.g. using {AccessControl} or {Ownable}. Not doing so will
 * make the contract pause mechanism of the contract unreachable, and thus unusable.
 */
abstract contract CustomPausable is ERC20, Pausable {
    /**
     * @dev See {ERC20-_update}.
     *
     * This contract modifies the default behavior of ERC20Pausable.
     *
     * - When paused, transfers are not paused.
     * - The `whenNotPaused` modifier has been removed to allow transfers even when the contract is paused.
     * - Only minting and burning operations are paused when the contract is paused.
     */
    function _update(address from, address to, uint256 value)
        internal
        virtual
        override
    {
        super._update(from, to, value);
    }
}
