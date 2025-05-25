// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IWETH} from "../interfaces/exchange/IWETH.sol";
import {ISwapRouter} from "../interfaces/ISwapRouter.sol";
import {IVault} from "../interfaces/IVault.sol";

/**
 * @title IZapper Interface
 * @notice Interface for contracts that enable deposits/withdrawals from vaults using any token
 * @dev Implements functionality for converting tokens and interacting with vaults
 */
interface IZapper {
    // Structs
    /**
     * @notice Struct to track leftover tokens returned to users
     * @param tokens Address of the token
     * @param amounts Amount of tokens returned
     */
    struct ReturnedAsset {
        address tokens;
        uint256 amounts;
    }

    // Errors
    /// @notice Thrown when a non-governance address calls a governance-only function
    error NotGovernance();
    /// @notice Thrown when a zero address is provided
    error ZeroAddress();
    /// @notice Thrown when input amount is below minimum required
    error InsufficientInputAmount(
        address token,
        uint256 provided,
        uint256 minimum
    );
    /// @notice Thrown when token approval is missing
    error TokenNotApproved();
    /// @notice Thrown when ETH transfer fails
    error ETHTransferFailed();
    /// @notice Thrown when output amount is below minimum required
    error InsufficientOutputAmount(
        address token,
        uint256 received,
        uint256 minimum
    );
    /// @notice Thrown when fee percentage is too high
    error FeeTooHigh(uint16 fee, uint16 maxFee);
    /// @notice Thrown when total ratio is zero
    error TotalRatioZero();

    // Events
    /// @notice Emitted when swap router address is updated
    /// @param newSwapRouter Address of the new swap router
    /// @param oldSwapRouter Address of the previous swap router
    event SwapRouterChanged(
        address indexed newSwapRouter,
        address indexed oldSwapRouter
    );
    /// @notice Emitted when stablecoin address is updated
    /// @param newStableCoin Address of the new stablecoin
    /// @param oldStableCoin Address of the previous stablecoin
    event StableCoinChanged(
        address indexed newStableCoin,
        address indexed oldStableCoin
    );
    /// @notice Emitted when governance address is updated
    /// @param newGovernance Address of the new governance
    /// @param oldGovernance Address of the previous governance
    event GovernanceChanged(
        address indexed newGovernance,
        address indexed oldGovernance
    );
    /// @notice Emitted when lp router address is updated
    /// @param newLpRouter Address of the new lp router
    /// @param oldLpRouter Address of the previous lp router
    event LpRouterChanged(
        address indexed newLpRouter,
        address indexed oldLpRouter
    );
    /// @notice Emitted when zapIn fee is updated
    /// @param oldFee Previous fee percentage in basis points
    /// @param newFee New fee percentage in basis points
    event ZapInFeeChanged(uint16 oldFee, uint16 newFee);
    /// @notice Emitted when zapOut fee is updated
    /// @param oldFee Previous fee percentage in basis points
    /// @param newFee New fee percentage in basis points
    event ZapOutFeeChanged(uint16 oldFee, uint16 newFee);
    /// @notice Emitted when fee recipient is updated
    /// @param oldRecipient Address of the previous fee recipient
    /// @param newRecipient Address of the new fee recipient
    event FeeRecipientChanged(
        address indexed oldRecipient,
        address indexed newRecipient
    );
    /// @notice Emitted when tokens are deposited into a vault
    /// @param user Address of the depositor
    /// @param vault Address of the target vault
    /// @param tokenIn Address of the input token
    /// @param tokenInAmount Amount of input tokens
    /// @param assetsIn Amount of assets deposited
    /// @param shares Amount of vault shares received
    /// @param fee Amount of fee paid
    /// @param returnedAssets Array of any remaining tokens returned to caller
    event ZapIn(
        address indexed user,
        address indexed vault,
        address tokenIn,
        uint256 tokenInAmount,
        uint256 assetsIn,
        uint256 shares,
        uint256 fee,
        ReturnedAsset[] returnedAssets
    );
    /// @notice Emitted when tokens are withdrawn from a vault
    /// @param user Address of the withdrawer
    /// @param vault Address of the source vault
    /// @param tokenOut Address of the output token
    /// @param tokenOutAmount Amount of output tokens
    /// @param assetsOut Amount of assets withdrawn
    /// @param shares Amount of vault shares withdrawn
    /// @param fee Amount of fee paid
    /// @param returnedAssets Array of any remaining tokens returned to caller
    event ZapOut(
        address indexed user,
        address indexed vault,
        address tokenOut,
        uint256 tokenOutAmount,
        uint256 assetsOut,
        uint256 shares,
        uint256 fee,
        ReturnedAsset[] returnedAssets
    );

    /**
     * @notice Converts input token balance of address(this) to vault's desired token
     * @param vault The vault to deposit into
     * @param tokenIn The input token to convert
     * @return assetsOut Amount of converted assets
     * @return returnedAssets Array of any remaining tokens returned to caller
     */
    function swapToAssets(
        address vault,
        address tokenIn,
        uint256 tokenInAmount,
        address recipient
    )
        external
        returns (uint256 assetsOut, ReturnedAsset[] memory returnedAssets);

    /**
     * @notice Converts vault's desired token balance to output token
     * @param vault The vault to withdraw from
     * @param tokenOut The output token to convert
     * @return tokenOutAmount Amount of converted tokens
     * @return returnedAssets Array of any remaining tokens returned to caller
     */
    function swapFromAssets(
        address vault,
        address tokenOut,
        uint256 assetsInAmount,
        address recipient
    )
        external
        returns (uint256 tokenOutAmount, ReturnedAsset[] memory returnedAssets);

    /// @notice Deposits tokens into a vault after converting them if necessary
    /// @param vault Target vault
    /// @param tokenIn Input token address
    /// @param tokenInAmount Amount of input tokens
    /// @param minShares Minimum amount of vault shares to receive
    /// @return shares Number of vault shares received
    /// @return returnedAssets Array of any remaining tokens returned to caller
    function zapIn(
        IVault vault,
        address tokenIn,
        uint256 tokenInAmount,
        uint256 minShares
    )
        external
        payable
        returns (uint256 shares, ReturnedAsset[] memory returnedAssets);

    /// @notice Withdraws from vault and converts to desired token
    /// @param vault Source vault
    /// @param withdrawAmount Amount of vault shares to withdraw
    /// @param tokenOut Desired output token
    /// @param minTokenOutAmount Minimum amount of desired tokens to receive
    /// @return tokenOutAmount Amount of output tokens received
    /// @return returnedAssets Array of any remaining tokens returned to caller
    function zapOut(
        IVault vault,
        uint256 withdrawAmount,
        address tokenOut,
        uint256 minTokenOutAmount
    )
        external
        returns (uint256 tokenOutAmount, ReturnedAsset[] memory returnedAssets);
}
