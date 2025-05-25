// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {IInfraredCollateralVault} from "./IInfraredCollateralVault.sol";
import {IInfraredVault} from "../../utils/integrations/IInfraredVault.sol";

interface IIBGTVault is IInfraredCollateralVault {
    /*
    struct IBGTVaultStorage {
        IInfraredVault infraredIBGTVault;
    }

    struct InitParams {
        IInfraredVault _infraredIBGTVault;
    }
    */

    function initialize(IInfraredCollateralVault.InfraredInitParams calldata baseParams /*, InitParams calldata ibgtParams */) external;
}