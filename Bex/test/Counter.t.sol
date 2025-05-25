// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "../contracts/vault/Vault.sol";

contract VaultTest is Test {
    Vault public vault;

    function setUp() public {
        vault = new Vault();
        // counter.setNumber(0);
    }

    function test_Increment() public {
        // counter.increment();
        // assertEq(counter.number(), 1);
    }

    function testFuzz_SetNumber(uint256 x) public {
        // counter.setNumber(x);
        // assertEq(counter.number(), x);
    }

    function test_Deposit() public {
        vault.deposit(100);
    }
    function test_flashLoan() public {
        vault.flashLoan(100);
    }
}
