// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.19;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an manager) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the manager account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyManager`, which can be applied to your functions to restrict their use to
 * the manager.
 */
abstract contract OwnableUninitialized {
    address internal _manager;

    event OwnershipTransferred(
        address indexed previousManager,
        address indexed newManager
    );

    /// @dev Initializes the contract setting the deployer as the initial manager.
    /// CONSTRUCTOR EMPTY - USE initialize() INSTEAD
    constructor() {}

    /**
     * @dev Returns the address of the current manager.
     */
    function manager() external view returns (address) {
        return _manager;
    }

    /**
     * @dev Throws if called by any account other than the manager.
     */
    modifier onlyManager() {
        require(msg.sender == _manager, "Ownable: caller is not the manager");
        _;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current manager.
     */
    function transferOwnership(address newOwner) external onlyManager {
        require(
            newOwner != address(0),
            "Ownable: call renounceOwnership to set zero address"
        );
        emit OwnershipTransferred(_manager, newOwner);
        _manager = newOwner;
    }
}