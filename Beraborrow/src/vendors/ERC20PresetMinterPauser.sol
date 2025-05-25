// SPDX-License-Identifier: BUSL-1.1
// OpenZeppelin Contracts (last updated v4.5.0)
// (token/ERC20/presets/ERC20PresetMinterPauser.sol)

/* solhint-disable */
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControlEnumerable} from
    "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {CustomPausable} from "./CustomPausable.sol";

/**
 * @dev {ERC20} token, including:
 *
 *  - ability for holders to burn (destroy) their tokens
 *  - a minter role that allows for token minting (creation)
 *  - a pauser role that allows to stop all token transfers
 *
 * This contract uses {AccessControl} to lock permissioned functions using the
 * different roles - head to its documentation for details.
 *
 * The account that deploys the contract will be granted the minter and pauser
 * roles, as well as the default admin role, which will let it grant both minter
 * and pauser roles to other accounts.
 *
 * _Deprecated in favor of https://wizard.openzeppelin.com/[Contracts Wizard]._
 */
contract ERC20PresetMinterPauser is
    Context,
    AccessControlEnumerable,
    CustomPausable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /**
     * @dev Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE` and `PAUSER_ROLE` to the
     * account that deploys the contract.
     *
     * See {ERC20-constructor}.
     */
    constructor(
        string memory name,
        string memory symbol,
        address _admin,
        address _minter,
        address _pauser,
        address _burner
    ) ERC20(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);

        _grantRole(MINTER_ROLE, _minter);
        _grantRole(PAUSER_ROLE, _pauser);
        if (_burner != address(0)) {
            _grantRole(BURNER_ROLE, _burner);
        }
    }

    /**
     * @dev Creates `amount` new tokens for `to`.
     *
     * See {ERC20-_mint}.
     *
     * Requirements:
     *
     * - the caller must have the `MINTER_ROLE`.
     */
    function mint(address to, uint256 amount) public virtual whenNotPaused {
        require(
            hasRole(MINTER_ROLE, _msgSender()),
            "ERC20PresetMinterPauser: must have minter role to mint"
        );
        _mint(to, amount);
    }

    /**
     * @dev Burn `amount` new tokens from `from`.
     *
     * See {ERC20-_burn}.
     *
     * Requirements:
     *
     * - the caller must have the `BURNER_ROLE`.
     */
    function burn(uint256 amount) public virtual whenNotPaused {
        require(
            hasRole(BURNER_ROLE, _msgSender()),
            "ERC20PresetMinterPauser: must have burner role to burn"
        );
        _burn(msg.sender, amount);
    }

    /**
     * @dev Pauses all token transfers.
     *
     * See {ERC20Pausable} and {Pausable-_pause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function pause() public virtual {
        require(
            hasRole(PAUSER_ROLE, _msgSender()),
            "ERC20PresetMinterPauser: must have pauser role to pause"
        );
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     *
     * See {ERC20Pausable} and {Pausable-_unpause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function unpause() public virtual {
        require(
            hasRole(PAUSER_ROLE, _msgSender()),
            "ERC20PresetMinterPauser: must have pauser role to unpause"
        );
        _unpause();
    }

    function _update(address from, address to, uint256 value)
        internal
        virtual
        override(CustomPausable)
    {
        super._update(from, to, value);
    }
}
