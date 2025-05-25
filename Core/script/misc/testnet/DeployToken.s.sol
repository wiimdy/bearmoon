// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { console2 } from "forge-std/console2.sol";
import { BaseScript } from "../../base/Base.s.sol";
import { DAI } from "./tokens/DAI.sol";
import { USDT } from "./tokens/USDT.sol";
import { USDC } from "./tokens/USDC.sol";

contract DeployTokenScript is BaseScript {
    function run() public pure {
        console2.log("Please run specific task");
    }

    function deployDAI() public broadcast {
        address dai = address(new DAI());
        console2.log("DAI deployed at: ", dai);
    }

    function deployUSDT() public broadcast {
        address usdt = address(new USDT());
        console2.log("USDT deployed at: ", usdt);
    }

    function deployUSDC() public broadcast {
        address usdc = address(new USDC());
        console2.log("USDC deployed at: ", usdc);
    }
}
