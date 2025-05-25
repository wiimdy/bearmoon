// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {IMetaBeraborrowCore} from "src/interfaces/core/IMetaBeraborrowCore.sol";

/**
    @title Beraborrow Core
    @notice Single source of truth for system-wide values and contract ownership.
            Other ownable Beraborrow contracts inherit their ownership from this contract
            using `BeraborrowOwnable`, relayed by BeraborrowCore.
    @dev Named Meta, since Beraborrow will consist of multiple protocol instances
 */
contract MetaBeraborrowCore is IMetaBeraborrowCore {
    // We enforce a three day delay between committing and applying
    // an ownership change, as a sanity check on a proposed new owner
    // and to give users time to react in case the act is malicious.
    uint256 public constant OWNERSHIP_TRANSFER_DELAY = 3 days;

    uint16 public constant DEFAULT_FLASH_LOAN_FEE = 5; // 0.05%

    // During bootstrap period sNect redemptions are not allowed
    uint64 public lspBootstrapPeriod;
    address public priceFeed;
    address public nect;
    // System-wide pause. When true, disables den adjustments across all collaterals.
    bool public paused;
    address public owner;
    address public pendingOwner;
    uint256 public ownershipTransferDeadline;
    address public manager;
    address public guardian;
    address public feeReceiver;
    uint16 public lspEntryFee;
    uint16 public lspExitFee;

    // Beacon-looked by NECT to determine fee reduction given to periphery contract for flash loans/mints
    mapping(address peripheryContract => FeeInfo fee) internal peripheryFlashLoanFee;
    mapping(address => RebalancerFeeInfo fee) internal rebalancerFee;

    constructor(address _owner, address _guardian, address _priceFeed, address _nect, address _feeReceiver, uint16 _lspEntryFee, uint16 _lspExitFee, uint64 _lspBootstrapPeriod) {
        if (_owner == address(0) || _guardian == address(0) || _priceFeed == address(0) || _nect == address(0) || _feeReceiver == address(0)) {
            revert("MetaBeraborrowCore: 0 address");
        }

        owner = _owner;
        guardian = _guardian;
        priceFeed = _priceFeed;
        nect = _nect;
        feeReceiver = _feeReceiver;
        lspEntryFee = _lspEntryFee;
        lspExitFee = _lspExitFee;
        lspBootstrapPeriod = _lspBootstrapPeriod;

        emit GuardianSet(_guardian);
        emit PriceFeedSet(_priceFeed);
        emit FeeReceiverSet(_feeReceiver);             
        emit EntryFeeSet(_lspEntryFee);
        emit ExitFeeSet(_lspExitFee);
        emit LSPBootstrapPeriodSet(_lspBootstrapPeriod);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    /**
     * @notice Sets the global pause state of the protocol
     *         Pausing is used to mitigate risks in exceptional circumstances
     *         Functionalities affected by pausing are:
     *         - New borrowing is not possible
     *         - New collateral deposits are not possible
     *         - New stability pool deposits are not possible
     * @param _paused If true the protocol is paused
     */
    function setPaused(bool _paused) external {
        require((_paused && msg.sender == guardian) || msg.sender == owner, "Unauthorized");
        paused = _paused;
        if (_paused) {
            emit Paused();
        } else {
            emit Unpaused();
        }
    }

    /**
     * @notice Set the receiver of all fees across the protocol
     * @param _feeReceiver Address of the fee's recipient
     */
    function setFeeReceiver(address _feeReceiver) external onlyOwner {
        feeReceiver = _feeReceiver;
        emit FeeReceiverSet(_feeReceiver);
    }

    /**
     * @notice Set the price feed used in the protocol
     * @param _priceFeed Price feed address
     */
    function setPriceFeed(address _priceFeed) external onlyOwner {
        priceFeed = _priceFeed;
        emit PriceFeedSet(_priceFeed);
    }

    /**
     * @notice Set the guardian address
               The guardian can execute some emergency actions
     * @param _guardian Guardian address
     */
    function setGuardian(address _guardian) external onlyOwner {
        guardian = _guardian;
        emit GuardianSet(_guardian);
    }

    /**
     * @notice Usable for deployment tasks
     * @param _manager Manager address
     */
    function setManager(address _manager) external onlyOwner {
        manager = _manager;
        emit ManagerSet(_manager);
    }

    /// @notice Bootstrap period is added to current timestamp
    function setLspBootstrapPeriod(uint64 _bootstrapPeriod) external onlyOwner {
        lspBootstrapPeriod = uint64(block.timestamp) + _bootstrapPeriod;

        emit LSPBootstrapPeriodSet(_bootstrapPeriod);
    }

    function setRebalancerFee(address _rebalancer, uint16 _entryFee, uint16 _exitFee) external onlyOwner {
        require(_entryFee <= 1e4 && _exitFee <= 1e4, "Fee too high");
        rebalancerFee[_rebalancer] = RebalancerFeeInfo({exists: true, entryFee: _entryFee, exitFee: _exitFee});
        emit RebalancerFees(_rebalancer, _entryFee, _exitFee);
    }

    function setEntryFee(uint16 _fee) external onlyOwner {
        require(_fee <= 1e4, "Fee too high");
        lspEntryFee = _fee;
        emit EntryFeeSet(_fee);
    }

    function setExitFee(uint16 _fee) external onlyOwner {
        require(_fee <= 1e4, "Fee too high");
        lspExitFee = _fee;
        emit ExitFeeSet(_fee);
    }

    function setPeripheryFlashLoanFee(address _periphery, uint16 _nectFee, bool _existsForNect) external onlyOwner {
        require(_nectFee <= 1e4, "Fee too high");

        peripheryFlashLoanFee[_periphery] = FeeInfo({
            existsForNect: _existsForNect,
            nectFee: _nectFee
        });

        emit PeripheryFlashLoanFee(_periphery, _nectFee);
    }

    function commitTransferOwnership(address newOwner) external onlyOwner {
        pendingOwner = newOwner;
        ownershipTransferDeadline = block.timestamp + OWNERSHIP_TRANSFER_DELAY;

        emit NewOwnerCommitted(msg.sender, newOwner, block.timestamp + OWNERSHIP_TRANSFER_DELAY);
    }

    function acceptTransferOwnership() external {
        require(msg.sender == pendingOwner, "Only new owner");
        require(block.timestamp >= ownershipTransferDeadline, "Deadline not passed");

        emit NewOwnerAccepted(owner, msg.sender);

        owner = pendingOwner;
        pendingOwner = address(0);
        ownershipTransferDeadline = 0;
    }

    function revokeTransferOwnership() external onlyOwner {
        emit NewOwnerRevoked(msg.sender, pendingOwner);

        pendingOwner = address(0);
        ownershipTransferDeadline = 0;
    }

    function getPeripheryFlashLoanFee(address periphery) external view returns (uint16) {
        FeeInfo memory info = peripheryFlashLoanFee[periphery];

        if (msg.sender == nect) {
            if (info.existsForNect) {
                return info.nectFee;
            }
        }

        return DEFAULT_FLASH_LOAN_FEE;
    }

    function getLspEntryFee(address rebalancer) external view returns (uint16) {
        if (rebalancerFee[rebalancer].exists) {
            return rebalancerFee[rebalancer].entryFee;
        } else {
            return lspEntryFee;
        }
    }

    function getLspExitFee(address rebalancer) external view returns (uint16) {
        if (rebalancerFee[rebalancer].exists) {
            return rebalancerFee[rebalancer].exitFee;
        } else {
            return lspExitFee;
        }
    }
}