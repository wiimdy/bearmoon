// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IBeraChef} from "@berachain/pol/interfaces/IBeraChef.sol";
import {IRewardVaultFactory as IBerachainRewardsVaultFactory} from
    "@berachain/pol/interfaces/IRewardVaultFactory.sol";
import {IVoter} from "src/voting/interfaces/IVoter.sol";
import {IInfraredBERA} from "src/interfaces/IInfraredBERA.sol";
import {IInfraredGovernanceToken} from
    "src/interfaces/IInfraredGovernanceToken.sol";
import {IWBERA} from "src/interfaces/IWBERA.sol";
import {InfraredBGT} from "src/core/InfraredBGT.sol";
import {IBribeCollector} from "src/interfaces/IBribeCollector.sol";
import {IInfraredDistributor} from "src/interfaces/IInfraredDistributor.sol";
import {IInfraredVault} from "src/interfaces/IInfraredVault.sol";
import {DataTypes} from "src/utils/DataTypes.sol";
import {ValidatorTypes} from "src/core/libraries/ValidatorTypes.sol";
import {ConfigTypes} from "src/core/libraries/ConfigTypes.sol";

interface IInfrared {
    /**
     * @notice Checks if a token is a whitelisted reward token
     * @param _token The address of the token to check
     * @return bool True if the token is whitelisted, false otherwise
     */
    function whitelistedRewardTokens(address _token)
        external
        view
        returns (bool);

    /**
     * @notice Returns the infrared vault address for a given staking token
     * @param _asset The address of the staking asset
     * @return IInfraredVault The vault associated with the asset
     */
    function vaultRegistry(address _asset)
        external
        view
        returns (IInfraredVault);

    /**
     * @notice The InfraredBGT liquid staked token
     * @return IInfraredBGT The InfraredBGT token contract address
     */
    function ibgt() external view returns (InfraredBGT);

    /**
     * @notice The Berachain rewards vault factory address
     * @return IBerachainRewardsVaultFactory instance of the rewards factory contract address
     */
    function rewardsFactory()
        external
        view
        returns (IBerachainRewardsVaultFactory);

    /**
     * @notice The Berachain chef contract for distributing validator rewards
     * @return IBeraChef instance of the BeraChef contract address
     */
    function chef() external view returns (IBeraChef);

    /**
     * @notice The InfraredBGT vault
     * @return IInfraredVault instance of the iBGT vault contract address
     */
    function ibgtVault() external view returns (IInfraredVault);

    /**
     * @notice The unclaimed Infrared protocol fees of token accumulated by contract
     * @param token address The token address for the accumulated fees
     * @return uint256 The amount of accumulated fees
     */
    function protocolFeeAmounts(address token)
        external
        view
        returns (uint256);

    /**
     * @notice Protocol fee rates to charge for various harvest function distributions
     * @param i The index of the fee rate
     * @return uint256 The fee rate
     */
    function fees(uint256 i) external view returns (uint256);

    /**
     * @notice Wrapped bera
     * @return IWBERA The wbera token contract address
     */
    function wbera() external view returns (IWBERA);

    /**
     * @notice Honey ERC20 token
     * @return ERC20 The honey token contract address
     */
    function honey() external view returns (ERC20);

    /**
     * @notice bribe collector contract
     * @return IBribeCollector The bribe collector contract address
     */
    function collector() external view returns (IBribeCollector);

    /**
     * @notice Infrared distributor for BGT rewards to validators
     * @return IInfraredDistributor instance of the distributor contract address
     */
    function distributor() external view returns (IInfraredDistributor);

    /**
     * @notice IR voter
     * @return IVoter instance of the voter contract address
     */
    function voter() external view returns (IVoter);

    /**
     * @notice collects all iBERA realted fees and revenue
     * @return returns IInfraredBERAFeeReceivor instanace of iBeraFeeReceivor
     */
    function ibera() external view returns (IInfraredBERA);

