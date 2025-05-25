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

import "@balancer-labs/v2-interfaces/contracts/standalone-utils/IProtocolFeesWithdrawer.sol";
import "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";

import "@balancer-labs/v2-solidity-utils/contracts/helpers/SingletonAuthentication.sol";
import "@balancer-labs/v2-solidity-utils/contracts/math/FixedPoint.sol";
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/EnumerableSet.sol";

/**
 * @author Balancer Labs
 * @title Protocol Fees Withdrawer
 * @notice Safety layer around the Protocol Fees Collector which allows withdrawals of specific tokens to be blocked.
 * This is useful for the case where tokens that shouldn't be distributed are unexpectedly paid into the Protocol
 * Fees Collector.
 * It Manages the distribution of collected fees between the
 * polFeeCollector and feeReceiver based on the `polFeeCollectorPercentage`.
 */
contract ProtocolFeesWithdrawer is IProtocolFeesWithdrawer, SingletonAuthentication {
    using EnumerableSet for EnumerableSet.AddressSet;
    using FixedPoint for uint256;

    IProtocolFeesCollector private immutable _protocolFeesCollector;

    EnumerableSet.AddressSet private _denylistedTokens;

    /// @inheritdoc IProtocolFeesWithdrawer
    address public override polFeeCollector;

    /// @inheritdoc IProtocolFeesWithdrawer
    address public override feeReceiver;

    /// @inheritdoc IProtocolFeesWithdrawer
    uint256 public override polFeeCollectorPercentage;

    constructor(
        IVault vault,
        address _polFeeCollector,
        address _feeReceiver,
        IERC20[] memory initialDeniedTokens
    ) SingletonAuthentication(vault) {
        _protocolFeesCollector = vault.getProtocolFeesCollector();
        require(_polFeeCollector != address(0), "ZERO_ADDRESS");
        require(_feeReceiver != address(0), "ZERO_ADDRESS");
        polFeeCollector = _polFeeCollector;
        feeReceiver = _feeReceiver;
        // This is not passed as a param in the constructor, gets set to default 100%.
        polFeeCollectorPercentage = FixedPoint.ONE; // 100%
        uint256 tokensLength = initialDeniedTokens.length;
        for (uint256 i = 0; i < tokensLength; ++i) {
            _denylistToken(initialDeniedTokens[i]);
        }
    }

    /**
     * @notice Returns the address of the Protocol Fee Collector.
     */
    function getProtocolFeesCollector() external view override returns (IProtocolFeesCollector) {
        return _protocolFeesCollector;
    }

    /**
     * @notice Returns whether the provided token may be withdrawn from the Protocol Fee Collector
     */
    function isWithdrawableToken(IERC20 token) public view override returns (bool) {
        return !_denylistedTokens.contains(address(token));
    }

    /**
     * @notice Returns whether the provided array of tokens may be withdrawn from the Protocol Fee Collector
     * @dev Returns false if any token is denylisted.
     */
    function isWithdrawableTokens(IERC20[] calldata tokens) public view override returns (bool) {
        uint256 tokensLength = tokens.length;
        for (uint256 i = 0; i < tokensLength; ++i) {
            if (!isWithdrawableToken(tokens[i])) return false;
        }
        return true;
    }

    /**
     * @notice Returns the denylisted token at the given `index`.
     */
    function getDenylistedToken(uint256 index) external view override returns (IERC20) {
        return IERC20(_denylistedTokens.at(index));
    }

    /**
     * @notice Returns the number of denylisted tokens.
     */
    function getDenylistedTokensLength() external view override returns (uint256) {
        return _denylistedTokens.length();
    }

    /**
     * @notice Withdraws fees from the Protocol Fee Collector.
     * This function should only be used in special cases where
     * we need to transfer fees to a different recipient other than polFeeCollector and feeReceiver.
     * cases like these https://forum.balancer.fi/t/medium-severity-bug-found/3161
     * @dev Reverts if attempting to withdraw a denylisted token.
     * @param tokens - an array of token addresses to withdraw.
     * @param amounts - an array of the amounts of each token to withdraw.
     * @param recipient - the address to which to send the withdrawn tokens.
     */
    function withdrawCollectedFees(
        IERC20[] calldata tokens,
        uint256[] calldata amounts,
        address recipient
    ) external override authenticate {
        require(isWithdrawableTokens(tokens), "Attempting to withdraw denylisted token");

        // We delegate checking of inputs and reentrancy protection to the ProtocolFeesCollector.
        _protocolFeesCollector.withdrawCollectedFees(tokens, amounts, recipient);
    }

    /// @inheritdoc IProtocolFeesWithdrawer
    function distributeAndWithdrawCollectedFees(IERC20[] calldata tokens) external override authenticate {
        // `isWithdrawableTokens(tokens)` check is performed inside `_checkWithdrawableTokensAndDistributeFees`.
        // We delegate checking of inputs and reentrancy protection to the ProtocolFeesCollector.
        (
            uint256[] memory polFeeCollectorFees,
            uint256[] memory feeReceiverFees
        ) = _checkWithdrawableTokensAndDistributeFees(tokens);
        _protocolFeesCollector.withdrawCollectedFees(tokens, polFeeCollectorFees, polFeeCollector);
        _protocolFeesCollector.withdrawCollectedFees(tokens, feeReceiverFees, feeReceiver);
    }

    /**
     * @notice Marks the provided token as ineligible for withdrawal from the Protocol Fee Collector
     */
    function denylistToken(IERC20 token) external override authenticate {
        _denylistToken(token);
    }

    /**
     * @notice Marks the provided token as eligible for withdrawal from the Protocol Fee Collector
     */
    function allowlistToken(IERC20 token) external override authenticate {
        require(_denylistedTokens.remove(address(token)), "Token is not denylisted");
        emit TokenAllowlisted(token);
    }

    /// @inheritdoc IProtocolFeesWithdrawer
    function setPOLFeeCollector(address _polFeeCollector) external override authenticate {
        require(_polFeeCollector != address(0), "ZERO_ADDRESS");
        polFeeCollector = _polFeeCollector;
        emit POLFeeCollectorChanged(_polFeeCollector);
    }

    /// @inheritdoc IProtocolFeesWithdrawer
    function setFeeReceiver(address _feeReceiver) external override authenticate {
        require(_feeReceiver != address(0), "ZERO_ADDRESS");
        feeReceiver = _feeReceiver;
        emit FeeReceiverChanged(_feeReceiver);
    }

    /// @inheritdoc IProtocolFeesWithdrawer
    function setPOLFeeCollectorPercentage(uint256 _polFeeCollectorPercentage) external override authenticate {
        require(_polFeeCollectorPercentage <= FixedPoint.ONE, "MAX_PERCENTAGE_EXCEEDED");
        polFeeCollectorPercentage = _polFeeCollectorPercentage;
        emit POLFeeCollectorPercentageChanged(_polFeeCollectorPercentage);
    }

    // Internal functions

    function _denylistToken(IERC20 token) internal {
        require(_denylistedTokens.add(address(token)), "Token already denylisted");
        emit TokenDenylisted(token);
    }

    // checks if the tokens are withdrawable and distributes the fees
    // between `polFeeCollector` and `feeReceiver`.
    function _checkWithdrawableTokensAndDistributeFees(IERC20[] calldata tokens)
        internal
        view
        returns (uint256[] memory polFeeCollectorFees, uint256[] memory feeReceiverFees)
    {
        uint256 tokensLength = tokens.length;
        polFeeCollectorFees = new uint256[](tokensLength);
        feeReceiverFees = new uint256[](tokensLength);

        for (uint256 i = 0; i < tokensLength; ++i) {
            IERC20 token = tokens[i];
            require(isWithdrawableToken(token), "Attempting to withdraw denylisted token");
            uint256 amount = token.balanceOf(address(_protocolFeesCollector));
            polFeeCollectorFees[i] = amount.mulDown(polFeeCollectorPercentage);
            feeReceiverFees[i] = amount.sub(polFeeCollectorFees[i]);
        }
    }
}
