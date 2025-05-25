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

import "@balancer-labs/v2-interfaces/contracts/pool-stable/IComposableStablePoolFactoryCreateV6.sol";
import "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import "@balancer-labs/v2-pool-stable/contracts/ComposableStablePool.sol";
import "@balancer-labs/v2-pool-weighted/contracts/WeightedPoolFactory.sol";
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/Address.sol";

/**
 * @author Berachain Team
 * @title PoolCreationHelper
 * @notice Helper contract to create and join pools in a single transaction.
 * Supports joining `WBERA` pools with `BERA`.
 * Non-standard ERC20 tokens, double-entrypoint tokens are not supported.
 * @dev joinPool is called on behalf of the user hence this contract should
 * be approved as a relayer by the pool creator inside vault to join the pool.
 * This uses a custom interface for `ComposableStablePoolFactory` to support the V6 version.
 * Check `IComposableStablePoolFactoryCreateV6.sol` for more details.
 */
contract PoolCreationHelper {
    using Address for address payable;

    /// @notice Emitted when a weighted pool is created
    event WeightedPoolCreated(string name, string symbol, address indexed pool);

    /// @notice Emitted when a composable stable pool is created
    event ComposableStablePoolCreated(string name, string symbol, address indexed pool);

    // Amount passed as maxAmountsIn when joining a ComposableStablePool at BPT index.
    // This is taken from balancer SDK which passes `type(uint256).max` as maxAmountsIn for safety.
    // https://github.com/balancer/balancer-sdk/blob/develop/balancer-js/src/modules/pools/
    // factory/composable-stable/composable-stable.factory.ts#L271
    uint256 private constant _MAX_UINT256 = type(uint256).max;

    // State variables
    IVault public immutable vault;
    IERC20 public immutable wBERA;
    WeightedPoolFactory public immutable weightedPoolFactory;
    IComposableStablePoolFactoryCreateV6 public immutable composableStablePoolFactory;

    constructor(
        IVault _vault,
        WeightedPoolFactory _weightedPoolFactory,
        IComposableStablePoolFactoryCreateV6 _composableStablePoolFactory
    ) {
        vault = _vault;
        // Initialize wBERA to the WETH address of the vault
        // since vault is immutable along with WETH also being immutable inside vault,
        // we can safely cache the address of WETH without worrying about the change of WETH address.
        wBERA = _vault.WETH();
        weightedPoolFactory = _weightedPoolFactory;
        composableStablePoolFactory = _composableStablePoolFactory;
    }

    /// @dev Taken from relayer/BalancerRelayer.sol
    receive() external payable {
        // Only accept BERA transfers from the Vault. This may happen when
        // joining a pool uses less than the full BERA value provided.
        // Any excess BERA will be refunded to this contract, and then forwarded to the original sender.
        _require(msg.sender == address(vault), Errors.ETH_TRANSFER);
    }

    /**
     * @notice Creates a weighted pool and joins it in a single transaction.
     * @dev Allows users to create a WBERA weighted pool and join it with either WBERA or BERA.
     * @param name Name of the pool
     * @param symbol Symbol of the pool
     * @param createPoolTokens Tokens to create the pool with
     * @param joinPoolTokens Tokens to join the pool with
     * @param normalizedWeights Normalized weights for the pool
     * @param rateProviders Rate providers for the pool
     * @param swapFeePercentage Swap fee percentage for the pool
     * @param amountsIn Amounts to join the pool with
     * @param owner Owner of the pool
     * @param salt Salt for the pool
     */
    function createAndJoinWeightedPool(
        string memory name,
        string memory symbol,
        IERC20[] memory createPoolTokens,
        IERC20[] memory joinPoolTokens,
        uint256[] memory normalizedWeights,
        IRateProvider[] memory rateProviders,
        uint256 swapFeePercentage,
        uint256[] memory amountsIn,
        address owner,
        bytes32 salt
    ) external payable returns (address pool) {
        pool = weightedPoolFactory.create(
            name,
            symbol,
            createPoolTokens,
            normalizedWeights,
            rateProviders,
            swapFeePercentage,
            owner,
            salt
        );

        emit WeightedPoolCreated(name, symbol, pool);

        // join pool with `joinPoolTokens` to allow users to join the `WBERA` pool with either WBERA or BERA
        // `amountsIn` is the amounts of tokens to join the pool with
        // According to the balancer SDK, amountsIn and maxAmountsIn are the same for weighted pools
        // https://github.com/balancer/balancer-sdk/blob/develop/balancer-js/src/modules/pools/
        // factory/weighted/weighted.factory.ts#L241
        _joinPool(pool, joinPoolTokens, amountsIn, amountsIn);
    }

    /**
     * @notice Creates a stable pool and joins it in a single transaction.
     * @dev Allows users to create a WBERA stable pool and join it with either WBERA or BERA,
     * depending on the value of `joinWBERAPoolWithBERA` flag and msg.value.
     * @param name Name of the pool
     * @param symbol Symbol of the pool
     * @param createPoolTokens Tokens to create the pool with
     * @param amplificationParameter Amplification parameter for the pool
     * @param rateProviders Rate providers for the pool
     * @param tokenRateCacheDurations Cache durations for the pool tokens
     * @param exemptFromYieldProtocolFeeFlag If true, exempt from yield protocol fee
     * @param swapFeePercentage Swap fee percentage for the pool
     * @param amountsIn Amounts to join the pool with
     * @param owner Owner of the pool
     * @param salt Salt for the pool
     * @param joinWBERAPoolWithBERA If true, join the WBERA pool with BERA.
     */
    function createAndJoinStablePool(
        string memory name,
        string memory symbol,
        IERC20[] memory createPoolTokens,
        uint256 amplificationParameter,
        IRateProvider[] memory rateProviders,
        uint256[] memory tokenRateCacheDurations,
        bool exemptFromYieldProtocolFeeFlag,
        uint256 swapFeePercentage,
        uint256[] memory amountsIn,
        address owner,
        bytes32 salt,
        bool joinWBERAPoolWithBERA // If true, join the WBERA pool with BERA
    ) external payable returns (address pool) {
        pool = composableStablePoolFactory.create(
            name,
            symbol,
            createPoolTokens,
            amplificationParameter,
            rateProviders,
            tokenRateCacheDurations,
            exemptFromYieldProtocolFeeFlag,
            swapFeePercentage,
            owner,
            salt
        );

        emit ComposableStablePoolCreated(name, symbol, pool);

        // Get the BPT index
        uint256 bptIndex = ComposableStablePool(pool).getBptIndex();

        // create a sorted array of tokens to join the pool by adding the BPT token in the list of tokens.
        IERC20[] memory joinPoolTokens = _insertSorted(createPoolTokens, IERC20(pool));

        // if `joinWBERAPoolWithBERA` flag is true, set the WBERA token to `0` address
        // to allow users to join the `WBERA` pool with BERA.
        if (joinWBERAPoolWithBERA) {
            uint256 wBERAIndex = _findTokenIndex(joinPoolTokens, wBERA);
            joinPoolTokens[wBERAIndex] = IERC20(0);
        }

        // cache the length of amountsIn
        uint256 amountsInLength = amountsIn.length + 1;
        // initialize amountsWithBpt and maxAmountsWithBpt
        uint256[] memory amountsInWithBpt = new uint256[](amountsInLength);
        uint256[] memory maxAmountsInWithBpt = new uint256[](amountsInLength);

        // amountsWithBpt contains `0` at bptIndex
        // maxAmountsWithBpt contains `_MAX_UINT256` at bptIndex
        for (uint256 i; i < amountsInLength; i++) {
            if (i < bptIndex) {
                amountsInWithBpt[i] = amountsIn[i];
                maxAmountsInWithBpt[i] = amountsIn[i];
            } else if (i == bptIndex) {
                amountsInWithBpt[i] = 0;
                maxAmountsInWithBpt[i] = _MAX_UINT256;
            } else {
                amountsInWithBpt[i] = amountsIn[i - 1];
                maxAmountsInWithBpt[i] = amountsIn[i - 1];
            }
        }

        // join pool with `joinPoolTokens` to allow users to join the `WBERA` pool with either WBERA or BERA
        // According to the balancer SDK, amountsIn and maxAmountsIn are different at BPT index for
        // ComposableStablePool hence we computed both above and passed them to joinPool.
        // https://github.com/balancer/balancer-sdk/blob/develop/balancer-js/src/modules/pools/
        // factory/composable-stable/composable-stable.factory.ts#L289
        _joinPool(pool, joinPoolTokens, amountsInWithBpt, maxAmountsInWithBpt);
    }

    /// @notice Joins a pool with the given amountsIn and maxAmountsIn.
    /// @dev Takes tokens as input to give users the flexibility to join WBERA pools either with WBERA or BERA.
    /// @dev msg.value is used to send BERA to the vault to support joining WBERA pools with BERA.
    /// @dev After `joinPool`, remaining BERA is refunded to this contract and then forwarded to the original sender.
    function _joinPool(
        address pool,
        IERC20[] memory tokens,
        uint256[] memory amountsIn,
        uint256[] memory maxAmountsIn
    ) internal {
        // `JoinKind` will be INIT for the first join, hence we encode 0 as the first element in the `userData`.
        bytes memory userData = abi.encode(0, amountsIn);
        bytes32 poolId = BasePool(pool).getPoolId();

        // uses "@balancer-labs/v2-solidity-utils/contracts/helpers/ERC20Helpers.sol";
        // for _asIAsset(tokens)
        IVault.JoinPoolRequest memory request = IVault.JoinPoolRequest({
            assets: _asIAsset(tokens),
            maxAmountsIn: maxAmountsIn,
            userData: userData,
            fromInternalBalance: false
        });
        // creator should approve tokens to vault before calling this function
        vault.joinPool{ value: msg.value }(poolId, msg.sender, msg.sender, request);
        // refund any remaining BERA to the original sender
        _refundBERA();
    }

    /// @notice Refunds any remaining BERA to the original sender after joinPool call.
    /// @dev Taken from relayer/BalancerRelayer.sol
    function _refundBERA() private {
        uint256 remainingBERA = address(this).balance;
        if (remainingBERA > 0) {
            msg.sender.sendValue(remainingBERA);
        }
    }
}
