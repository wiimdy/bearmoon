// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Reward} from "./Reward.sol";
import {IVotingEscrow} from "../interfaces/IVotingEscrow.sol";
import {IVoter} from "../interfaces/IVoter.sol";

/**
 * @title VotingReward
 * @notice Base contract for rewards distributed based on voting power
 * @dev Extends Reward with voting-specific reward logic
 */
abstract contract VotingReward is Reward {
    /**
     * @notice Configures voting rewards with initial reward tokens
     * @param _voter Address of voter contract
     * @param _rewards Initial array of reward token addresses
     */
    constructor(address _voter, address[] memory _rewards) Reward(_voter) {
        uint256 _length = _rewards.length;
        for (uint256 i; i < _length; i++) {
            if (_rewards[i] != address(0)) {
                isReward[_rewards[i]] = true;
                rewards.push(_rewards[i]);
            }
        }

        authorized = _voter;
    }

    /**
     * @inheritdoc Reward
     * @dev Validates caller is token owner or voter before processing claim
     */
    function getReward(uint256 tokenId, address[] memory tokens)
        external
        override
        nonReentrant
    {
        if (
            !IVotingEscrow(ve).isApprovedOrOwner(msg.sender, tokenId)
                && msg.sender != voter
        ) revert NotAuthorized();

        address _owner = IVotingEscrow(ve).ownerOf(tokenId);
        _getReward(_owner, tokenId, tokens);
    }

    /// @inheritdoc Reward
    function notifyRewardAmount(address token, uint256 amount)
        external
        virtual
        override
        nonReentrant
    {}
}
