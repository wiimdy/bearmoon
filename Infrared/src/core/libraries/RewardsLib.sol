// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IRewardVault as IBerachainRewardsVault} from "@berachain/pol/interfaces/IRewardVault.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {IInfraredDistributor} from "src/interfaces/IInfraredDistributor.sol";
import {IBerachainBGTStaker} from "src/interfaces/IBerachainBGTStaker.sol";
import {IInfraredVault} from "src/interfaces/IInfraredVault.sol";
import {ConfigTypes} from "src/core/libraries/ConfigTypes.sol";
import {IBerachainBGT} from "src/interfaces/IBerachainBGT.sol";
import {IInfrared} from "src/interfaces/IInfrared.sol";
import {IReward} from "src/voting/interfaces/IReward.sol";
import {IVoter} from "src/voting/interfaces/IVoter.sol";
import {DataTypes} from "src/utils/DataTypes.sol";
import {IWBERA} from "src/interfaces/IWBERA.sol";
import {IInfraredBGT} from "src/interfaces/IInfraredBGT.sol";
import {IInfraredGovernanceToken} from "src/interfaces/IInfraredGovernanceToken.sol";
import {IInfraredBERA} from "src/interfaces/IInfraredBERA.sol";
import {Errors} from "src/utils/Errors.sol";

