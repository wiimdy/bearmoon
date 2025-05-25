// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

interface IPandaStructs {
    struct PandaFees {
        uint16 buyFee;
        uint16 sellFee;
        uint16 graduationFee;
        uint16 deployerFeeShare;
    }

    struct PandaPoolParams {
        address baseToken;
        uint256 sqrtPa;
        uint256 sqrtPb;
        uint256 vestingPeriod;
    }

}