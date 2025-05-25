// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ERC20PresetMinterPauser} from "../vendors/ERC20PresetMinterPauser.sol";

/**
 * @title InfraredBGT
 * @notice This contract is the InfraredBGT token.
 */
contract InfraredBGT is ERC20PresetMinterPauser {
    /**
     * @notice Constructor for InfraredBGT
     * @param _admin The admin address to controll the roles of the contract
     * @param _minter The minter address of the contract
     * @param _pauser The pauser address of the contract
     * @param _burner The burner address of the contract
     */
    constructor(
        address _admin,
        address _minter,
        address _pauser,
        address _burner
    )
        ERC20PresetMinterPauser(
            "Infrared BGT",
            "iBGT",
            _admin,
            _minter,
            _pauser,
            _burner
        )
    {}
}
