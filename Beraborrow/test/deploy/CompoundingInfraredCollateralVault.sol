// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {InfraredCollateralVault, SafeERC20, IERC20} from "src/core/vaults/InfraredCollateralVault.sol";
import {IInfraredCollateralVault} from "src/interfaces/core/vaults/IInfraredCollateralVault.sol";
import {IInfraredVault} from "src/interfaces/utils/integrations/IInfraredVault.sol";
import {IIBGTVault} from "src/interfaces/core/vaults/IIBGTVault.sol";


contract CompoundingInfraredCollateralVault is InfraredCollateralVault { 
    using SafeERC20 for IERC20;

    function initialize(IInfraredCollateralVault.InfraredInitParams calldata baseParams) public initializer {
        __InfraredCollateralVault_init(baseParams);
    }

    function _autoCompoundHook(address _token, address _ibgt, IIBGTVault _ibgtVault, uint _rewards) internal override returns (uint, address) {
        uint bbIbgtMinted;
        bool isIBGT = _token == _ibgt;
        if (isIBGT && _hasPriceFeed(_token)) {
            IERC20(_ibgt).safeIncreaseAllowance(address(_ibgtVault), _rewards);
            bbIbgtMinted = _ibgtVault.deposit(_rewards, address(this));
            _rewards = bbIbgtMinted;
        }
        _token = isIBGT ? address(_ibgtVault) : _token;

        return (_rewards, _token);
    }
}