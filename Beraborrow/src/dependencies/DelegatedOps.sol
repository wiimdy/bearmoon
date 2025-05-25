// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {IBeraborrowCore} from "../interfaces/core/IBeraborrowCore.sol";

/**
    @title Beraborrow Delegated Operations
    @notice Allows delegation to specific contract functionality. Useful for creating
            wrapper contracts to bundle multiple interactions into a single call.

            Functions that supports delegation should include an `account` input allowing
            the delegated caller to indicate who they are calling on behalf of. In executing
            the call, all internal state updates should be applied for `account` and all
            value transfers should occur to or from the caller.

            For example: a delegated call to `openDen` should transfer collateral
            from the caller, create the debt position for `account`, and send newly
            minted tokens to the caller.
 */
contract DelegatedOps {
    IBeraborrowCore immutable beraborrowCore;

    mapping(address owner => mapping(address caller => bool isApproved)) public isApprovedDelegate;

    event DelegateApprovalSet(address indexed owner, address indexed delegate, bool isApproved);

    constructor(address _beraborrowCore) {
        if (_beraborrowCore == address(0)) {
            revert("DelegatedOps: 0 address");
        }
        beraborrowCore = IBeraborrowCore(_beraborrowCore);
    }

    modifier callerOrDelegated(address _account) {
        require(msg.sender == _account || beraborrowCore.isPeriphery(msg.sender) || isApprovedDelegate[_account][msg.sender], "Delegate not approved");
        _;
    }

    function setDelegateApproval(address _delegate, bool _isApproved) external {
        isApprovedDelegate[msg.sender][_delegate] = _isApproved;
        emit DelegateApprovalSet(msg.sender, _delegate, _isApproved);
    }
}
