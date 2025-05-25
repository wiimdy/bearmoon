// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {DenManager} from "../DenManager.sol";
import {IDebtToken} from "../../interfaces/core/IDebtToken.sol";
import {IPriceFeed} from "../../interfaces/core/IPriceFeed.sol";
import {ISortedDens} from "../../interfaces/core/ISortedDens.sol";

/**
    @title Beraborrow Permissioned Den Manager
    @notice Limits only one arbitrary account to be opened, and redemptions can be toggled on and off
    @dev Usable by boyco incentivized PSMBond.sol
    @notice Based on Liquity's `DenManager`
            https://github.com/liquity/dev/blob/main/packages/contracts/contracts/TroveManager.sol

            Beraborrow's implementation is modified so that multiple `DenManager` and `SortedDens`
            contracts are deployed in tandem, with each pair managing dens of a single collateral
            type.

            Functionality related to liquidations has been moved to `LiquidationManager`. This was
            necessary to avoid the restriction on deployed bytecode size.
 */
contract PermissionedDenManager is DenManager {
    address public permissionedDen;
    address public protocolDen;

    function _isPermissionedCheck(address _borrower) internal view override {
        require(_borrower == permissionedDen || _borrower == protocolDen, "PermissionedDenManager: Only the Permissioned/ProtocolDen can open a position");
    }

    modifier onlyOwnerOrManager() {
        require(msg.sender == owner() || msg.sender == BERABORROW_CORE.manager(), "Only owner or manager");
        _;
    }

    constructor(
        address _beraborrowCore,
        address _gasPoolAddress,
        address _debtTokenAddress,
        address _borrowerOperations,
        address _liquidationManager,
        address _brimeDen,
        uint256 _gasCompensation
    ) DenManager(
        _beraborrowCore,
        _gasPoolAddress,
        _debtTokenAddress,
        _borrowerOperations,
        _liquidationManager,
        _brimeDen,
        _gasCompensation
    ) {}

    /// @dev Initialization function
    function setPermissionedParameters(address _permissionedDen, address _protocolDen) external onlyOwnerOrManager {
        _setPermissionedDen(_permissionedDen);
        _setProtocolDen(_protocolDen);
    }

    /**
     * @dev Has to be set just after PermissionedDenManager is deployed via the Factory
     * @param _permissionedDen Address of the permissioned den, probably PSMBond
     */
    function setPermissionedDen(address _permissionedDen) external onlyOwner {
        _setPermissionedDen(_permissionedDen);
    }

    /**
     * @notice To enable liquidations on permissioned den (BoycoVault), since a minimum of 2 dens are required
     * @dev Has a higher CR than the permissioned den
     * @param _protocolDen Address of the protocol den, apart from BoycoVault
     */
    function setProtocolDen(address _protocolDen) external onlyOwner {
        _setProtocolDen(_protocolDen);
    }

    function _setPermissionedDen(address _permissionedDen) private  {
        permissionedDen = _permissionedDen;
    }

    function _setProtocolDen(address _protocolDen) private {
        protocolDen = _protocolDen;
    }
}