// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {EnumerableSet} from
    "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

library DataTypes {
    // Struct for ERC20 token information.
    struct Token {
        address tokenAddress;
        uint256 amount;
    }

    /// @dev The address of the native asset as of EIP-7528.
    address public constant NATIVE_ASSET =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
}
