// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "../pool-utils/IRateProvider.sol";
import "../solidity-utils/openzeppelin/IERC20.sol";

/**
 * @author Berachain Team
 * @title IComposableStablePoolFactoryCreateV6
 * @notice Interface for the `create` function of `ComposableStablePoolFactory` contract, version 6.
 * @dev this interface is necessitated because the monorepo does not have the latest version of
 * the `ComposableStablePoolFactory` contract currently deployed.
 */
interface IComposableStablePoolFactoryCreateV6 {
    /**
     * @dev taken from: https://etherscan.io/address/0x5B42eC6D40f7B7965BE5308c70e2603c0281C1E9#code
     * @dev Deploys a new `ComposableStablePool`.
     */
    function create(
        string memory name,
        string memory symbol,
        IERC20[] memory tokens,
        uint256 amplificationParameter,
        IRateProvider[] memory rateProviders,
        uint256[] memory tokenRateCacheDurations,
        bool exemptFromYieldProtocolFeeFlag,
        uint256 swapFeePercentage,
        address owner,
        bytes32 salt
    ) external returns (address);
}
