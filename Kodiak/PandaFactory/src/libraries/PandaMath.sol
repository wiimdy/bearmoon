// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";


library PandaMath {
    using Math for uint256;

    uint256 internal constant PRICE_SCALE = 1e36;
    uint256 internal constant FEE_SCALE = 10000;

    uint256 internal constant MAX_FEE = 1000;
    uint256 internal constant MAX_DEPLOYER_FEE_SHARE = 1000;

    //Helper function to get the sqrtP of the token, given scaledPrice = baseAmount * PRICE_SCALE / pandaAmount
    ///@param scaledPrice: price of the token specified as baseToken per 1e36 (PRICE_SCALE) pandaToken
    ///@dev For example, to get sqrtP associated with a price of 0.00001, pass in 0.00001 * 1e18 here
    function getSqrtP(uint256 scaledPrice) internal pure returns (uint256) {
        return Math.sqrt(scaledPrice);
    }

    //Get tokens in pool
    //Calculated deterministically based on:
    //totalAmountRaised / tokensForLp (i.e. the price when we move to the dex) == sqrtPb **2 (i.e. the ending price)
    //Calculated:
    //uint raiseAmount = tokensInPool*sqrtPa*sqrtPb/PRICE_SCALE;
    //uint raiseAmountWithFee = raiseAmount - raiseAmount * graduationFee / FEE_SCALE;
    //uint dexPrice = raiseAmountWithFee * PRICE_SCALE / (totalTokens - tokensInPool);
    //Solve for tokensInPool such that dexPrice == sqrtPb**2;
    function getTokensInPool(uint256 sqrtPa, uint256 sqrtPb, uint256 totalTokens, uint16 graduationFee) internal pure returns (uint256) {
        uint256 denom = sqrtPa + sqrtPb - sqrtPa * graduationFee / FEE_SCALE;
        return totalTokens.mulDiv(sqrtPb, denom, Math.Rounding.Up);
    }

    //Helper function to get the total amount of base tokens needed to graduate the pool, given pool parameters
    function getTotalRaise(uint256 sqrtPa, uint256 sqrtPb, uint256 tokensInPool) internal pure returns (uint256) {
        return tokensInPool.mulDiv(sqrtPa * sqrtPb, PRICE_SCALE, Math.Rounding.Up);
    }

    //Calculate the V2 dex pair address for the token, based on the information in the factory
    function getDexPair(address pandaToken, address baseToken, address v2Factory, bytes32 initCodeHash) internal pure returns (address pair) {
        require(baseToken != pandaToken, 'PandaFactory: IDENTICAL_ADDRESSES');
        require(baseToken != address(0) && pandaToken != address(0), 'PandaFactory: ZERO_ADDRESS');
        (address token0, address token1) = baseToken < pandaToken ? (baseToken, pandaToken) : (pandaToken, baseToken);
        pair = address(uint160(uint(keccak256(abi.encodePacked(
            hex'ff',
            v2Factory,
            keccak256(abi.encodePacked(token0, token1)),
            initCodeHash
        )))));
    }


    //MATH for PandaPool.sol
    //TODO: migrate it here with helper functions
    //In general, we follow UniV3 style math

    //LIQUIDITY:
    //Source: https://atiselsts.github.io/pdfs/uniswap-v3-liquidity-math.pdf
    //See Page 2, Equation (5): case where P <= Pa (i.e. Price = startingPrice, as is the case when pool is started)
    // L = x * (sqrt(Pa) - sqrt(Pb)) / (sqrt(Pb) - sqrt(Pa))
    // In our case, x = tokensForLp, sqrt(Pa) = sqrtPa, sqrt(Pb) = sqrtPb
    // L = tokensForLp * (sqrtPa - sqrtPb) / (sqrtPb - sqrtPa)
    // In solidity: liquidity = tokensInPool.mulDiv(sqrtPa * sqrtPb, sqrtPb - sqrtPa, Math.Rounding.Down);
    // Rounding up vs down doesn't matter here, chosen down to be explicit.
    // This is a constant and calculated once upon initialization.

    // Now we can deterministically calculate:
    // - Given PandaReserve: corresponding baseReserve, and price (sqrtP)
    // - Given BaseReserve: corresponding pandaReserve, and price (sqrtP)

    // PandaPool also follows the following property:
    // The average price paid to buy all the tokens in a PandaPool = GEOMEAN(Pa, Pb) = sqrtPa * sqrtPb

    //CALCULATING NEW PRICE:
    //Given pandaReserve_new
    //sqrtP_new = liquidity * sqrtPb / (pandaReserve_new * sqrtPb + liquidity)

    //Derivation:
    //Source: https://atiselsts.github.io/pdfs/uniswap-v3-liquidity-math.pdf.
    //Start with Page 3, Equation 11:
    //x = L * (sqrtPb - sqrtP) / (sqrtP * sqrtPb)
    //x * sqrtPb * sqrtP = L * sqrtPb - L * sqrtP
    //x * sqrtPb * sqrtP + L * sqrtP = L * sqrtPb
    //sqrtP * (x * sqrtPb + L) = L * sqrtPb
    //sqrtP = L * sqrtPb / (x * sqrtPb + L)

    //Given baseReserve_new
    //sqrtP_new = sqrtPa + baseReserve_new * PRICE_SCALE / liquidity
    //Derivation:
    //Source: https://atiselsts.github.io/pdfs/uniswap-v3-liquidity-math.pdf.
    //Start with Page 3, Equation 12:
    //y = L * (sqrtP - sqrtPa)
    //y = L*sqrtP - L*sqrtPa
    //y + L*sqrtPa = L*sqrtP
    //sqrtP = (y + L*sqrtPa) / L
    //sqrtP = y/L + sqrtPa
    //Note: we need to adjust by the PRICE_SCALE

    //ROUNDING:
    //In general we use OZ muldiv to avoid risk of overflow
    //When we calculate new price, round up when buying, round down when selling
    //When we calculate new reserves, always round up (in favor of the liquidity pool)
}
