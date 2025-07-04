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

pragma solidity >=0.7.0 <0.9.0;

import "../vault/IProtocolFeesCollector.sol";

/**
 * @author Balancer Labs
 * @title Protocol Fees Withdrawer
 * @notice Safety layer around the Protocol Fees Collector which allows withdrawals of specific tokens to be blocked.
 * This is useful for the case in where tokens that shouldn't be distributed are unexpectedly paid into the Protocol
 * Fees Collector.
 */
interface IProtocolFeesWithdrawer {
    event TokenAllowlisted(IERC20 token);
    event TokenDenylisted(IERC20 token);
    event POLFeeCollectorChanged(address newPOLFeeCollector);
    event FeeReceiverChanged(address newFeeReceiver);
    event POLFeeCollectorPercentageChanged(uint256 newPolFeeCollectorPercentage);

    /**
     * @notice Returns the address of the Protocol Fee Collector.
     */
    function getProtocolFeesCollector() external view returns (IProtocolFeesCollector);

    /**
     * @notice Returns the address of the POL fee collector.
     * POL fee collector is used to collect dapp fees and distribute them to the `BGT` boosters in POL mechanism.
     */
    function polFeeCollector() external view returns (address);

    /**
     * @notice Returns the address of the fee receiver.
     * This will get a portion of the fees collected by the Protocol Fee Collector.
     */
    function feeReceiver() external view returns (address);

    /**
     * @notice Returns the percentage of fees that will go to the POL fee collector.
     * 1e18 precision is used for this value, 1e18 = 100%
     */
    function polFeeCollectorPercentage() external view returns (uint256);

    /**
     * @notice Returns whether the provided token may be withdrawn from the Protocol Fee Collector
     */
    function isWithdrawableToken(IERC20 token) external view returns (bool);

    /**
     * @notice Returns whether the provided array of tokens may be withdrawn from the Protocol Fee Collector
     * @dev Returns false if any token is denylisted.
     */
    function isWithdrawableTokens(IERC20[] calldata tokens) external view returns (bool);

    /**
     * @notice Returns the denylisted token at the given `index`.
     */
    function getDenylistedToken(uint256 index) external view returns (IERC20);

    /**
     * @notice Returns the number of denylisted tokens.
     */
    function getDenylistedTokensLength() external view returns (uint256);

    /**
     * @notice Withdraws fees from the Protocol Fee Collector.
     * @dev Reverts if attempting to withdraw a denylisted token.
     * @param tokens - an array of token addresses to withdraw.
     * @param amounts - an array of the amounts of each token to withdraw.
     * @param recipient - the address to which to send the withdrawn tokens.
     */
    function withdrawCollectedFees(
        IERC20[] calldata tokens,
        uint256[] calldata amounts,
        address recipient
    ) external;

    /**
     * @notice Withdraws fees from the Protocol Fee Collector to `polFeeCollector` and `feeReceiver`
     * @dev Withdraws all the balance of `_protocolFeesCollector` for each token in the `tokens` array.
     * @dev The fees are distributed between `polFeeCollector` and `feeReceiver`
     * according to the `polFeeCollectorPercentage`.
     * @dev Reverts if attempting to withdraw a denylisted token.
     * @param tokens - an array of token addresses to withdraw.
     */
    function distributeAndWithdrawCollectedFees(IERC20[] calldata tokens) external;

    /**
     * @notice Sets the address of the POL fee collector.
     * @dev Reverts if the provided address is zero
     */
    function setPOLFeeCollector(address _polFeeCollector) external;

    /**
     * @notice Sets the address of the fee receiver.
     * @dev Reverts if the provided address is zero
     */
    function setFeeReceiver(address _feeReceiver) external;

    /**
     * @notice Sets the percentage of fees that will go to the POL fee collector.
     * @dev Reverts if the provided percentage is greater than 100%
     */
    function setPOLFeeCollectorPercentage(uint256 _polFeeCollectorPercentage) external;

    /**
     * @notice Marks the provided token as ineligible for withdrawal from the Protocol Fee Collector
     */
    function denylistToken(IERC20 token) external;

    /**
     * @notice Marks the provided token as eligible for withdrawal from the Protocol Fee Collector
     */
    function allowlistToken(IERC20 token) external;
}
