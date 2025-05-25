// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IInfraredBERAWithdrawor {
    /// @notice Emitted when a withdrawal is queued
    /// @param receiver The address that will receive the withdrawn BERA
    /// @param nonce The unique identifier for this withdrawal request
    /// @param amount The amount of BERA to be withdrawn
    event Queue(address indexed receiver, uint256 nonce, uint256 amount);

    /// @notice Emitted when a withdrawal is executed
    /// @param pubkey The validator's public key
    /// @param start The starting nonce
    /// @param end The ending nonce
    /// @param amount The amount of BERA withdrawn
    event Execute(bytes pubkey, uint256 start, uint256 end, uint256 amount);

    /// @notice Emitted when a withdrawal is processed
    /// @param receiver The address receiving the withdrawn BERA
    /// @param nonce The nonce of the processed withdrawal
    /// @param amount The amount of BERA processed
    event Process(address indexed receiver, uint256 nonce, uint256 amount);

    /// @notice Emitted when funds are swept from a force-exited validator
    /// @param receiver The address receiving the swept BERA
    /// @param amount The amount of BERA swept
    event Sweep(address indexed receiver, uint256 amount);

    /// @notice The address of the InfraredBERA contract
    function InfraredBERA() external view returns (address);

    /// @notice Sweeps forced withdrawals to InfraredBERA to re-stake principal
    /// @param pubkey The validator's public key to sweep funds from
    /// @dev Only callable when withdrawals are disabled and by keeper
    function sweep(bytes calldata pubkey) external;

    /// @notice Outstanding requests for claims on previously burnt ibera
    /// @param nonce The nonce associated with the claim
    /// @return receiver The address of the receiver of bera funds to be claimed
    /// @return timestamp The block.timestamp at which withdraw request was issued
    /// @return fee The fee escrow amount set aside for withdraw precompile request
    /// @return amountSubmit The amount of bera left to be submitted for withdraw request
    /// @return amountProcess The amount of bera left to be processed for withdraw request
    function requests(uint256 nonce)
        external
        view
        returns (
            address receiver,
            uint96 timestamp,
            uint256 fee,
            uint256 amountSubmit,
            uint256 amountProcess
        );

    /// @notice Amount of BERA internally set aside for withdraw precompile request fees
    function fees() external view returns (uint256);

    /// @notice Amount of BERA internally set aside to process withdraw compile requests from funds received on successful requests
    function reserves() external view returns (uint256);

    /// @notice Amount of BERA internally rebalancing amongst Infrared validators
    function rebalancing() external view returns (uint256);

    /// @notice The next nonce to issue withdraw request for
    function nonceRequest() external view returns (uint256);

    /// @notice The next nonce to submit withdraw request for
    function nonceSubmit() external view returns (uint256);

    /// @notice The next nonce in queue to process claims for
    function nonceProcess() external view returns (uint256);

    /// @notice Queues a withdraw request from InfraredBERA
    /// @param receiver The address to receive withdrawn funds
    /// @param amount The amount of funds to withdraw
    /// @return nonce The unique identifier for this withdrawal request
    /// @dev Requires msg.value to cover minimum withdrawal fee
    function queue(address receiver, uint256 amount)
        external
        payable
        returns (uint256 nonce);

    /// @notice Executes a withdraw request to withdraw precompile
    /// @param pubkey The validator's public key to withdraw from
    /// @param amount The amount of BERA to withdraw
    /// @dev Payable to cover any additional fees required by precompile
    /// @dev Only callable by keeper
    function execute(bytes calldata pubkey, uint256 amount) external payable;

    /// @notice Processes the funds received from withdraw precompile
    /// @dev Reverts if balance has not increased by full amount of request
    /// @dev Processes requests in FIFO order based on nonce
    function process() external;
}
