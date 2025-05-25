interface IMetaBeraborrowCore {
    // ---------------------------------
    // Structures
    // ---------------------------------
    struct FeeInfo {
        bool existsForNect;
        uint16 nectFee;
    }

    struct RebalancerFeeInfo {
        bool exists;
        uint16 entryFee;
        uint16 exitFee;
    }

    // ---------------------------------
    // Public constants
    // ---------------------------------
    function OWNERSHIP_TRANSFER_DELAY() external view returns (uint256);
    function DEFAULT_FLASH_LOAN_FEE() external view returns (uint16);

    // ---------------------------------
    // Public state variables
    // ---------------------------------
    function nect() external view returns (address);
    function lspEntryFee() external view returns (uint16);
    function lspExitFee() external view returns (uint16);

    function feeReceiver() external view returns (address);
    function priceFeed() external view returns (address);
    function owner() external view returns (address);
    function pendingOwner() external view returns (address);
    function ownershipTransferDeadline() external view returns (uint256);
    function manager() external view returns (address);
    function guardian() external view returns (address);
    function paused() external view returns (bool);
    function lspBootstrapPeriod() external view returns (uint64);

    // ---------------------------------
    // External functions
    // ---------------------------------
    function setFeeReceiver(address _feeReceiver) external;
    function setPriceFeed(address _priceFeed) external;
    function setGuardian(address _guardian) external;
    function setManager(address _manager) external;

    /**
     * @notice Global pause/unpause
     *         Pausing halts new deposits/borrowing across the protocol
     */
    function setPaused(bool _paused) external;

    /**
     * @notice Extend or change the LSP bootstrap period,
     *         after which certain protocol mechanics change
     */
    function setLspBootstrapPeriod(uint64 _bootstrapPeriod) external;

    /**
     * @notice Set a custom flash-loan fee for a given periphery contract
     * @param _periphery Target contract that will get this custom fee
     * @param _nectFee Fee in basis points (bp)
     * @param _existsForNect Whether this custom fee is used when the caller = `nect`
     */
    function setPeripheryFlashLoanFee(address _periphery, uint16 _nectFee, bool _existsForNect) external;

    /**
     * @notice Begin the ownership transfer process
     * @param newOwner The address proposed to be the new owner
     */
    function commitTransferOwnership(address newOwner) external;

    /**
     * @notice Finish the ownership transfer, after the mandatory delay
     */
    function acceptTransferOwnership() external;

    /**
     * @notice Revoke a pending ownership transfer
     */
    function revokeTransferOwnership() external;

    /**
     * @notice Look up a custom flash-loan fee for a specific periphery contract
     * @param peripheryContract The contract that might have a custom fee
     * @return The flash-loan fee in basis points
     */
    function getPeripheryFlashLoanFee(address peripheryContract) external view returns (uint16);

    /**
     * @notice Set / override entry & exit fees for a special rebalancer contract
     */
    function setRebalancerFee(address _rebalancer, uint16 _entryFee, uint16 _exitFee) external;

    /**
     * @notice Set the LSP entry fee globally
     * @param _fee Fee in basis points
     */
    function setEntryFee(uint16 _fee) external;

    /**
     * @notice Set the LSP exit fee globally
     * @param _fee Fee in basis points
     */
    function setExitFee(uint16 _fee) external;

    /**
     * @notice Look up the LSP entry fee for a rebalancer
     * @param rebalancer Possibly has a special fee
     * @return The entry fee in basis points
     */
    function getLspEntryFee(address rebalancer) external view returns (uint16);

    /**
     * @notice Look up the LSP exit fee for a rebalancer
     * @param rebalancer Possibly has a special fee
     * @return The exit fee in basis points
     */
    function getLspExitFee(address rebalancer) external view returns (uint16);

    // ---------------------------------
    // Events
    // ---------------------------------
    event NewOwnerCommitted(address indexed owner, address indexed pendingOwner, uint256 deadline);
    event NewOwnerAccepted(address indexed oldOwner, address indexed newOwner);
    event NewOwnerRevoked(address indexed owner, address indexed revokedOwner);

    event FeeReceiverSet(address indexed feeReceiver);
    event PriceFeedSet(address indexed priceFeed);
    event GuardianSet(address indexed guardian);
    event ManagerSet(address indexed manager);
    event PeripheryFlashLoanFee(address indexed periphery, uint16 nectFee);
    event LSPBootstrapPeriodSet(uint64 bootstrapPeriod);
    event RebalancerFees(address indexed rebalancer, uint16 entryFee, uint16 exitFee);
    event EntryFeeSet(uint16 fee);
    event ExitFeeSet(uint16 fee);
    event Paused();
    event Unpaused();
}

interface IFeeHook {
    enum Action {
        DEPOSIT,
        MINT,
        WITHDRAW,
        REDEEM
    }

    function calcFee(address caller, address stable, uint amount, Action action) external view returns (uint feeInBP);
}

contract FeeHook is IFeeHook {
    struct Fee {
        bool exists;
        uint16 entryFeeInBp;
        uint16 exitFeeInBp;
    }

    IMetaBeraborrowCore metaBeraborrowCore;

    mapping(address actor => Fee) public customFee;

    constructor(address _metaBeraborrowCore) {
        metaBeraborrowCore = IMetaBeraborrowCore(_metaBeraborrowCore);
    }

    function calcFee(address caller, address stable, uint256 amount, Action action) external view returns (uint256 feeInBP) {
        Fee memory fee = customFee[caller];

        if (action == Action.DEPOSIT || action == Action.MINT) {
            return fee.exists ? fee.entryFeeInBp : 5; // 0.05%
        }

        return fee.exists ? fee.exitFeeInBp : 30; // 0.3%
    }

    function setCustomFee(address actor, Fee calldata fee) external {
        require(msg.sender == metaBeraborrowCore.owner(), "Not owner");

        customFee[actor] = fee;
    }
}