// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;
import {IPandaStructs} from "./IPandaStructs.sol";

interface IPandaPool is IPandaStructs {
    function GRADUATION_THRESHOLD() external view returns(uint256);

    function pandaToken() external view returns (address);
    function baseToken() external view returns (address);
    function treasury() external view returns (address);
    function deployer() external view returns (address);
    function minTradeSize() external view returns (uint256);
    function vestingPeriod() external view returns (uint256);
    function poolFees() external view returns (PandaFees memory);
    function isBeraPair() external view returns (bool);

    function liquidity() external view returns (uint256);
    function sqrtPa() external view returns (uint256);
    function sqrtPb() external view returns (uint256);
    function sqrtP() external view returns (uint256);
    function pandaReserve() external view returns (uint256);
    function baseReserve() external view returns (uint256);
    function tokensInPool() external view returns (uint256);
    function totalRaiseWithFees() external view returns (uint256);
    function getCurrentPrice() external view returns (uint256);
    function remainingTokensInPool() external view returns (uint256);
    function tokensForLp() external view returns (uint256);

    function totalBalanceOf(address user) external view returns (uint256);
    function vestedBalanceOf(address user) external view returns (uint256);
    function claimableTokens(address user) external view returns (uint256);

    function getTokensInPool(uint256 sqrtPa, uint256 sqrtPb, uint256 totalTokens, uint16 graduationFee) external view returns (uint256);
    function getTotalRaise(uint256 sqrtPa, uint256 sqrtPb, uint256 tokensInPool) external view returns (uint256);
    function getTotalRaise() external view returns (uint256);

    function tokensBoughtInPool(address user) external view returns (uint256);
    function tokensClaimed(address user) external view returns (uint256);

    function claimTokens(address user) external returns (uint256);
    function moveLiquidity() external;
    function collectExcessTokens() external;
    function viewExcessTokens() external view returns (uint256 excessPandaTokens, uint256 excessBaseTokens);

    function getAmountInBuyRemainingTokens() external view returns (uint256 amountIn);
    function getAmountInSell(uint256 amountOut) external returns (uint256 amountIn, uint256 fee, uint256 sqrtP_new);
    function getAmountInBuy(uint256 amountOut) external view returns (uint256 amountIn, uint256 fee, uint256 sqrtP_new);
    function getAmountOutSell(uint256 amountIn) external view returns (uint256 amountOut, uint256 fee, uint256 sqrtP_new);
    function getAmountOutBuy(uint256 amountIn) external view returns (uint256 amountOut, uint256 fee, uint256 sqrtP_new);
    function graduated() external view returns (bool);
    function graduationTime() external view returns (uint256);
    function canClaimIncentive() external view returns (bool);

    function sellTokens(uint256 amountIn, uint256 minAmountOut, address to) external returns (uint256 amountOut, uint256 fee);
    function sellTokens(uint256 amountIn, uint256 minAmountOut, address from, address to) external returns (uint256 amountOut, uint256 fee);
    function sellTokensForBera(uint256 amountIn, uint256 minAmountOut, address to) external returns (uint256 amountOut, uint256 fee);
    function buyTokens(uint256 amountIn, uint256 minAmountOut, address to) external returns (uint256 amountOut, uint256 fee);
    function buyTokens(uint256 amountIn, uint256 minAmountOut, address from, address to) external returns (uint256 amountOut, uint256 fee);
    function buyTokensWithBera(uint256 minAmountOut, address to) external payable returns (uint256 amountOut, uint256 fee);

    function initializeIncentives(address _incentiveToken, uint256 _incentiveAmount, address _incentiveContract) external;
    function transferDeployerIncentive() external;

    function VERSION() external pure returns (string memory);
    function isPandaToken() external pure returns (bool);
    function getByteCode() external pure returns (bytes memory);

    function initializePool(
        address _pandaToken,
        PandaPoolParams calldata _pp,
        uint256 _totalTokens,
        address _deployer,
        bytes calldata _data
    ) external;
    event Sync(uint256 pandaReserve, uint256 baseReserve, uint256 sqrtPrice);
    event FeesCollected(uint256 baseTokenAmount);
    event TokensBought(address indexed buyer, uint256 amountIn, uint256 amountOut);
    event TokensSold(address indexed seller, uint256 amountIn, uint256 amountOut);
    event ExcessCollected(uint256 excessPandaTokens, uint256 excessBaseTokens);
    event LiquidityMoved(uint256 amountPanda, uint256 amountBase);
    event PoolInitialized(
        address pandaToken,
        address baseToken,
        uint256 sqrtPa,
        uint256 sqrtPb,
        uint256 tokensInPool,
        PandaFees poolFees,
        address deployer
    );
    event Swap(address indexed sender, uint amount0In, uint amount1In, uint amount0Out, uint amount1Out, address indexed to);

}