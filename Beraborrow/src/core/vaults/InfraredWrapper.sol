// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {ERC20Wrapper, ERC20, IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Wrapper.sol";
import {IMetaBeraborrowCore} from "src/interfaces/core/IMetaBeraborrowCore.sol";

/**
 * @title InfraredWrapper
 * @author Beraborrow Team
 * @notice Wraps InfraredCollateralVault's underlying token to have a unique InfraredVault PoL gauge
 */
contract InfraredWrapper is ERC20Wrapper {
    using SafeERC20 for IERC20;

    IMetaBeraborrowCore public immutable metaBeraborrowCore;
    address public immutable infraredCollVault;

    error OnlyOwner(address caller);

    constructor(
        IERC20 _underlying, string memory _shareName, string memory _shareSymbol, address _metaBeraborrowCore, address _infraredCollVault
    ) ERC20Wrapper(_underlying) ERC20(_shareName, _shareSymbol) {
        metaBeraborrowCore = IMetaBeraborrowCore(_metaBeraborrowCore);
        infraredCollVault = _infraredCollVault;
    }

    function depositFor(address account, uint256 amount) public override returns (bool) {
        if (msg.sender != infraredCollVault) revert OnlyOwner(msg.sender);

        SafeERC20.safeTransferFrom(underlying, msg.sender, address(this), amount);
        _mint(account, amount);
        return true;
    }

    function recover(address account) external returns (uint256) {
        if (msg.sender != metaBeraborrowCore.owner()) revert OnlyOwner(msg.sender);

        return _recover(account);
    }
}