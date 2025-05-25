// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IInfraredBERA is IERC20, IAccessControl {
    /// @notice Emitted when InfraredBERA is minted
    /// @param receiver The address receiving the minted shares
    /// @param amount The amount of BERA deposited
    /// @param shares The amount of shares minted
    event Mint(address indexed receiver, uint256 amount, uint256 shares);

    /// @notice Emitted when InfraredBERA is burned
    /// @param receiver The address receiving the withdrawn BERA
    /// @param nonce The withdrawal nonce
    /// @param amount The amount of BERA to withdraw
    /// @param shares The amount of shares burned
    /// @param fee The fee paid for withdrawal
    event Burn(
        address indexed receiver,
        uint256 nonce,
        uint256 amount,
        uint256 shares,
        uint256 fee
    );

    /// @notice Emitted when accumulated rewards are swept
    /// @param amount The amount of BERA swept
    event Sweep(uint256 amount);

    /// @notice Emitted when validator stake is registered
    /// @param pubkey The validator's public key
    /// @param delta The change in stake amount
    /// @param stake The new total stake amount
    event Register(bytes pubkey, int256 delta, uint256 stake);

    /// @notice Emitted when fee shareholders rate is updated
    /// @param from Previous fee rate
    /// @param to New fee rate
    event SetFeeShareholders(uint16 from, uint16 to);

    /// @notice Emitted when deposit signature is updated
    /// @param pubkey The validator's public key
    /// @param from Previous signature
    /// @param to New signature
    event SetDepositSignature(bytes pubkey, bytes from, bytes to);

    /// @notice Emitted when withdrawal flag is updated
    /// @param flag New withdrawal flag value
    event WithdrawalFlagSet(bool flag);

    /// @notice The `Infrared.sol` smart contract
    function infrared() external view returns (address);

    /// @notice The `InfraredBERADepositor.sol` smart contract
    function depositor() external view returns (address);

    /// @notice The `InfraredBERAWithdrawor.sol` smart contract
    function withdrawor() external view returns (address);

    /// @notice The `InfraredBERAFeeReceivor.sol` smart contract
    function receivor() external view returns (address);

    /// @notice The total amount of `BERA` deposited by the system
    function deposits() external view returns (uint256);

    /// @notice Returns the amount of `BERA` staked in validator with given pubkey
    function stakes(bytes calldata pubkey) external view returns (uint256);

    /// @notice Returns whether initial deposit has been staked to validator with given pubkey
    function staked(bytes calldata pubkey) external view returns (bool);

    /// @notice Returns whether a validator pubkey has exited
    function hasExited(bytes calldata pubkey) external view returns (bool);

    /// @notice Returns the deposit signature to use for given pubkey
    function signatures(bytes calldata pubkey)
        external
        view
        returns (bytes memory);

    /// @notice The fee divisor for protocol + operator + voter fees. 1/N, where N is the divisor. example 100 = 1/100 = 1%
    function feeDivisorShareholders() external view returns (uint16);

    /// @notice Pending deposits yet to be forwarded to CL
    function pending() external view returns (uint256);

    /// @notice Confirmed deposits sent to CL, total - future deposits
    function confirmed() external view returns (uint256);

    /// @notice Checks if account has the keeper role
    /// @param account The address to check
    /// @return True if the account has the keeper role
    function keeper(address account) external view returns (bool);

    /// @notice Checks if account has the governance role
    /// @param account The address to check
    /// @return True if the account has the governance role
    function governor(address account) external view returns (bool);

    /// @notice Checks if a given pubkey is a validator in the `Infrared` contract
    /// @param pubkey The pubkey to check
    /// @return True if the pubkey is a validator
    function validator(bytes calldata pubkey) external view returns (bool);

    /// @notice Previews the amount of InfraredBERA shares that would be minted for a given BERA amount
    /// @param beraAmount The amount of BERA to simulate depositing
    /// @return shares The amount of InfraredBERA shares that would be minted, returns 0 if the operation would fail
    function previewMint(uint256 beraAmount)
        external
        view
        returns (uint256 shares);

    /// @notice Previews the amount of BERA that would be received for burning InfraredBERA shares
    /// @param shareAmount The amount of InfraredBERA shares to simulate burning
    /// @return beraAmount The amount of BERA that would be received, returns 0 if the operation would fail
    /// @return fee The fee that would be charged for the burn operation
    function previewBurn(uint256 shareAmount)
        external
        view
        returns (uint256 beraAmount, uint256 fee);

    /// @notice Initiializer for `InfraredBERA`
    /// @param _gov The address of the governance contract
    /// @param _keeper The address of the keeper contract
    /// @param _infrared The address of the `Infrared.sol` contract
    /// @param _depositor The address of the `InfraredBERADepositor.sol` contract
    /// @param _withdrawor The address of the `InfraredBERAWithdrawor.sol` contract
    /// @param _receivor The address of the `InfraredBERAFeeReceivor.sol` contract
    function initialize(
        address _gov,
        address _keeper,
        address _infrared,
        address _depositor,
        address _withdrawor,
        address _receivor
    ) external payable;

    /// @notice Internal function to update top level accounting and compound rewards
    function compound() external;

    /// @notice Compounds accumulated EL yield in fee receivor into deposits
    /// @dev Called internally at bof whenever InfraredBERA minted or burned
    /// @dev Only sweeps if amount transferred from fee receivor would exceed min deposit thresholds
    function sweep() external payable;

    /// @notice Collects yield from fee receivor and mints ibera shares to Infrared
    /// @dev Called in `RewardsLib::harvestOperatorRewards()` in `Infrared.sol`
    /// @dev Only Infrared can call this function
    /// @return sharesMinted The amount of ibera shares
    function collect() external returns (uint256 sharesMinted);

    /// @notice Mints `ibera` to the `receiver` in exchange for `bera`
    /// @dev takes in msg.value as amount to mint `ibera` with
    /// @param receiver The address to mint `ibera` to
    /// @return shares The amount of `ibera` minted
    function mint(address receiver) external payable returns (uint256 shares);

    /// @notice Burns `ibera` from the `msg.sender` and sets a receiver to get the `BERA` in exchange for `iBERA`
    /// @param receiver The address to send the `BERA` to
    /// @param shares The amount of `ibera` to burn
    /// @return nonce The nonce of the withdrawal. Queue based system for withdrawals
    /// @return amount The amount of `BERA` withdrawn for the exchange of `iBERA`
    function burn(address receiver, uint256 shares)
        external
        payable
        returns (uint256 nonce, uint256 amount);

    /// @notice Updates the accounted for stake of a validator pubkey
    /// @param pubkey The pubkey of the validator
    /// @param delta The change in stake
    function register(bytes calldata pubkey, int256 delta) external;

    /// @notice Sets the fee shareholders taken on yield from EL coinbase priority fees + MEV
    /// @param to The new fee shareholders represented as an integer denominator (1/x)%
    function setFeeDivisorShareholders(uint16 to) external;

    /// @notice Sets the deposit signature for a given pubkey. Ensure that the pubkey has signed the correct deposit amount of `INITIAL_DEPOSIT`
    /// @param pubkey The pubkey to set the deposit signature for
    /// @param signature The signature to set for the pubkey
    function setDepositSignature(
        bytes calldata pubkey,
        bytes calldata signature
    ) external;

    /// @notice Whether withdrawals are currently enabled
    function withdrawalsEnabled() external view returns (bool);
}
