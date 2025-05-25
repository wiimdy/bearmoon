// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ISpotOracle} from "src/interfaces/core/spotOracles/ISpotOracle.sol";
import {ILiquidStabilityPool} from "src/interfaces/core/ILiquidStabilityPool.sol";

/**
 * @title LSPOracle
 * @dev Contract for managing and providing LSP token price rates in sNECT 
 */
contract LSPOracle is ISpotOracle {
    ILiquidStabilityPool private immutable lsp;
    
    // returns prce of sNECT
    constructor(address _lsp) {
        lsp = ILiquidStabilityPool(_lsp);
    }

    /// @notice Returns the current price of sNECT tokens
    /// @dev Price is calculated as totalAssets (NECT value of LSP holdings) divided by total supply of sNECT
    /// @return The price of sNECT in NECT terms (scaled to 1e18)
    function fetchPrice() external view returns (uint256) {
        uint256 totalSupply = lsp.totalSupply();
        return totalSupply == 0 ? 0 : lsp.totalAssets() * 1e18 / totalSupply;
    }

}
