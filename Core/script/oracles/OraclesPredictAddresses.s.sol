// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { BasePredictScript, console2 } from "../base/BasePredict.s.sol";
import { PythPriceOracle } from "src/extras/PythPriceOracle.sol";
import { PeggedPriceOracle } from "src/extras/PeggedPriceOracle.sol";
import { RootPriceOracle } from "src/extras/RootPriceOracle.sol";
import { PYTH_PRICE_ORACLE_SALT, PEGGED_PRICE_ORACLE_SALT, ROOT_PRICE_ORACLE_SALT } from "./OraclesSalts.sol";

contract OraclesPredictAddressesScript is BasePredictScript {
    function run() public pure {
        console2.log("Price oracles contracts will be deployed at: ");
        _predictProxyAddress("PythPriceOracle", type(PythPriceOracle).creationCode, 0, PYTH_PRICE_ORACLE_SALT);
        _predictAddress("PeggedPriceOracle", type(PeggedPriceOracle).creationCode, PEGGED_PRICE_ORACLE_SALT);
        _predictAddress("RootPriceOracle", type(RootPriceOracle).creationCode, ROOT_PRICE_ORACLE_SALT);
    }
}
