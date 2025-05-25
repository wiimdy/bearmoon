// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title TransferHelper
/// @notice Contains helper methods for interacting with ERC20 tokens that do not consistently return true/false
/// @dev Forked from Uniswap solidity-lib + added condition to skip 0 value transfers
library TransferHelper {
    function safeApprove(
        address token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.approve.selector, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::safeApprove: approve failed'
        );
    }

    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        if (value == 0) return;
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::safeTransfer: transfer failed'
        );
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        if (value == 0) return;
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::transferFrom: transferFrom failed'
        );
    }

    function safeTransferETH(address to, uint256 value) internal {
        if (value == 0) return;
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, 'TransferHelper::safeTransferETH: ETH transfer failed');
    }
}