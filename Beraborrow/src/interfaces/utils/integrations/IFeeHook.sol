// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

interface IFeeHook {
    enum Action {
        DEPOSIT,
        MINT,
        WITHDRAW,
        REDEEM
    }

    function calcFee(address caller, address stable, uint amount, Action action) external view returns (uint feeInBP);
}