    /**
     * @notice The IR token
     * @return IR instance of the IR token contract address
     */
    function ir() external view returns (IInfraredGovernanceToken);

    /**
     * @notice The rewards duration
     * @dev Used as gloabl variabel to set the rewards duration for all new reward tokens on InfraredVaults
     * @return uint256 The reward duration period, in seconds
     */
    function rewardsDuration() external view returns (uint256);

    /**
     * @notice Registers a new vault for a given asset
     * @dev Infrared.sol must be admin over MINTER_ROLE on InfraredBGT to grant minter role to deployed vault
     * @param _asset The address of the asset, such as a specific LP token
     * @return vault The address of the newly created InfraredVault contract
     * @custom:emits NewVault with the caller, asset address, and new vault address.
     */
    function registerVault(address _asset)
        external
        returns (IInfraredVault vault);

    /**
     * @notice Adds a new reward token to a specific staking vault
     * @dev Only callable by governance when contract is initialized
     * @param _stakingToken The address of the staking token associated with the vault
     * @param _rewardsToken The address of the token to be added as a reward
     * @param _rewardsDuration The duration period for the rewards distribution, in seconds
     * @custom:error ZeroAmount if _rewardsDuration is 0
     * @custom:error RewardTokenNotWhitelisted if _rewardsToken is not whitelisted
     * @custom:error NoRewardsVault if vault doesn't exist for _stakingToken
     */
    function addReward(
        address _stakingToken,
        address _rewardsToken,
        uint256 _rewardsDuration
    ) external;

    /**
     * @notice Adds reward incentives to a specific staking vault
     * @dev Transfers reward tokens from caller to this contract, then notifies vault of new rewards
     * @param _stakingToken The address of the staking token associated with the vault
     * @param _rewardsToken The address of the token being added as incentives
     * @param _amount The amount of reward tokens to add as incentives
     * @custom:error ZeroAmount if _amount is 0
     * @custom:error NoRewardsVault if vault doesn't exist for _stakingToken
     * @custom:error RewardTokenNotWhitelisted if reward token hasn't been configured for the vault
     * @custom:access Callable when contract is initialized
     * @custom:security Requires caller to have approved this contract to spend _rewardsToken
     */
    function addIncentives(
        address _stakingToken,
        address _rewardsToken,
        uint256 _amount
    ) external;

    /**
     * @notice Updates the whitelist status of a reward token
     * @param _token The address of the token to whitelist or remove from whitelist
     * @param _whitelisted A boolean indicating if the token should be whitelisted
     */
    function updateWhiteListedRewardTokens(address _token, bool _whitelisted)
        external;

    /**
     * @notice Sets the new duration for reward distributions in InfraredVaults
     * @param _rewardsDuration The new reward duration period, in seconds
     * @dev Only callable by governance
     */
    function updateRewardsDuration(uint256 _rewardsDuration) external;

    /**
     * @notice Updates the rewards duration for a specific reward token on a specific vault
     * @param _stakingToken The address of the staking asset associated with the vault
     * @param _rewardsToken The address of the reward token to update the duration for
     * @param _rewardsDuration The new reward duration period, in seconds
     * @dev Only callable by governance
     */
    function updateRewardsDurationForVault(
        address _stakingToken,
        address _rewardsToken,
        uint256 _rewardsDuration
    ) external;

    /**
     * @notice Pauses staking functionality on a specific vault
     * @param _asset The address of the staking asset associated with the vault to pause
     * @dev Only callable by pauser or governance, will revert if vault doesn't exist
     */
    function pauseStaking(address _asset) external;

    /**
     * @notice Un-pauses staking functionality on a specific vault
     * @param _asset The address of the staking asset associated with the vault to pause
     * @dev Only callable by gov, will revert if vault doesn't exist
     */
    function unpauseStaking(address _asset) external;

