// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IInfraredBERADepositor {
    /// @notice Emitted when BERA is queued for deposit
    /// @param amount The amount of BERA queued
    event Queue(uint256 amount);

    /// @notice Emitted when a deposit is executed to the deposit contract
    /// @param pubkey The validator's public key
    /// @param amount The amount of BERA deposited
    event Execute(bytes pubkey, uint256 amount);

    /// @notice the main InfraredBERA contract address
    function InfraredBERA() external view returns (address);

    /// @notice the queued amount of BERA to be deposited
    function reserves() external view returns (uint256);

    /// @notice Queues a deposit by sending BERA to this contract and storing the amount
    /// in the pending deposits acculimator
    function queue() external payable;

    /// @notice Executes a deposit to the deposit contract for the specified pubkey and amount
    /// @param pubkey The pubkey of the validator to deposit for
    /// @param amount The amount of BERA to deposit
    /// @dev Only callable by the keeper
    /// @dev Only callable if the deposits are enabled
    function execute(bytes calldata pubkey, uint256 amount) external;

    /// @notice Initialize the contract (replaces the constructor)
    /// @param _gov Address for admin / gov to upgrade
    /// @param _keeper Address for keeper
    /// @param ibera The initial IBERA address
    /// @param _depositContract The ETH2 (Berachain) Deposit Contract Address
    function initialize(
        address _gov,
        address _keeper,
        address ibera,
        address _depositContract
    ) external;

    /// @notice The Deposit Contract Address for Berachain
    function DEPOSIT_CONTRACT() external view returns (address);

    /// @notice https://eth2book.info/capella/part2/deposits-withdrawals/withdrawal-processing/
    function ETH1_ADDRESS_WITHDRAWAL_PREFIX() external view returns (uint8);
}
