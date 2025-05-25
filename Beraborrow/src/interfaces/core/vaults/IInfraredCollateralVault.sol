// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IBaseCollateralVault} from "./IBaseCollateralVault.sol";
import {IInfraredWrapper} from "./IInfraredWrapper.sol";
import {IDenManager} from "../IDenManager.sol";
import {IBeraborrowCore} from "../IBeraborrowCore.sol";
import {IInfraredVault} from "../../utils/integrations/IInfraredVault.sol";
import {EmissionsLib} from "src/libraries/EmissionsLib.sol";

interface IInfraredCollateralVault is IBaseCollateralVault {
    struct InfraredCollVaultStorage {
        uint16 minPerformanceFee;
        uint16 maxPerformanceFee;
        uint16 performanceFee; // over yield, in basis points
        address iRedToken;
        /// @dev We currently don't know the infraredVault implementation, but if it were to be possible for them to remove tokens from the rewardTokens
        /// There would be no need to remove it from here since the amounts should continue being accounted for in the virtual balance
        EnumerableSet.AddressSet rewardedTokens;

        IInfraredVault _infraredVault;
        address ibgtVault;
        address ibgt;
        IInfraredWrapper infraredWrapper;
        uint96 lastUpdate;

        mapping(address tokenIn => uint) threshold;
    }

    struct InfraredInitParams {
        BaseInitParams _baseParams;
        uint16 _minPerformanceFee;
        uint16 _maxPerformanceFee;
        uint16 _performanceFee; // over yield, in basis points
        address _iRedToken;
        IInfraredVault _infraredVault;
        address _ibgtVault;
        address _infraredWrapper;
    }

    struct RebalanceParams {
        address sentCurrency; 
        uint sentAmount; 
        address swapper;
        bytes payload;
    }

    function rebalance(RebalanceParams calldata p) external;

    function setUnlockRatePerSecond(address token, uint64 _unlockRatePerSecond) external;

    function internalizeDonations(address[] memory tokens, uint128[] memory amounts) external;

    function setPairThreshold(address tokenIn, uint thresholdInBP) external;

    function setPerformanceFee(uint16 _performanceFee) external;
    function setWithdrawFee(uint16 _withdrawFee) external;

    function getBalance(address token) external view returns (uint);

    function getBalanceOfWithFutureEmissions(address token) external view returns (uint);

    function getFullProfitUnlockTimestamp(address token) external view returns (uint);

    function unlockRatePerSecond(address token) external view returns (uint);

    function getLockedEmissions(address token) external view returns (uint);

    function getPerformanceFee() external view returns (uint16);


    function rewardedTokens() external view returns (address[] memory);

    function iRedToken() external view returns (address);

    function infraredVault() external view returns (IInfraredVault);

    function ibgt() external view returns (address);

    function ibgtVault() external view returns (address);
}