    /**
     * @notice Claims lost rewards on a specific vault
     * @param _asset The address of the staking asset associated with the vault to claim lost rewards on
     * @dev Only callable by governance, will revert if vault doesn't exist
     */
    function claimLostRewardsOnVault(address _asset) external;

    /**
     * @notice Recovers ERC20 tokens sent accidentally to the contract
     * @param _to The address to receive the recovered tokens
     * @param _token The address of the token to recover
     * @param _amount The amount of the token to recover
     */
    function recoverERC20(address _to, address _token, uint256 _amount)
        external;

    /**
     * @notice Recover ERC20 tokens from a vault.
     * @param _asset  address The address of the staking asset that the vault is for.
     * @param _to     address The address to send the tokens to.
     * @param _token  address The address of the token to recover.
     * @param _amount uint256 The amount of the token to recover.
     */
    function recoverERC20FromVault(
        address _asset,
        address _to,
        address _token,
        uint256 _amount
    ) external;

    /**
     * @notice Delegates BGT votes to `_delegatee` address.
     * @param _delegatee  address The address to delegate votes to
     */
    function delegateBGT(address _delegatee) external;

    /**
     * @notice Updates the weight for iBERA bribes
     * @param _weight uint256 The weight value
     */
    function updateInfraredBERABribeSplit(uint256 _weight) external;

    /**
     * @notice Updates the fee rate charged on different harvest functions
     * @notice Please harvest all assosiated rewards for a given type before updating
     * @dev Fee rate in units of 1e6 or hundredths of 1 bip
     * @param _t   FeeType The fee type
     * @param _fee uint256 The fee rate to update to
     */
    function updateFee(ConfigTypes.FeeType _t, uint256 _fee) external;

    /**
     * @notice Sets the address of the IR contract
     * @dev Infrared must be granted MINTER_ROLE on IR to set the address
     * @param _IR The address of the IR contract
     */
    function setIR(address _IR) external;

    /**
     * @notice Sets the address of the iBGT contract
     * @dev Infrared must be granted MINTER_ROLE on IBGT to set the address
     * @param _ibgt The address of the iBGT contract
     */
    function setIBGT(address _ibgt) external;

    /**
     * @notice Updates the mint rate for IR
     * @param _IRMintRate The new mint rate for IR
     */
    function updateIRMintRate(uint256 _IRMintRate) external;

    /**
     * @notice Claims accumulated protocol fees in contract
     * @param _to     address The recipient of the fees
     * @param _token  address The token to claim fees in
     */
    function claimProtocolFees(address _to, address _token) external;

    /**
     * @notice Claims all the BGT base and commission rewards minted to this contract for validators.
     */
    function harvestBase() external;

    /**
     * @notice Credits all accumulated rewards to the operator
     */
    function harvestOperatorRewards() external;

    /**
     * @notice Claims all the BGT rewards for the vault associated with the given staking token.
     * @param _asset address The address of the staking asset that the vault is for.
     */
    function harvestVault(address _asset) external;

    /**
     * @notice Claims all the bribes rewards in the contract forwarded from Berachain POL.
     * @param _tokens address[] memory The addresses of the tokens to harvest in the contract.
     */
    function harvestBribes(address[] memory _tokens) external;

    /**
     * @notice Collects bribes from bribe collector and distributes to wiBERA and iBGT Infrared vaults.
     * @notice _token The payout token for the bribe collector.
     * @notice _amount The amount of payout received from bribe collector.
     */
    function collectBribes(address _token, uint256 _amount) external;

    /**
     * @notice Claims all the BGT staker rewards from boosting validators.
     * @dev Sends rewards to iBGT vault.
     */
    function harvestBoostRewards() external;

    /**
     * @notice Adds validators to the set of `InfraredValidators`.
     * @param _validators Validator[] memory The validators to add.
     */
    function addValidators(ValidatorTypes.Validator[] memory _validators)
        external;

