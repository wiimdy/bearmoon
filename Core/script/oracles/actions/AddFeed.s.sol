// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { console2 } from "forge-std/Script.sol";
import { BaseScript } from "../../base/Base.s.sol";
import { PythPriceOracle } from "src/extras/PythPriceOracle.sol";
import { PYTH_PRICE_ORACLE_ADDRESS } from "../OraclesAddresses.sol";
import { USDT_ADDRESS, USDC_ADDRESS } from "../../misc/Addresses.sol";

/// @notice Creates a collateral vault for the given token.
contract AddFeedScript is BaseScript {
    bytes32 constant USDC_PYTH_FEED = bytes32(0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a);
    bytes32 constant USDT_PYTH_FEED = bytes32(0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b);

    function run() public virtual broadcast {
        require(USDC_PYTH_FEED != bytes32(0), "USDC_PYTH_FEED not set");
        require(USDT_PYTH_FEED != bytes32(0), "USDT_PYTH_FEED not set");
        _validateCode("PythPriceOracle", PYTH_PRICE_ORACLE_ADDRESS);
        PythPriceOracle pythPriceOracle = PythPriceOracle(PYTH_PRICE_ORACLE_ADDRESS);

        bool grantedRole = false;
        if (!pythPriceOracle.hasRole(pythPriceOracle.MANAGER_ROLE(), msg.sender)) {
            grantedRole = true;
            pythPriceOracle.grantRole(pythPriceOracle.MANAGER_ROLE(), msg.sender);
        }

        setPriceFeed("USDC", USDC_ADDRESS, USDC_PYTH_FEED);
        setPriceFeed("USDT", USDT_ADDRESS, USDT_PYTH_FEED);

        if (grantedRole) {
            pythPriceOracle.revokeRole(pythPriceOracle.MANAGER_ROLE(), msg.sender);
        }
    }

    /// @dev requires MANAGER_ROLE to be granted to msg.sender
    function setPriceFeed(string memory assetName, address asset, bytes32 feed) internal {
        PythPriceOracle pythPriceOracle = PythPriceOracle(PYTH_PRICE_ORACLE_ADDRESS);
        console2.log(string.concat("Setting feed for ", assetName, " (%s):"), asset);
        pythPriceOracle.setPriceFeed(asset, feed);
        require(pythPriceOracle.feeds(asset) == feed, "Failed to set feed");
        require(pythPriceOracle.priceAvailable(asset) == true, "Price not available");
        console2.log("Feed set to:");
        console2.logBytes32(feed);
        console2.log("-------");
    }
}
