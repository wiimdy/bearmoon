// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {Errors, Upgradeable} from "src/utils/Upgradeable.sol";
import {IInfraredBERA} from "src/interfaces/IInfraredBERA.sol";
import {IInfraredBERAFeeReceivor} from
    "src/interfaces/IInfraredBERAFeeReceivor.sol";
import {IInfrared} from "src/interfaces/IInfrared.sol";
import {InfraredBERAConstants} from "./InfraredBERAConstants.sol";

/// @title InfraredBERAFeeReceivor
/// @notice Receivor for fees from InfraredBERA from tips and share of the proof-of-liquidity incentive system.
/// @dev Validators need to set this address as their coinbase(fee_recepient on most clients).
contract InfraredBERAFeeReceivor is Upgradeable, IInfraredBERAFeeReceivor {
    /// @notice The address of the `InfraredBERA.sol` contract.
    address public InfraredBERA;

    /// @notice The `Infrared.sol` contract address.
    IInfrared public infrared;

    /// @notice Accumulated protocol fees in contract to be claimed.
    uint256 public shareholderFees;

    /// @notice Reserve storage slots for future upgrades for safety
    uint256[40] private __gap;

    /// @notice Initializer function (replaces constructor)
    /// @param _gov Address for admin / gov to upgrade
    /// @param _keeper Address for keeper
    /// @param ibera Address for InfraredBERA
    /// @param _infrared Address for Infrared
    function initialize(
        address _gov,
        address _keeper,
        address ibera,
        address _infrared
    ) external initializer {
        if (
            _gov == address(0) || _keeper == address(0) || ibera == address(0)
                || _infrared == address(0)
        ) revert Errors.ZeroAddress();
        __Upgradeable_init();

        InfraredBERA = ibera;
        infrared = IInfrared(_infrared);

        _grantRole(DEFAULT_ADMIN_ROLE, _gov);
        _grantRole(GOVERNANCE_ROLE, _gov);
        _grantRole(KEEPER_ROLE, _keeper);
    }

    /// @notice Amount of BERA swept to InfraredBERA and fees taken for protool on next call to sweep
    /// @return amount THe amount of BERA forwarded to InfraredBERA on next sweep.
    /// @return fees The protocol fees taken on next sweep.
    function distribution()
        public
        view
        returns (uint256 amount, uint256 fees)
    {
        amount = (address(this).balance - shareholderFees);
        uint16 feeShareholders =
            IInfraredBERA(InfraredBERA).feeDivisorShareholders();

        // take protocol fees
        if (feeShareholders > 0) {
            fees = amount / uint256(feeShareholders);
            amount -= fees;
        }
    }

    /// @notice Sweeps accumulated coinbase priority fees + MEV to InfraredBERA to autocompound principal
    /// @return amount The amount of BERA forwarded to InfraredBERA.
    /// @return fees The total fees taken.
    function sweep() external returns (uint256 amount, uint256 fees) {
        (amount, fees) = distribution();

        // add to protocol fees and sweep amount back to ibera to deposit
        if (fees > 0) shareholderFees += fees;
        IInfraredBERA(InfraredBERA).sweep{value: amount}();
        emit Sweep(InfraredBERA, amount, fees);
    }

    /// @notice Collects accumulated shareholder fees
    /// @dev Reverts if msg.sender is not `InfraredBera.sol` contract
    /// @return sharesMinted The amount of iBERA shares minted and sent to the `Infrared.sol`
    function collect() external returns (uint256 sharesMinted) {
        if (msg.sender != InfraredBERA) revert Errors.Unauthorized(msg.sender);
        uint256 _shareholderFees = shareholderFees;
        if (_shareholderFees == 0) return 0;

        delete shareholderFees;
        sharesMinted = IInfraredBERA(InfraredBERA).mint{value: _shareholderFees}(
            address(infrared)
        );

        emit Collect(address(infrared), _shareholderFees, sharesMinted);
    }

    /// @notice Fallback function to receive BERA
    receive() external payable {}
}