    /**
     * @notice Removes validators from the set of `InfraredValidators`.
     * @param _pubkeys bytes[] memory The pubkeys of the validators to remove.
     */
    function removeValidators(bytes[] memory _pubkeys) external;

    /**
     * @notice Replaces a validator in the set of `InfraredValidators`.
     * @param _current bytes The pubkey of the validator to replace.
     * @param _new     bytes The new validator pubkey.
     */
    function replaceValidator(bytes calldata _current, bytes calldata _new)
        external;

    /**
     * @notice Queue `_amts` of tokens to `_validators` for boosts.
     * @param _pubkeys     bytes[] memory The pubkeys of the validators to queue boosts for.
     * @param _amts        uint128[] memory The amount of BGT to boost with.
     */
    function queueBoosts(bytes[] memory _pubkeys, uint128[] memory _amts)
        external;

    /**
     * @notice Removes `_amts` from previously queued boosts to `_validators`.
     * @dev `_pubkeys` need not be in the current validator set in case just removed but need to cancel.
     * @param _pubkeys     bytes[] memory The pubkeys of the validators to remove boosts for.
     * @param _amts        uint128[] memory The amounts of BGT to remove from the queued boosts.
     */
    function cancelBoosts(bytes[] memory _pubkeys, uint128[] memory _amts)
        external;

    /**
     * @notice Activates queued boosts for `_pubkeys`.
     * @param _pubkeys   bytes[] memory The pubkeys of the validators to activate boosts for.
     */
    function activateBoosts(bytes[] memory _pubkeys) external;

    /**
     * @notice Queues a drop boost of the validators removing an amount of BGT for sender.
     * @dev Reverts if `user` does not have enough boosted balance to cover amount.
     * @param pubkeys     bytes[] memory The pubkeys of the validators to remove boost from.
     * @param amounts Amounts of BGT to remove from the queued drop boosts.
     */
    function queueDropBoosts(
        bytes[] calldata pubkeys,
        uint128[] calldata amounts
    ) external;

    /**
     * @notice Cancels a queued drop boost of the validator removing an amount of BGT for sender.
     * @param pubkeys     bytes[] memory The pubkeys of the validators to remove boost from.
     * @param amounts Amounts of BGT to remove from the queued drop boosts.
     */
    function cancelDropBoosts(
        bytes[] calldata pubkeys,
        uint128[] calldata amounts
    ) external;

    /**
     * @notice Drops an amount of BGT from an existing boost of validators by user.
     * @param pubkeys     bytes[] memory The pubkeys of the validators to remove boost from.
     */
    function dropBoosts(bytes[] calldata pubkeys) external;

    /**
     * @notice Queues a new cutting board on BeraChef for reward weight distribution for validator
     * @param _pubkey             bytes                         The pubkey of the validator to queue the cutting board for
     * @param _startBlock         uint64                        The start block for reward weightings
     * @param _weights            IBeraChef.Weight[] calldata   The weightings used when distributor calls chef to distribute validator rewards
     */
    function queueNewCuttingBoard(
        bytes calldata _pubkey,
        uint64 _startBlock,
        IBeraChef.Weight[] calldata _weights
    ) external;

    /**
     * @notice Gets the set of infrared validator pubkeys.
     * @return validators Validator[] memory The set of infrared validators.
     */
    function infraredValidators()
        external
        view
        returns (ValidatorTypes.Validator[] memory validators);

    /**
     * @notice Gets the number of infrared validators in validator set.
     * @return num uint256 The number of infrared validators in validator set.
     */
    function numInfraredValidators() external view returns (uint256);

    /**
     * @notice Checks if a validator is an infrared validator.
     * @param _pubkey    bytes      The pubkey of the validator to check.
     * @return _isValidator bool       Whether the validator is an infrared validator.
     */
    function isInfraredValidator(bytes memory _pubkey)
        external
        view
        returns (bool);

