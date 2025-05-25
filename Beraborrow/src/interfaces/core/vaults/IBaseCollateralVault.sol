// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {IERC4626, IERC20} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC1822Proxiable} from "@openzeppelin/contracts/interfaces/draft-IERC1822.sol";
import {IDenManager} from "../IDenManager.sol";
import {IMetaBeraborrowCore} from "../IMetaBeraborrowCore.sol";
import {IPriceFeed} from "../IPriceFeed.sol";
import {EmissionsLib} from "src/libraries/EmissionsLib.sol";

interface IBaseCollateralVault is IERC4626, IERC1822Proxiable {
    struct BaseInitParams {
        uint16 _minWithdrawFee;
        uint16 _maxWithdrawFee;
        uint16 _withdrawFee;
        IMetaBeraborrowCore _metaBeraborrowCore;
        // ERC4626
        IERC20 _asset;
        // ERC20
        string _sharesName;
        string _sharesSymbol;
    }

    struct BaseCollVaultStorage {
        uint16 minWithdrawFee;
        uint16 maxWithdrawFee;
        uint16 withdrawFee; // over rewarded tokens, in basis points
        uint8 assetDecimals;

        IMetaBeraborrowCore _metaBeraborrowCore;

        // Second mapping of this struct is usless, but it's for retrocompatibility with InfraredCollateralVault
        EmissionsLib.BalanceData balanceData;
    }

    function totalAssets() external view returns (uint);

    function fetchPrice() external view returns (uint);

    function getPrice(address token) external view returns (uint);

    function receiveDonations(address[] memory tokens, uint[] memory amounts, address receiver) external;

    function setWithdrawFee(uint16 _withdrawFee) external;

    function getBalance(address token) external view returns (uint);

    function getWithdrawFee() external view returns (uint16);

    function getMetaBeraborrowCore() external view returns (IMetaBeraborrowCore);

    function getPriceFeed() external view returns (IPriceFeed);

    function assetDecimals() external view returns (uint8);
}