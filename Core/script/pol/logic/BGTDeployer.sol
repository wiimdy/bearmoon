// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { BGT } from "src/pol/BGT.sol";
import { Create2Deployer } from "src/base/Create2Deployer.sol";

abstract contract BGTDeployer is Create2Deployer {
    /// @notice Deploy BGT contract
    function deployBGT(address owner, uint256 bgtSalt) internal returns (address) {
        BGT bgt = BGT(deployWithCreate2(bgtSalt, type(BGT).creationCode));
        bgt.initialize(owner);

        require(keccak256(bytes(bgt.CLOCK_MODE())) == keccak256("mode=timestamp"), "BGT CLOCK_MODE is incorrect");

        return address(bgt);
    }
}
