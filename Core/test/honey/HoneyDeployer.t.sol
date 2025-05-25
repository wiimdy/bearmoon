// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";

import { IHoneyErrors } from "src/honey/IHoneyErrors.sol";
import { Honey } from "src/honey/Honey.sol";
import { HoneyDeployer } from "src/honey/HoneyDeployer.sol";
import { HoneyFactory } from "src/honey/HoneyFactory.sol";
import { HoneyFactoryReader } from "src/honey/HoneyFactoryReader.sol";
import { MockOracle } from "@mock/oracle/MockOracle.sol";

contract HoneyDeployerTest is Test {
    address private immutable GOVERNANCE = makeAddr("governance");
    address private immutable FEE_RECEIVER = makeAddr("feeReceiver");
    address private immutable POL_FEE_COLLECTOR = makeAddr("polFeeCollector");

    MockOracle oracle = new MockOracle();

    function test_HoneyDeployRevertGovernanceIsAddressZero() public {
        vm.expectRevert(abi.encodeWithSelector(IHoneyErrors.ZeroAddress.selector));
        new HoneyDeployer(address(0), POL_FEE_COLLECTOR, FEE_RECEIVER, 0, 1, 1, address(oracle));
    }

    function test_HoneyDeployRevertFeeReceiverIsAddressZero() public {
        vm.expectRevert(abi.encodeWithSelector(IHoneyErrors.ZeroAddress.selector));
        new HoneyDeployer(GOVERNANCE, address(0), POL_FEE_COLLECTOR, 0, 1, 1, address(oracle));
    }

    function test_HoneyDeployRevertPolFeeCollectorIsAddressZero() public {
        vm.expectRevert(abi.encodeWithSelector(IHoneyErrors.ZeroAddress.selector));
        new HoneyDeployer(GOVERNANCE, address(0), FEE_RECEIVER, 0, 1, 1, address(oracle));
    }

    function test_HoneyDeployer() public {
        HoneyDeployer deployer =
            new HoneyDeployer(GOVERNANCE, POL_FEE_COLLECTOR, FEE_RECEIVER, 0, 1, 1, address(oracle));
        Honey honey = deployer.honey();
        HoneyFactory factory = deployer.honeyFactory();
        HoneyFactoryReader factoryReader = deployer.honeyFactoryReader();

        assertEq(honey.factory(), address(factory));
        assertTrue(honey.hasRole(factory.DEFAULT_ADMIN_ROLE(), GOVERNANCE));

        assertEq(address(factory.honey()), address(honey));
        assertTrue(factory.hasRole(factory.DEFAULT_ADMIN_ROLE(), GOVERNANCE));
        assertEq(factory.feeReceiver(), FEE_RECEIVER);
        assertEq(factory.polFeeCollector(), POL_FEE_COLLECTOR);
        assertEq(address(factory), address(factoryReader.honeyFactory()));
    }
}
