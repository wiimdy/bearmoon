// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IInfrared} from "./IInfrared.sol";

interface IInfraredBERAFeeReceivor {
    /// @notice Emitted when accumulated rewards are swept to InfraredBERA
    /// @param receiver The address receiving the swept BERA
    /// @param amount The amount of BERA swept
    /// @param fees The amount of fees taken
    event Sweep(address indexed receiver, uint256 amount, uint256 fees);

    /// @notice Emitted when shareholder fees are collected
    /// @param receiver The address receiving the collected fees
    /// @param amount The amount of fees collected
    /// @param sharesMinted The amount of iBERA shares minted
    event Collect(
        address indexed receiver, uint256 amount, uint256 sharesMinted
    );

    /// @notice The address of the `InfraredBERA.sol` contract
    function InfraredBERA() external view returns (address);

    /// @notice The `Infrared.sol` contract address
    function infrared() external view returns (IInfrared);

    /// @notice Accumulated protocol fees in contract to be claimed
    function shareholderFees() external view returns (uint256);

    /// @notice Amount of BERA swept to InfraredBERA and fees taken for protool on next call to sweep
    /// @return amount The amount of BERA forwarded to InfraredBERA on next sweep
    /// @return fees The protocol fees taken on next sweep
    function distribution()
        external
        view
        returns (uint256 amount, uint256 fees);

    /// @notice Sweeps accumulated coinbase priority fees + MEV to InfraredBERA to autocompound principal
    /// @return amount The amount of BERA forwarded to InfraredBERA
    /// @return fees The total fees taken
    function sweep() external returns (uint256 amount, uint256 fees);

    /// @notice Collects accumulated shareholder fees
    /// @dev Reverts if msg.sender is not `InfraredBera.sol` contract
    /// @return sharesMinted The amount of iBERA shares minted and sent to the `Infrared.sol`
    function collect() external returns (uint256 sharesMinted);

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
    ) external;
}