    /**
     * @notice Gets the BGT balance for this contract
     * @return bgtBalance The BGT balance held by this address
     */
    function getBGTBalance() external view returns (uint256 bgtBalance);

    /**
     * @notice Emitted when a new vault is registered
     * @param _sender The address that initiated the vault registration
     * @param _asset The address of the asset for which the vault is registered
     * @param _vault The address of the newly created vault
     */
    event NewVault(
        address _sender, address indexed _asset, address indexed _vault
    );

    /**
     * @notice Emitted when pause status for new vault registration has changed
     * @param pause True if new vault creation is paused
     */
    event VaultRegistrationPauseStatus(bool pause);

    /**
     * @notice Emitted when InfraredBGT tokens are supplied to distributor.
     * @param _ibera token the rewards are denominated in
     * @param _distributor The address of the distributor receiving the InfraredBGT tokens.
     * @param _amt The amount of WBERA tokens supplied to distributor.
     */
    event OperatorRewardsDistributed(
        address indexed _ibera, address indexed _distributor, uint256 _amt
    );

    /**
     * @notice Emitted when InfraredBGT tokens are supplied to a vault.
     * @param _vault The address of the vault receiving the InfraredBGT and IR tokens.
     * @param _ibgtAmt The amount of InfraredBGT tokens supplied to vault.
     * @param _iredAmt The amount of IR tokens supplied to vault as additional reward from protocol.
     */
    event InfraredBGTSupplied(
        address indexed _vault, uint256 _ibgtAmt, uint256 _iredAmt
    );

    /**
     * @notice Emitted when rewards are supplied to a vault.
     * @param _vault The address of the vault receiving the reward.
     * @param _token The address of the token being supplied as a reward.
     * @param _amt The amount of the reward token supplied.
     */
    event RewardSupplied(
        address indexed _vault, address indexed _token, uint256 _amt
    );

    /**
     * @notice Emitted when rewards are supplied to a vault.
     * @param _recipient The address receiving the bribe.
     * @param _token The address of the token being supplied as a bribe reward.
     * @param _amt The amount of the bribe reward token supplied.
     */
    event BribeSupplied(
        address indexed _recipient, address indexed _token, uint256 _amt
    );

    /**
     * @notice Emitted when tokens are recovered from the contract.
     * @param _sender The address that initiated the recovery.
     * @param _token The address of the token being recovered.
     * @param _amount The amount of the token recovered.
     */
    event Recovered(address _sender, address indexed _token, uint256 _amount);

    /**
     * @notice Emitted when a reward token is marked as unsupported.
     * @param _token The address of the reward token.
     */
    event RewardTokenNotSupported(address _token);

    /**
     * @notice Emitted when the InfraredBGT token address is updated.
     * @param _sender The address that initiated the update.
     * @param _oldIbgt The previous address of the InfraredBGT token.
     * @param _newIbgt The new address of the InfraredBGT token.
     */
    event InfraredBGTUpdated(
        address _sender, address _oldIbgt, address _newIbgt
    );

    /**
     * @notice Emitted when the InfraredBGT vault address is updated.
     * @param _sender The address that initiated the update.
     * @param _oldIbgtVault The previous address of the InfraredBGT vault.
     * @param _newIbgtVault The new address of the InfraredBGT vault.
     */
    event InfraredBGTVaultUpdated(
        address _sender, address _oldIbgtVault, address _newIbgtVault
    );

    /**
     * @notice Emitted when reward tokens are whitelisted or unwhitelisted.
     * @param _sender The address that initiated the update.
     * @param _token The address of the token being updated.
     * @param _wasWhitelisted The previous whitelist status of the token.
     * @param _isWhitelisted The new whitelist status of the token.
     */
    event WhiteListedRewardTokensUpdated(
        address _sender,
        address indexed _token,
        bool _wasWhitelisted,
        bool _isWhitelisted
    );

