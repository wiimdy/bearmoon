// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IBerachainBGT} from "src/interfaces/IBerachainBGT.sol";
import {IInfraredBGT} from "src/interfaces/IInfraredBGT.sol";
import {Errors} from "src/utils/Errors.sol";
import {ValidatorTypes} from "./ValidatorTypes.sol";
import {IInfraredDistributor} from "src/interfaces/IInfraredDistributor.sol";
import {EnumerableSet} from
    "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// @title ValidatorManagerLib
/// @notice Library for managing validator storage
/// @dev This library is used by the Infrared contract for:
/// - Adding and removing validators (to the set of validators and distributor contract)
/// - Queuing/Activating Boosts and Drop/Activate Boosts in BGT contract: https://github.com/berachain/contracts-monorepo/blob/main/src/pol/BGT.sol
/// - Getting the number of validators
/// - Checking if validator is an Infrared validator
/// @dev Ownership of Operator rewards is tied to the number of validators an operator has, which should be linear to their operating costs hence share of fees.
/// ie if an operator has 10 validators and total validators is 100, they should receive 10% of the fees even if Effective Balances are not super equal.
library ValidatorManagerLib {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /// @notice Storage structure for validator storage
    /// @dev This structure is used to store validator IDs and public keys
    /// @param validatorIds Set of validator IDs which are keccak256 hashes of public keys.
    /// @param validatorPubkeys Maps validator ID to public key
    struct ValidatorStorage {
        EnumerableSet.Bytes32Set validatorIds; // Set of validator IDs
        mapping(bytes32 => bytes) validatorPubkeys; // Maps validator ID to public key
    }

    /// @notice Checks if a validator is an Infrared validator, ie if the validator ID is in the set of validator IDs
    /// @param $ Storage pinter for validator storage
    /// @param pubkey The CL pubkey of validator
    function isValidator(ValidatorStorage storage $, bytes memory pubkey)
        external
        view
        returns (bool)
    {
        return $.validatorIds.contains(keccak256(pubkey));
    }

    /// @notice Gets the validator ID for associated CL pubkey
    /// @param pubkey The CL pubkey of validator
    function _getValidatorId(bytes memory pubkey)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(pubkey);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       VALIDATOR CRUD                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Adds validator to the set of validators, and maps the validator ID to the public key.
    /// @notice Also adds the validator to a public key set in the distributor contract, for receiving operator rewards. (ie Commissions for running nodeds).address
    /// @param $ Storage pointer to the validator storage
    /// @param distributor address of the distributor contract
    /// @param _validators array of Validator structs containing the CL public key and address of the validator and their associated fee collecting address
    function addValidators(
        ValidatorStorage storage $,
        address distributor,
        ValidatorTypes.Validator[] memory _validators
    ) external {
        for (uint256 i = 0; i < _validators.length; i++) {
            ValidatorTypes.Validator memory v = _validators[i];
            if (v.addr == address(0)) revert Errors.ZeroAddress();
            bytes32 id = _getValidatorId(v.pubkey);
            if ($.validatorIds.contains(id)) {
                revert Errors.InvalidValidator();
            }
            $.validatorIds.add(id);
            $.validatorPubkeys[id] = v.pubkey;

            // add CL pubkey to EVM address mapping in distributor (for operator rewards)
            IInfraredDistributor(distributor).add(v.pubkey, v.addr);
        }
    }

    /// @notice Removes validators from the set of validators and also removes the validator from the distributor contract.
    function removeValidators(
        ValidatorStorage storage $,
        address distributor,
        bytes[] memory _pubkeys
    ) external {
        for (uint256 i = 0; i < _pubkeys.length; i++) {
            bytes memory pubkey = _pubkeys[i];
            bytes32 id = keccak256(pubkey);
            if (!$.validatorIds.contains(id)) {
                revert Errors.InvalidValidator();
            }
            $.validatorIds.remove(id);
            delete $.validatorPubkeys[id];

            // remove pubkey from those elligible for iBGT rewards
            IInfraredDistributor(distributor).remove(pubkey);
        }
    }

    /// @notice Replaces a validator in the set of validators and also updates the validator in the distributor contract.
    /// @param $ Storage pointer to the validator storage
    /// @param distributor address of the distributor contract
    /// @param _current Public key of the current validator
    /// @param _new Public key of the new validator
    function replaceValidator(
        ValidatorStorage storage $,
        address distributor,
        bytes calldata _current,
        bytes calldata _new
    ) external {
        bytes32 id = keccak256(_current);
        if (!$.validatorIds.contains(id)) {
            revert Errors.InvalidValidator();
        }
        address _addr = _getValidatorAddress(distributor, _current);

        // remove current from set
        $.validatorIds.remove(id);
        delete $.validatorPubkeys[id];
        IInfraredDistributor(distributor).remove(_current);

        // add new to set
        id = _getValidatorId(_new);
        if ($.validatorIds.contains(id)) {
            revert Errors.InvalidValidator();
        }
        $.validatorIds.add(id);
        $.validatorPubkeys[id] = _new;

        IInfraredDistributor(distributor).add(_new, _addr);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   BOOST MANAGMENT                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Queues boosts for validators in the BGT smart contract
    /// @param $ Storage pointer to the validator storage
    /// @param bgt address of the BGT contract
    /// @param _pubkeys array of public keys of validators
    /// @param _amts array of amounts of boosts to queue
    /// @dev The sum of the boosts must be less than or equal to the total supply of iBGT
    function queueBoosts(
        ValidatorStorage storage $,
        address bgt,
        address ibgt,
        bytes[] memory _pubkeys,
        uint128[] memory _amts
    ) external {
        if (_pubkeys.length != _amts.length) {
            revert Errors.InvalidArrayLength();
        }
        // check if sum of boosts is less than or equal to totalSpupply of iBGT
        uint256 _totalBoosts = 0;

        for (uint256 i = 0; i < _pubkeys.length; i++) {
            if (_amts[i] == 0) revert Errors.ZeroAmount();
            _totalBoosts += _amts[i];
        }

        // make that new boost plus the existing boosts and queued boosts
        // are less than or equal to the total supply of iBGT to ensure that `harvestBase` can be called without reverting.
        if (
            _totalBoosts
                > IInfraredBGT(ibgt).totalSupply()
                    - (
                        IBerachainBGT(bgt).boosts(address(this))
                            + IBerachainBGT(bgt).queuedBoost(address(this))
                    )
        ) {
            revert Errors.BoostExceedsSupply();
        }
        // check if all pubkeys are valid
        for (uint256 i = 0; i < _pubkeys.length; i++) {
            IBerachainBGT(bgt).queueBoost(_pubkeys[i], _amts[i]);
        }
    }

    /// @notice Cancels boosts for validators in the BGT smart contract before they are activated
    /// @param bgt address of the BGT contract
    /// @param _pubkeys array of public keys of validators
    /// @param _amts array of amounts of boosts to cancel
    function cancelBoosts(
        address bgt,
        bytes[] memory _pubkeys,
        uint128[] memory _amts
    ) external {
        if (_pubkeys.length != _amts.length) {
            revert Errors.InvalidArrayLength();
        }
        for (uint256 i = 0; i < _pubkeys.length; i++) {
            bytes memory pubkey = _pubkeys[i];

            // We don't need to verify the validator exists to cancel its boosts, this is a trusted function
            // and the validator could already be exited

            if (_amts[i] == 0) revert Errors.ZeroAmount();
            IBerachainBGT(bgt).cancelBoost(pubkey, _amts[i]);
        }
    }

    /// @notice Activates boosts for validators in the BGT smart contract
    /// @param $ Storage pointer to the validator storage
    /// @param bgt address of the BGT contract
    /// @param _pubkeys array of public keys of validators
    function activateBoosts(
        ValidatorStorage storage $,
        address bgt,
        bytes[] memory _pubkeys
    ) external {
        for (uint256 i = 0; i < _pubkeys.length; i++) {
            IBerachainBGT(bgt).activateBoost(address(this), _pubkeys[i]);
        }
    }

    /// @notice Queues to drop the boosts for validators in the BGT smart contract
    /// @param bgt address of the BGT contract
    /// @param _pubkeys array of public keys of validators
    /// @param _amts array of amounts of boosts to drop
    function queueDropBoosts(
        address bgt,
        bytes[] memory _pubkeys,
        uint128[] memory _amts
    ) external {
        if (_pubkeys.length != _amts.length) {
            revert Errors.InvalidArrayLength();
        }
        for (uint256 i = 0; i < _pubkeys.length; i++) {
            // We don't need to verify the validator exists to drop its boosts, this is a trusted function
            // and the validator could already be exited

            if (_amts[i] == 0) revert Errors.ZeroAmount();
            IBerachainBGT(bgt).queueDropBoost(_pubkeys[i], _amts[i]);
        }
    }

    /// @notice Cancels drop boosts for validators in the BGT smart contract before they are activated
    /// @param $ Storage pointer to the validator storage
    /// @param bgt address of the BGT contract
    /// @param _pubkeys array of public keys of validators
    /// @param _amts array of amounts of boosts to cancel
    function cancelDropBoosts(
        ValidatorStorage storage $,
        address bgt,
        bytes[] memory _pubkeys,
        uint128[] memory _amts
    ) external {
        if (_pubkeys.length != _amts.length) {
            revert Errors.InvalidArrayLength();
        }
        for (uint256 i = 0; i < _pubkeys.length; i++) {
            if (_amts[i] == 0) revert Errors.ZeroAmount();
            IBerachainBGT(bgt).cancelDropBoost(_pubkeys[i], _amts[i]);
        }
    }

    /// @notice Activates drop boosts for validators in the BGT smart contract
    /// @param bgt address of the BGT contract
    /// @param _pubkeys array of public keys of validators
    function dropBoosts(address bgt, bytes[] memory _pubkeys) external {
        for (uint256 i = 0; i < _pubkeys.length; i++) {
            // We don't need to verify the validator exists to drop its boosts, this is a trusted function
            // and the validator could already be exited

            IBerachainBGT(bgt).dropBoost(address(this), _pubkeys[i]);
        }
    }

    /// @notice Returns the list of validators in the validator storage
    /// @param $ Storage pointer to the validator storage
    /// @param distributor address of the distributor contract
    /// @return validators array of Validator structs containing the CL public key and address of the validators fee collecting address
    function infraredValidators(ValidatorStorage storage $, address distributor)
        external
        view
        returns (ValidatorTypes.Validator[] memory validators)
    {
        bytes32[] memory ids = $.validatorIds.values();
        uint256 len = ids.length;
        validators = new ValidatorTypes.Validator[](len);

        for (uint256 i = 0; i < len; i++) {
            bytes memory pubkey = $.validatorPubkeys[ids[i]];
            validators[i] = ValidatorTypes.Validator({
                pubkey: pubkey,
                addr: _getValidatorAddress(distributor, pubkey)
            });
        }
    }

    /// @notice Returns the number of validators in the validator storage
    /// @param $ Storage pointer to the validator storage
    /// @return number of validators
    function numInfraredValidators(ValidatorStorage storage $)
        external
        view
        returns (uint256)
    {
        return $.validatorIds.length();
    }

    /// @notice helper function to get the vlaidator fee collecting address via the CL pubkey
    /// @param distributor address of the distributor contract
    /// @param pubkey CL pubkey of the validator
    /// @return address of the validator fee collecting address
    function _getValidatorAddress(address distributor, bytes memory pubkey)
        internal
        view
        returns (address)
    {
        return IInfraredDistributor(distributor).getValidator(pubkey);
    }
}
