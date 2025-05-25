// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

interface ISpotOracle {
    function fetchPrice() external view returns (uint);
}