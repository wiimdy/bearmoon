// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

interface IWBera {
    function deposit() external payable;
    function withdraw(uint wad) external;
    function transfer(address dst, uint256 wad) external returns (bool);
    function approve(address to, uint amount) external returns (bool);
}
