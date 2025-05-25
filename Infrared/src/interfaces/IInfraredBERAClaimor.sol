// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IInfraredBERAClaimor {
    event Queue(address indexed receiver, uint256 amount, uint256 claim);
    event Sweep(address indexed receiver, uint256 amount);

    /// @notice Outstanding BERA claims for a receiver
    /// @param receiver The address of the claims receiver
    function claims(address receiver) external view returns (uint256);

    /// @notice Queues a new BERA claim for a receiver
    /// @dev Only callable by the InfraredBERAWithdrawor contract
    /// @param receiver The address of the claims receiver
    function queue(address receiver) external payable;

    /// @notice Sweeps oustanding BERA claims for a receiver to their address
    /// @param receiver The address of the claims receiver
    function sweep(address receiver) external;
}
