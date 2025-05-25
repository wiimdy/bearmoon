// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract BrimeDen is Ownable2Step {

    struct Call3 {
        address target;
        bool allowFailure;
        bytes callData;
    }

    struct Call3Value {
        address target;
        bool allowFailure;
        uint256 value;
        bytes callData;
    }

    struct Result {
        bool success;
        bytes returnData;
    }

    constructor(address _admin) {
        // Make sure the contract is initialized with the correct admin
        require(_admin == owner());
    }

    /// @dev Multicall function based on:
    /// https://github.com/mds1/multicall/blob/cbfc277f49722da6a9d9c0dd8c8c67fe13260558/src/Multicall3.sol#L125
    /// @notice Aggregate calls, ensuring each returns success if required
    /// @param calls An array of Call3 structs
    /// @return returnData An array of Result structs
    function multicall3(Call3[] calldata calls) public onlyOwner returns (Result[] memory returnData) {
        uint256 length = calls.length;
        returnData = new Result[](length);
        Call3 calldata calli;
        for (uint256 i; i < length;) {
            Result memory result = returnData[i];
            calli = calls[i];
            (result.success, result.returnData) = calli.target.call(calli.callData);
            assembly {
                // Revert if the call fails and failure is not allowed
                // `allowFailure := calldataload(add(calli, 0x20))` and `success := mload(result)`
                if iszero(or(calldataload(add(calli, 0x20)), mload(result))) {
                    // set "Error(string)" signature: bytes32(bytes4(keccak256("Error(string)")))
                    mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                    // set data offset
                    mstore(0x04, 0x0000000000000000000000000000000000000000000000000000000000000020)
                    // set length of revert string
                    mstore(0x24, 0x0000000000000000000000000000000000000000000000000000000000000017)
                    // set revert string: bytes32(abi.encodePacked("Multicall3: call failed"))
                    mstore(0x44, 0x4d756c746963616c6c333a2063616c6c206661696c6564000000000000000000)
                    revert(0x00, 0x64)
                }
            }
            unchecked { ++i; }
        }
    }

    /// @notice Aggregate calls with a msg value
    /// @notice Reverts if msg.value is less than the sum of the call values
    /// @param calls An array of Call3Value structs
    /// @return returnData An array of Result structs
    function multicall3Value(Call3Value[] calldata calls) public payable onlyOwner returns (Result[] memory returnData) {
        uint256 valAccumulator;
        uint256 length = calls.length;
        returnData = new Result[](length);
        Call3Value calldata calli;
        for (uint256 i; i < length;) {
            Result memory result = returnData[i];
            calli = calls[i];
            uint256 val = calli.value;
            // Humanity will be a Type V Kardashev Civilization before this overflows - andreas
            // ~ 10^25 Wei in existence << ~ 10^76 size uint fits in a uint256
            unchecked { valAccumulator += val; }
            (result.success, result.returnData) = calli.target.call{value: val}(calli.callData);
            assembly {
                // Revert if the call fails and failure is not allowed
                // `allowFailure := calldataload(add(calli, 0x20))` and `success := mload(result)`
                if iszero(or(calldataload(add(calli, 0x20)), mload(result))) {
                    // set "Error(string)" signature: bytes32(bytes4(keccak256("Error(string)")))
                    mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                    // set data offset
                    mstore(0x04, 0x0000000000000000000000000000000000000000000000000000000000000020)
                    // set length of revert string
                    mstore(0x24, 0x0000000000000000000000000000000000000000000000000000000000000017)
                    // set revert string: bytes32(abi.encodePacked("Multicall3: call failed"))
                    mstore(0x44, 0x4d756c746963616c6c333a2063616c6c206661696c6564000000000000000000)
                    revert(0x00, 0x84)
                }
            }
            unchecked { ++i; }
        }
        // Finally, make sure the msg.value = SUM(call[0...i].value)
        require(msg.value == valAccumulator, "BrimeDen: value mismatch");
    }

    /// @dev Failed sub-call's part of msg.value will be permanently frozen with BrimeDen when the sub-call have allowFailure == true.
    function sendLockedBera(address _to, uint256 _amount) external onlyOwner {
        (bool success, ) = _to.call{value: _amount}("");
        require(success, "BrimeDen: sendLockedBera failed");
    }
}