    /**
     * @notice Emitted when the rewards duration is updated
     * @param _sender The address that initiated the update
     * @param _oldDuration The previous rewards duration
     * @param _newDuration The new rewards duration
     */
    event RewardsDurationUpdated(
        address _sender, uint256 _oldDuration, uint256 _newDuration
    );

    /**
     * @notice Emitted when a weight is updated.
     * @param _sender The address that initiated the update.
     * @param _oldWeight The old value of the weight.
     * @param _newWeight The new value of the weight.
     */
    event InfraredBERABribeSplitUpdated(
        address _sender, uint256 _oldWeight, uint256 _newWeight
    );

    /**
     * @notice Emitted when protocol fee rate is updated.
     * @param _sender The address that initiated the update.
     * @param _feeType The fee type updated.
     * @param _oldFeeRate The old protocol fee rate.
     * @param _newFeeRate The new protocol fee rate.
     */
    event FeeUpdated(
        address _sender,
        ConfigTypes.FeeType _feeType,
        uint256 _oldFeeRate,
        uint256 _newFeeRate
    );

    /**
     * @notice Emitted when protocol fees claimed.
     * @param _sender The address that initiated the claim.
     * @param _to The address to send protocol fees to.
     * @param _token The address of the token protocol fees in.
     * @param _amount The amount of protocol fees claimed.
     */
    event ProtocolFeesClaimed(
        address _sender, address _to, address _token, uint256 _amount
    );

    /**
     * @notice Emitted when protocol fees are received.
     * @param _token The address of the token protocol fees in.
     * @param _amt The amount of protocol fees received.
     * @param _voterAmt The amount of protocol fees received by the voter.
     */
    event ProtocolFees(address indexed _token, uint256 _amt, uint256 _voterAmt);

    /**
     * @notice Emitted when base + commission rewards are harvested.
     * @param _sender The address that initiated the harvest.
     * @param _bgtAmt The amount of BGT harvested.
     */
    event BaseHarvested(address _sender, uint256 _bgtAmt);

    /**
     * @notice Emitted when a vault harvests its rewards.
     * @param _sender The address that initiated the harvest.
     * @param _asset The asset associated with the vault being harvested.
     * @param _vault The address of the vault being harvested.
     * @param _bgtAmt The amount of BGT harvested.
     */
    event VaultHarvested(
        address _sender,
        address indexed _asset,
        address indexed _vault,
        uint256 _bgtAmt
    );

    /**
     * @notice Emitted when bribes are harvested then collected by collector.
     * @param _sender The address that initiated the bribe collection.
     * @param _token The payout token from bribe collection.
     * @param _amtWiberaVault The amount of collected bribe sent to the wrapped iBERA vault.
     * @param _amtIbgtVault The amount of collected bribe sent to the iBGT vault.
     */
    event BribesCollected(
        address _sender,
        address _token,
        uint256 _amtWiberaVault,
        uint256 _amtIbgtVault
    );

    /**
     * @notice Emitted when a validator harvests its rewards.
     * @param _sender The address that initiated the harvest.
     * @param _validator The public key of the validator.
     * @param _rewards An array of tokens and amounts harvested.
     * @param _bgtAmt The amount of BGT included in the rewards.
     */
    event ValidatorHarvested(
        address _sender,
        bytes indexed _validator,
        DataTypes.Token[] _rewards,
        uint256 _bgtAmt
    );

    /**
     * @notice Emitted when validators are added.
     * @param _sender The address that initiated the addition.
     * @param _validators An array of validators that were added.
     */
    event ValidatorsAdded(
        address _sender, ValidatorTypes.Validator[] _validators
    );

    /**
     * @notice Emitted when validators are removed from validator set.
     * @param _sender The address that initiated the removal.
     * @param _pubkeys An array of validators' pubkeys that were removed.
     */
    event ValidatorsRemoved(address _sender, bytes[] _pubkeys);