library RewardsLib {
    using SafeTransferLib for ERC20;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       STORAGE TYPE                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // @notice Storage for all reward accumulators and configurations
    // @notice protocolFeeAmounts Tracks accumulated protocol fees per token so that the protocol can claim them at a later time
    // @notice irMintRate         Rate for minting IR tokens at a rate of BGT to IR in hundredths of 1 bip (1e6)
    // @notice bribeSplitRatio    Ratio for splitting received bribes to the iBERA and IBGT product, weighted towards iBERA, ie iBGT weight = (UNIT_DENOMINATOR - bribeSplitRatio))
    // @notice fees               Mapping of fee rates for different fee types
    struct RewardsStorage {
        mapping(address => uint256) protocolFeeAmounts;
        uint256 irMintRate;
        uint256 bribeSplitRatio;
        mapping(uint256 => uint256) fees;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       EVENTS                               */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Emitted when protocol wants to mint `IR` but fails.
    /// @param amount uint256 The amount of `IR` that failed to mint
    event ErrorMisconfiguredIRMinting(uint256 amount);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CONSTANTS                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Unit denominotor for calculating all fees and rates in the system
     * @dev All fees and rates are calculated out of 1e6
     */
    uint256 internal constant UNIT_DENOMINATOR = 1e6;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       FEES                                 */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Harvest rewards given to our operators for setting their cuttingboard weights
    /// ref - https://github.com/infrared-dao/infrared-contracts/blob/develop/src/staking/InfraredBERAFeeReceivor.sol#L83
    /// @param $                The storage pointer for all rewards accumulators
    /// @param ibera            The address of the InfraredBERA token
    /// @param voter            The address of the voter (address(0) if IR token is not live)
    /// @param distributor      The address of the distributor
    ///
    /// @return _amt            The amount of rewards harvested
    function harvestOperatorRewards(
        RewardsStorage storage $,
        address ibera,
        address voter,
        address distributor
    ) external returns (uint256 _amt) {
        // Compound + Collect, syncing the iBERA rewards to latest.
        IInfraredBERA(ibera).compound();
        uint256 iBERAShares = IInfraredBERA(ibera).collect();
        if (iBERAShares == 0) return 0;

        // The total fee rate to charge on iBERA harvest rewards.
        uint256 feeTotal = $.fees[
            uint256(ConfigTypes.FeeType.HarvestOperatorFeeRate)
        ];

        // The rate to charge for the protocol treasury on total fees.
        uint256 feeProtocol = $.fees[
            uint256(ConfigTypes.FeeType.HarvestOperatorProtocolRate)
        ];

        // the recipient of the rewards is the total pool of operators which is aggregated in the `Distributor` smart contract.
        uint256 amountOperators;
        // The amount of rewards going to the voter contract
        uint256 amountVoters;
        /// The amount of rewards going to the protocol treasury
        uint256 amountProtocol;
        (amountOperators, amountVoters, amountProtocol) = chargedFeesOnRewards(
            iBERAShares,
            feeTotal,
            feeProtocol
        );

        // Distribute the fees for the protocol and voter amounts.
        _distributeFeesOnRewards(
            $.protocolFeeAmounts,
            voter,
            ibera,
            amountVoters,
            amountProtocol
        );

        // Send the rewards owed to the operators to the distributor.
        if (amountOperators > 0) {
            ERC20(ibera).safeApprove(distributor, amountOperators);
            IInfraredDistributor(distributor).notifyRewardAmount(
                amountOperators
            );
        }
    }

    /// @notice Generic function to calculate the fees charged on rewards, returning the amount owed to the recipient, protocol, and voter.
    /// @notice the recipient is the amount of rewards being sent forward into the protocol for example a vault
    /// @param  amount          The amount of rewards to calculate fees on
    /// @param  totalFeeRate    The total fee rate to charge on rewards (protocol + voter)
    /// @param  protocolFeeRate The rate to charge for protocol fees
    /// @return recipient       The amount of rewards to send to the recipient
    /// @return voterFees       The amount of rewards to send to the voter
    /// @return protocolFees    The amount of rewards to send to the protocol
    function chargedFeesOnRewards(
        uint256 amount,
        uint256 totalFeeRate,
        uint256 protocolFeeRate
    )
        public
        pure
        returns (uint256 recipient, uint256 voterFees, uint256 protocolFees)
    {
        // if the total fee charged is 0, return the amount as is and 0 for the rest
        if (totalFeeRate == 0) return (amount, 0, 0);

        // calculate the total fees to be charged = amount * totalFeeRate
        uint256 totalFees = (amount * totalFeeRate) / UNIT_DENOMINATOR;

        // calculate the protocol fees = totalFees * protocolFeeRate
        protocolFees =
            (amount * totalFeeRate * protocolFeeRate) /
            (UNIT_DENOMINATOR * UNIT_DENOMINATOR);

        // calculate the voter fees = totalFees - protocolFees
        voterFees = totalFees - protocolFees;

        // deduct the total fees from the amount to get the recipient amount
        recipient = amount - totalFees;
    }

    /// @notice Distributes fees on rewards to the protocol, voter, and recipient.
    /// @notice _protocolFeeAmounts The accumulator for protocol fees per token
    /// @notice _voter              The address of the voter
    /// @notice _token              The address of the reward token
    /// @notice _amtVoter           The amount of rewards for the voter
    /// @notice _amtProtocol        The amount of rewards for the protocol
    function _distributeFeesOnRewards(
        mapping(address => uint256) storage protocolFeeAmounts,
        address _voter,
        address _token,
        uint256 _amtVoter,
        uint256 _amtProtocol
    ) internal {
        // add protocol fees to accumulator for token
        protocolFeeAmounts[_token] += _amtProtocol;

        // forward voter fees
        if (_amtVoter > 0) {
            address voterFeeVault = IVoter(_voter).feeVault();
            ERC20(_token).safeApprove(voterFeeVault, _amtVoter);
            IReward(voterFeeVault).notifyRewardAmount(_token, _amtVoter);
        }

        emit IInfrared.ProtocolFees(_token, _amtProtocol, _amtVoter);
    }

    /// @notice Handles non-InfraredBGT token rewards to the vault.
    /// @param $            RewardsStorage  The storage pointer for all rewards accumulators.
    /// @param _vault       IInfraredVault   The address of the vault.
    /// @param _token       address          The reward token.
    /// @param voter        address          The address of the voter.
    /// @param _amount      uint256          The amount of reward token to send to vault.
    /// @param _feeTotal    uint256          The rate to charge for total fees on `_amount`.
    /// @param _feeProtocol uint256          The rate to charge for protocol treasury on total fees.
    /// @param rewardsDuration uint256        The duration of the rewards.
    function _handleTokenRewardsForVault(
        RewardsStorage storage $,
        IInfraredVault _vault,
        address _token,
        address voter,
        uint256 _amount,
        uint256 _feeTotal,
        uint256 _feeProtocol,
        uint256 rewardsDuration
    ) internal {
        if (_amount == 0) return;

        // add reward if not already added
        (, uint256 _vaultRewardsDuration, , , , , ) = _vault.rewardData(_token);
        if (_vaultRewardsDuration == 0) {
            _vault.addReward(_token, rewardsDuration);
        }

        uint256 _amtVoter;
        uint256 _amtProtocol;

        // calculate and distribute fees on rewards
        (_amount, _amtVoter, _amtProtocol) = chargedFeesOnRewards(
            _amount,
            _feeTotal,
            _feeProtocol
        );
        _distributeFeesOnRewards(
            $.protocolFeeAmounts,
            voter,
            _token,
            _amtVoter,
            _amtProtocol
        );

        // increase allowance then notify vault of new rewards
        if (_amount > 0) {
            ERC20(_token).safeApprove(address(_vault), _amount);
            _vault.notifyRewardAmount(_token, _amount);
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       ADMIN                                */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Update the IR minting rate for the protocol.
    /// @notice This rate determines how many IR tokens are minted whenever BGT rewards are harvested.
    /// @notice For example, if the rate is 500,000 (0.5 * UNIT_DENOMINATOR), 0.5 IR is minted per BGT.
    /// @notice If the rate is 2,000,000 (2 * UNIT_DENOMINATOR), 2 IR are minted per BGT.
    /// @notice The actuall calculation is done in the `harvestVault` function when BGT rewards are harvested and IR tokens are minted accordingly.
    /// @param $           The storage pointer for all rewards accumulators
    /// @param newRate The new IR minting rate out of UNIT_DENOMINATOR(1e6 being 100% or a 1:1 rate)
    function updateIRMintRate(
        RewardsStorage storage $,
        uint256 newRate
    ) external {
        $.irMintRate = newRate;
    }

    /// @notice Delegates Berachain Governance Voting Power to a delegatee
    /// @param _delegatee The address to delegate voting power to
    /// @param bgt        The address of the BGT token
    function delegateBGT(address _delegatee, address bgt) external {
        IBerachainBGT(bgt).delegate(_delegatee);
    }

    /// @notice Update the split ratio for iBERA and iBGT rewards
    /// @param $           The storage pointer for all rewards accumulators
    /// @param _split The ratio for splitting received bribes to be iBERA and iBGT, weighted towards iBERA
    function updateInfraredBERABribeSplit(
        RewardsStorage storage $,
        uint256 _split
    ) external {
        if (_split > UNIT_DENOMINATOR) revert Errors.InvalidWeight();
        $.bribeSplitRatio = _split;
    }

    /// @notice Update the fee rate for a given fee type
    /// @param $           The storage pointer for all rewards accumulators
    /// @param _t          The fee type to update
    /// @param _fee        The new fee rate
    function updateFee(
        RewardsStorage storage $,
        ConfigTypes.FeeType _t,
        uint256 _fee
    ) external {
        if (_fee > UNIT_DENOMINATOR) revert Errors.InvalidFee();
        $.fees[uint256(_t)] = _fee;
    }

    /// @notice Claim protocol fees for a given token
    /// @param $           The storage pointer for all rewards accumulators
    /// @param _to         The address to send the protocol fees to
    /// @param _token      The token to claim protocol fees for
    function claimProtocolFees(
        RewardsStorage storage $,
        address _to,
        address _token
    ) external returns (uint256 _amountClaimed) {
        _amountClaimed = $.protocolFeeAmounts[_token];
        delete $.protocolFeeAmounts[_token];

        ERC20(_token).safeTransfer(_to, _amountClaimed);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       HARVEST Functions                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Harvet's base rewards from the BGT contract, ie rewards from Distributor, given in BGT
    ///     ref - https://github.com/berachain/contracts-monorepo/blob/main/src/pol/rewards/Distributor.sol#L160
    /// @notice The BGT accumilates in the contract, therfore can check balance(this) since all other BGT rewards are claimed and harvested atomically
    /// @notice Reward paid out to validators proposing a block, MUST be forwarded to IBERA.receivor, the fees are handled there. TODO: Link here.
    /// @param ibgt     The address of the InfraredBGT toke
    /// @param bgt      The address of the BGT token
    /// @param ibera    The address of the InfraredBERA token
    ///
    /// @return bgtAmt  The amount of BGT rewards harvested
    function harvestBase(
        address ibgt,
        address bgt,
        address ibera
    ) external returns (uint256 bgtAmt) {
        // Since BGT balance has accrued to this contract, we check for what we've already accounted for
        uint256 minted = IInfraredBGT(ibgt).totalSupply();

        // The balance of BGT in the contract is the rewards accumilated from base rewards since the last harvest
        // Since is paid out every block our validators propose (have a `Distributor::distibuteFor()` call)
        uint256 balance = IBerachainBGT(bgt).balanceOf(address(this));
        if (balance == 0) return 0;

        // @dev the amount that will be minted is the difference between the balance accrued since the last harvestVault and the current balance in the contract.
        // This difference should keep getting bigger as the contract accumilates more bgt from `Distributor::distibuteFor()` calls.
        bgtAmt = balance - minted;

        // @dev ensure that the `BGT::redeem` call won't revert if there is no BERA backing it.
        // This is not unlikley since https://github.com/berachain/beacon-kit slots/blocks are not consistent there are times
        // where the BGT rewards are not backed by BERA, in this case the BGT rewards are not redeemable.
        // https://github.com/berachain/contracts-monorepo/blob/a28404635b5654b4de0627d9c0d1d8fced7b4339/src/pol/BGT.sol#L363
        if (bgtAmt > bgt.balance) return 0;

        // catch try can be used for additional security
        try IBerachainBGT(bgt).redeem(IInfraredBERA(ibera).receivor(), bgtAmt) {
            return bgtAmt;
        } catch {
            return 0;
        }
    }

    /// @notice Harvests the accrued BGT rewards to a vault.
    /// @notice BGT transferred here directly to the user https://github.com/berachain/contracts-monorepo/blob/c374de32077ede0147985cf2bf6ed89570244a7e/src/pol/rewards/RewardVault.sol#L404
    /// @param vault            The address of the InfraredRewardVault, wrapping an underlying RewardVault
    /// @param bgt              The address of the BGT token
    /// @param ibgt             The address of the InfraredBGT token
    /// @param voter            The address of the voter (0 until IR token is live)
    /// @param ir               The address of the Infrared token
    /// @param rewardsDuration  The duration of the rewards
    ///
    /// @return bgtAmt The amount of BGT rewards harvested
    function harvestVault(
        RewardsStorage storage $,
        IInfraredVault vault,
        address bgt,
        address ibgt,
        address voter,
        address ir,
        uint256 rewardsDuration
    ) external returns (uint256 bgtAmt) {
        // Ensure the vault is valid
        if (vault == IInfraredVault(address(0))) {
            revert Errors.VaultNotSupported();
        }

        // Record the BGT balance before claiming rewards since there could be base rewards that are in the balance.
        uint256 balanceBefore = IBerachainBGT(bgt).balanceOf(address(this));

        // Get the underlying Berachain RewardVault and claim the BGT rewards.
        IBerachainRewardsVault rewardsVault = vault.rewardsVault();
        rewardsVault.getReward(address(vault), address(this));

        // Calculate the amount of BGT rewards received
        bgtAmt = IBerachainBGT(bgt).balanceOf(address(this)) - balanceBefore;

        // If no BGT rewards were received, exit early
        if (bgtAmt == 0) return bgtAmt;

        // Mint InfraredBGT tokens equivalent to the BGT rewards
        IInfraredBGT(ibgt).mint(address(this), bgtAmt);

        // Calculate the voter and protocol fees to charge on the rewards
        (
            uint256 _amt,
            uint256 _amtVoter,
            uint256 _amtProtocol
        ) = chargedFeesOnRewards(
                bgtAmt,
                $.fees[uint256(ConfigTypes.FeeType.HarvestVaultFeeRate)],
                $.fees[uint256(ConfigTypes.FeeType.HarvestVaultProtocolRate)]
            );

        // Distribute the fees on the rewards.
        _distributeFeesOnRewards(
            $.protocolFeeAmounts,
            voter,
            ibgt,
            _amtVoter,
            _amtProtocol
        );

        // Send the post-fee rewards to the vault
        if (_amt > 0) {
            ERC20(ibgt).safeApprove(address(vault), _amt);
            vault.notifyRewardAmount(ibgt, _amt);
        }

        // If IR token is set and mint rate is greater than zero, handle IR rewards.
        uint256 mintRate = $.irMintRate;
        if (ir != address(0) && mintRate > 0) {
            // Calculate the amount of IR tokens to mint = BGT rewards * mint rate
            uint256 irAmt = (bgtAmt * mintRate) / UNIT_DENOMINATOR;
            if (!IInfraredGovernanceToken(ir).paused()) {
                IInfraredGovernanceToken(ir).mint(address(this), irAmt);
                {
                    // Check if IR is already a reward token in the vault
                    (, uint256 IRRewardsDuration, , , , , ) = vault.rewardData(
                        ir
                    );
                    if (IRRewardsDuration == 0) {
                        // Add IR as a reward token if not already added
                        vault.addReward(ir, rewardsDuration);
                    }
                }

                // Send the remaining IR rewards to the vault
                if (irAmt > 0) {
                    ERC20(ir).safeApprove(address(vault), irAmt);
                    vault.notifyRewardAmount(ir, irAmt);
                }
            } else {
                // @dev Misconfigured Role or Hit Supply Cap
                emit ErrorMisconfiguredIRMinting(irAmt);
            }
        }
    }

    /// @notice Harvests berachain reward vault as operator for user.
    /// @notice BGT transferred here, iBGT minted to user
    /// @param vault            The address of the Berachain reward vault
    /// @param bgt              The address of the BGT token
    /// @param ibgt             The address of the InfraredBGT token
    /// @param voter            The address of the voter (0 until IR token is live)
    /// @param user             The address of the User to claim bgt on behalf of
    ///
    /// @return bgtAmt The amount of BGT rewards harvested = amount of iBGT minted
    function harvestVaultForUser(
        RewardsStorage storage $,
        IBerachainRewardsVault vault,
        address bgt,
        address ibgt,
        address voter,
        address user
    ) external returns (uint256 bgtAmt) {
        // Ensure the vault is valid
        if (address(vault) == address(0)) {
            revert Errors.VaultNotSupported();
        }

        // check infrared is an operator for user
        if (vault.operator(user) != address(this)) {
            revert Errors.InvalidOperator();
        }

        // Record the BGT balance before claiming rewards since there could be base rewards that are in the balance.
        uint256 balanceBefore = IBerachainBGT(bgt).balanceOf(address(this));

        // Claim the BGT rewards on behalf of user.
        vault.getReward(user, address(this));

        // Calculate the amount of BGT rewards received
        bgtAmt = IBerachainBGT(bgt).balanceOf(address(this)) - balanceBefore;

        // If no BGT rewards were received, exit early
        if (bgtAmt == 0) return bgtAmt;

        // Mint InfraredBGT tokens equivalent to the BGT rewards
        IInfraredBGT(ibgt).mint(address(this), bgtAmt);

        // Calculate the voter and protocol fees to charge on the rewards
        (
            uint256 _amt,
            uint256 _amtVoter,
            uint256 _amtProtocol
        ) = chargedFeesOnRewards(
                bgtAmt,
                $.fees[uint256(ConfigTypes.FeeType.HarvestVaultFeeRate)],
                $.fees[uint256(ConfigTypes.FeeType.HarvestVaultProtocolRate)]
            );

        // Distribute the fees on the rewards.
        _distributeFeesOnRewards(
            $.protocolFeeAmounts,
            voter,
            ibgt,
            _amtVoter,
            _amtProtocol
        );

        // Send the post-fee ibgt to user
        if (_amt > 0) {
            ERC20(ibgt).safeTransfer(user, _amt);
        }
    }

    /// @notice View rewards to claim for berachain reward vault as operator for user.
    /// @param vault            The address of the Berachain reward vault
    /// @param user             The address of the User to claim bgt on behalf of
    ///
    /// @return iBgtAmount The amount of BGT rewards harvested = amount of iBGT minted
    function externalVaultRewards(
        RewardsStorage storage $,
        IBerachainRewardsVault vault,
        address user
    ) external view returns (uint256 iBgtAmount) {
        // Ensure the vault is valid
        if (address(vault) == address(0)) {
            revert Errors.VaultNotSupported();
        }

        // check infarred is an operator for user
        if (vault.operator(user) != address(this)) {
            revert Errors.InvalidOperator();
        }

        // Claim the BGT rewards on behalf of user.
        uint256 bgtAmt = vault.earned(user);

        // If no BGT rewards were received, exit early
        if (bgtAmt == 0) return bgtAmt;

        // Calculate the voter and protocol fees to charge on the rewards
        (iBgtAmount, , ) = chargedFeesOnRewards(
            bgtAmt,
            $.fees[uint256(ConfigTypes.FeeType.HarvestVaultFeeRate)],
            $.fees[uint256(ConfigTypes.FeeType.HarvestVaultProtocolRate)]
        );
    }

    /// @notice Harvests the accrued BGT rewards to a vault.
    /// @notice BGT transferred here directly to the user https://github.com/berachain/contracts-monorepo/blob/c374de32077ede0147985cf2bf6ed89570244a7e/src/pol/rewards/RewardVault.sol#L404
    /// @param vault            The address of the InfraredRewardVault, wrapping an underlying RewardVault
    /// @param bgt              The address of the BGT token
    /// @param ibgt             The address of the InfraredBGT token
    /// @param voter            The address of the voter (0 until IR token is live)
    ///
    /// @return bgtAmt The amount of BGT rewards harvested
    function harvestOldVault(
        RewardsStorage storage $,
        IInfraredVault vault,
        IInfraredVault newVault,
        address bgt,
        address ibgt,
        address voter
    ) external returns (uint256 bgtAmt) {
        // Ensure the vault is valid
        if (vault == IInfraredVault(address(0))) {
            revert Errors.VaultNotSupported();
        }

        // Record the BGT balance before claiming rewards since there could be base rewards that are in the balance.
        uint256 balanceBefore = IBerachainBGT(bgt).balanceOf(address(this));

        // Get the underlying Berachain RewardVault and claim the BGT rewards.
        IBerachainRewardsVault rewardsVault = vault.rewardsVault();
        rewardsVault.getReward(address(vault), address(this));

        // Calculate the amount of BGT rewards received
        bgtAmt = IBerachainBGT(bgt).balanceOf(address(this)) - balanceBefore;

        // If no BGT rewards were received, exit early
        if (bgtAmt == 0) return bgtAmt;

        // Mint InfraredBGT tokens equivalent to the BGT rewards
        IInfraredBGT(ibgt).mint(address(this), bgtAmt);

        // Calculate the voter and protocol fees to charge on the rewards
        (
            uint256 _amt,
            uint256 _amtVoter,
            uint256 _amtProtocol
        ) = chargedFeesOnRewards(
                bgtAmt,
                $.fees[uint256(ConfigTypes.FeeType.HarvestVaultFeeRate)],
                $.fees[uint256(ConfigTypes.FeeType.HarvestVaultProtocolRate)]
            );

        // Distribute the fees on the rewards.
        _distributeFeesOnRewards(
            $.protocolFeeAmounts,
            voter,
            ibgt,
            _amtVoter,
            _amtProtocol
        );

        if (_amt > 0) {
            ERC20(ibgt).safeApprove(address(newVault), _amt);
            newVault.notifyRewardAmount(ibgt, _amt);
        }
    }

    /// @notice Harvest Bribes in tokens from RewardVault, sent to us via processIncentive
    /// ref - https://github.com/berachain/contracts-monorepo/blob/c374de32077ede0147985cf2bf6ed89570244a7e/src/pol/rewards/RewardVault.sol#L421
    /// @param $            The storage pointer for all rewards accumulators
    /// @param collector    The address of the bribe collector, which will auction off fees for WBERA
    /// @param _tokens      The array of token addresses to harvest
    /// @param whitelisted  The array of booleans indicating if the token is whitelisted, and should be collected
    function harvestBribes(
        RewardsStorage storage $,
        address collector,
        address[] memory _tokens,
        bool[] memory whitelisted
    ) external returns (address[] memory tokens, uint256[] memory amounts) {
        // Create new arrays for the tokens and amounts
        uint256 len = _tokens.length;
        amounts = new uint256[](len);
        tokens = new address[](len);

        // Iterate over the tokens, checking if they are whitelisted and collecting them to the bribe collector
        // if they are. Since we accumulate protocol fees for each token, balance - protocol fees = amounts the contract has earned from bribes.
        for (uint256 i = 0; i < len; i++) {
            if (!whitelisted[i]) continue;
            // Current token being processed
            address _token = _tokens[i];

            // Calculate the amount of the token to forward to the bribe collector = balance of this address - existing protocol fees
            uint256 _amount = ERC20(_token).balanceOf(address(this)) -
                $.protocolFeeAmounts[_token];

            // Store the token and amount in the arrays
            amounts[i] = _amount;
            tokens[i] = _token;

            // Transfer the tokens to the bribe collector
            if (_amount > 0) {
                ERC20(_token).safeTransfer(collector, _amount);
            }
        }
    }

    /// @notice Harvest boost rewards from the BGT staker (in HONEY -- likely)
    /// @param $                The storage pointer for all rewards accumulators
    /// @param bgt              The address of the BGT token
    /// @param ibgtVault        The address of the InfraredBGT vault
    /// @param voter            The address of the voter (address(0) if IR token is not live)
    /// @param rewardsDuration  The duration of the rewards
    ///
    /// @return _token           The rewards token harvested (likely hunny)
    /// @return _amount          The amount of rewards harvested
    function harvestBoostRewards(
        RewardsStorage storage $,
        address bgt,
        address ibgtVault,
        address voter,
        uint256 rewardsDuration
    ) external returns (address _token, uint256 _amount) {
        IBerachainBGTStaker _bgtStaker = IBerachainBGTStaker(
            IBerachainBGT(bgt).staker()
        );
        _token = address(_bgtStaker.rewardToken());

        // @dev claim the boost rewards and use return value to calculate the amount
        _amount = _bgtStaker.getReward();

        // get total and protocol fee rates
        uint256 feeTotal = $.fees[
            uint256(ConfigTypes.FeeType.HarvestBoostFeeRate)
        ];
        uint256 feeProtocol = $.fees[
            uint256(ConfigTypes.FeeType.HarvestBoostProtocolRate)
        ];

        _handleTokenRewardsForVault(
            $,
            IInfraredVault(ibgtVault),
            _token,
            voter,
            _amount,
            feeTotal,
            feeProtocol,
            rewardsDuration
        );
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CALLBACK                             */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Callback from the BribeCollector to payout the WBERA bribes were auctioned off for
    ///     ref - https://github.com/infrared-dao/infrared-contracts/blob/develop/src/core/BribeCollector.sol#L87
    /// @param $        Storage pointer for reward accumulators
    /// @param _amount          The amount of WBERA our bribes were auctioned off for
    /// @param wbera            The address of the WBERA token
    /// @param ibera            The address of the InfraredBERA token
    /// @param ibgtVault        The address of the InfraredBGT vault
    /// @param voter            The address of the voter (address(0) if IR token is not live)
    /// @param rewardsDuration  The duration of the rewards
    ///
    /// @notice WBERA is split between the iBERA product (where it is redeemed for BERA) and the rest is sent to the IBGT vault.
    /// @return amtInfraredBERA The amount of WBERA sent to the iBERA product
    /// @return amtIbgtVault    The amount of WBERA sent to the IBGT vault
    function collectBribesInWBERA(
        RewardsStorage storage $,
        uint256 _amount,
        address wbera,
        address ibera,
        address ibgtVault,
        address voter,
        uint256 rewardsDuration
    ) external returns (uint256 amtInfraredBERA, uint256 amtIbgtVault) {
        // transfer WBERA from bribe collector
        ERC20(wbera).safeTransferFrom(msg.sender, address(this), _amount);

        // determine amount to send to iBERA and IBGT vault
        amtInfraredBERA = (_amount * $.bribeSplitRatio) / UNIT_DENOMINATOR;
        amtIbgtVault = _amount - amtInfraredBERA;

        // Redeem WBERA for BERA and send to IBERA receivor for compounding
        IWBERA(wbera).withdraw(amtInfraredBERA);
        SafeTransferLib.safeTransferETH(
            IInfraredBERA(ibera).receivor(),
            amtInfraredBERA
        );

        // Get Fee totals (voter + protocol)
        uint256 feeTotal = $.fees[
            uint256(ConfigTypes.FeeType.HarvestBribesFeeRate)
        ];
        uint256 feeProtocol = $.fees[
            uint256(ConfigTypes.FeeType.HarvestBribesProtocolRate)
        ];

        // Charge fees and notify rewards
        _handleTokenRewardsForVault(
            $,
            IInfraredVault(ibgtVault),
            wbera,
            voter,
            amtIbgtVault,
            feeTotal,
            feeProtocol,
            rewardsDuration
        );
    }
}
