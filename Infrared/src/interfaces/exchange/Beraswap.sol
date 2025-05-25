// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IAsset {
    // solhint-disable-previous-line no-empty-blocks
}

interface IBeraVault {
    struct SingleSwap {
        bytes32 poolId;
        SwapKind kind;
        IAsset assetIn;
        IAsset assetOut;
        uint256 amount;
        bytes userData;
    }

    struct BatchSwapStep {
        bytes32 poolId;
        uint256 assetInIndex;
        uint256 assetOutIndex;
        uint256 amount;
        bytes userData;
    }

    struct FundManagement {
        address sender;
        bool fromInternalBalance;
        address payable recipient;
        bool toInternalBalance;
    }

    struct JoinPoolRequest {
        IAsset[] assets;
        uint256[] maxAmountsIn;
        bytes userData;
        bool fromInternalBalance;
    }

    struct ExitPoolRequest {
        IAsset[] assets;
        uint256[] minAmountsOut;
        bytes userData;
        bool toInternalBalance;
    }

    enum PoolSpecialization {
        GENERAL,
        MINIMAL_SWAP_INFO,
        TWO_TOKEN
    }

    enum SwapKind {
        GIVEN_IN,
        GIVEN_OUT
    }

    function getPoolTokens(
        bytes32 poolId
    )
        external
        view
        returns (
            IERC20[] memory tokens,
            uint256[] memory balances,
            uint256 lastChangeBlock
        );

    function getPool(
        bytes32 poolId
    ) external view returns (address, PoolSpecialization);

    function swap(
        SingleSwap memory singleSwap,
        FundManagement memory funds,
        uint256 limit,
        uint256 deadline
    ) external returns (uint256 amountCalculated);

    function batchSwap(
        SwapKind kind,
        BatchSwapStep[] memory swaps,
        IAsset[] memory assets,
        FundManagement memory funds,
        int256[] memory limits,
        uint256 deadline
    ) external payable returns (int256[] memory);

    function joinPool(
        bytes32 poolId,
        address sender,
        address recipient,
        JoinPoolRequest memory request
    ) external payable;

    function exitPool(
        bytes32 poolId,
        address sender,
        address payable recipient,
        ExitPoolRequest memory request
    ) external;
}

interface IBeraPool {
    function getPoolId() external view returns (bytes32);

    function getVault() external view returns (address);

    function balanceOf(address account) external view returns (uint256);
}