    /**
     * @notice Emitted when a validator is replaced with a new validator.
     * @param _sender The address that initiated the replacement.
     * @param _current The pubkey of the current validator being replaced.
     * @param _new The pubkey of the new validator.
     */
    event ValidatorReplaced(address _sender, bytes _current, bytes _new);

    /**
     * @notice Emitted when BGT tokens are queued for boosts to validators.
     * @param _sender The address that initiated the boost.
     * @param _pubkeys The addresses of the validators to which tokens are queued for boosts.
     * @param _amts The amounts of tokens that were queued.
     */
    event QueuedBoosts(address _sender, bytes[] _pubkeys, uint128[] _amts);

    /**
     * @notice Emitted when existing queued boosts to validators are cancelled.
     * @param _sender The address that initiated the cancellation.
     * @param _pubkeys The pubkeys of the validators to which tokens were queued for boosts.
     * @param _amts The amounts of tokens to remove from boosts.
     */
    event CancelledBoosts(address _sender, bytes[] _pubkeys, uint128[] _amts);

    /**
     * @notice Emitted when an existing boost to a validator is activated.
     * @param _sender The address that initiated the activation.
     * @param _pubkeys The addresses of the validators which were boosted.
     */
    event ActivatedBoosts(address _sender, bytes[] _pubkeys);

    /**
     * @notice Emitted when an user queues a drop boost for a validator.
     * @param user The address of the user.
     * @param pubkeys The addresses of the validators to which tokens were queued for boosts.
     * @param amounts The amounts of tokens to remove from boosts.
     */
    event QueueDropBoosts(
        address indexed user, bytes[] indexed pubkeys, uint128[] amounts
    );

    /**
     * @notice Emitted when an user cancels a queued drop boost for a validator.
     * @param user The address of the user.
     * @param pubkeys The addresses of the validators to which tokens were queued for boosts.
     * @param amounts The amounts of tokens to remove from boosts.
     */
    event CancelDropBoosts(
        address indexed user, bytes[] indexed pubkeys, uint128[] amounts
    );

    /**
     * @notice Emitted when sender removes an amount of BGT boost from a validator
     * @param _sender The address that initiated the cancellation.
     * @param _pubkeys The addresses of the validators to which tokens were queued for boosts.
     */
    event DroppedBoosts(address indexed _sender, bytes[] _pubkeys);

    /**
     * @notice Emitted when tokens are undelegated from a validator.
     * @param _sender The address that initiated the undelegation.
     * @param _pubkey The pubkey of the validator from which tokens are undelegated.
     * @param _amt The amount of tokens that were undelegated.
     */
    event Undelegated(address _sender, bytes _pubkey, uint256 _amt);

    /**
     * @notice Emitted when tokens are redelegated from one validator to another.
     * @param _sender The address that initiated the redelegation.
     * @param _from The public key of the validator from which tokens are redelegated.
     * @param _to The public key of the validator to which tokens are redelegated.
     * @param _amt The amount of tokens that were redelegated.
     */
    event Redelegated(address _sender, bytes _from, bytes _to, uint256 _amt);

    /**
     * @notice Emitted when the IR token is set.
     * @param _sender The address that initiated the update.
     * @param _IR The address of the IRdd token.
     */
    event IRSet(address _sender, address _IR);

    /**
     *
     * @param oldMintRate The old mint rate for IR
     * @param newMintRate The new mint rate for IR
     * @param sender The address that initiated the update
     */
    event UpdatedIRMintRate(
        uint256 oldMintRate, uint256 newMintRate, address sender
    );

    /**
     * @notice Emitted when the iBGT token is set.
     * @param _sender The address that initiated the update.
     * @param _ibgt The address of the iBGT token.
     */
    event IBGTSet(address _sender, address _ibgt);

    /**
     * @notice Emitted when the voter contract is set.
     * @param _sender The address that initiated the update.
     * @param _voter The address of the voter contract.
     */
    event VoterSet(address _sender, address _voter);
}
