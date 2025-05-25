// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./interfaces/tokens/IKdkToken.sol";
import "./interfaces/tokens/IXKdkToken.sol";
import "./interfaces/IXKdkTokenUsage.sol";


/*
 * xKDK is Kodiak's escrowed governance token obtainable by converting KDK to it
 * It's non-transferable, except from/to whitelisted addresses
 * It can be converted back to KDK through a vesting process
 * This contract is made to receive xKDK deposits from users in order to allocate them to Usages (plugins) contracts
 */
contract XKodiakToken is Ownable, ReentrancyGuard, ERC20("Kodiak pre-TGE rewards", "xKDK"), IXKdkToken {
    using Address for address;
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IKdkToken;

    struct XKdkBalance {
        uint256 allocatedAmount; // Amount of xKDK allocated to a Usage
        uint256 redeemingAmount; // Total amount of xKDK currently being redeemed
    }

    struct RedeemInfo {
        uint256 kdkAmount; // KDK amount to receive when vesting has ended
        uint256 xKodiakAmount; // xKDK amount to redeem
        uint256 endTime;
        IXKdkTokenUsage rewardsAddress;
        uint256 rewardsAllocation; // Share of redeeming xKDK to allocate to the Rewards Usage contract
    }

    IKdkToken public kdkToken; // KDK token to convert to/from
    IXKdkTokenUsage public rewardsAddress; // Kodiak rewards contract
    address public burnAddress;

    EnumerableSet.AddressSet private _whitelisters; // addresses allowed to whitelist/unwhitelist
    EnumerableSet.AddressSet private _transferWhitelist; // addresses allowed to send/receive xKDK

    mapping(address => mapping(address => uint256)) public usageApprovals; // Usage approvals to allocate xKDK
    mapping(address => mapping(address => uint256)) public override usageAllocations; // Active xKDK allocations to usages

    uint256 public constant MAX_DEALLOCATION_FEE = 200; // 2%
    mapping(address => uint256) public usagesDeallocationFee; // Fee paid when deallocating xKDK

    uint256 public constant MAX_FIXED_RATIO = 100; // 100%

    // Redeeming min/max settings
    uint256 public minRedeemRatio = 50; // 1:0.5
    uint256 public maxRedeemRatio = 100; // 1:1
    uint256 public minRedeemDuration = 15 days; // 1296000s
    uint256 public maxRedeemDuration = 180 days; // 7776000s
    // Adjusted rewards for redeeming xKDK
    uint256 public redeemRewardsAdjustment = 25; // 25%

    mapping(address => XKdkBalance) public xKodiakBalances; // User's xKDK balances
    mapping(address => RedeemInfo[]) public userRedeems; // User's redeeming instances


    constructor() {
        _transferWhitelist.add(address(this));
    }

    /********************************************/
    /****************** EVENTS ******************/
    /********************************************/

    event ApproveUsage(address indexed userAddress, address indexed usageAddress, uint256 amount);
    event Convert(address indexed from, address to, uint256 amount);
    event SetKdkAddress(address kdkAddress);
    event UpdateRedeemSettings(uint256 minRedeemRatio, uint256 maxRedeemRatio, uint256 minRedeemDuration, uint256 maxRedeemDuration, uint256 redeemRewardsAdjustment);
    event UpdateRewardsAddress(address previousRewardsAddress, address newRewardsAddress);
    event UpdateDeallocationFee(address indexed usageAddress, uint256 fee);
    event UpdateTransferWhitelist(address account, bool add);
    event UpdateWhitelister(address account, bool add);
    event Redeem(address indexed userAddress, uint256 xKodiakAmount, uint256 kodiakAmount, uint256 duration);
    event FinalizeRedeem(address indexed userAddress, uint256 xKodiakAmount, uint256 kodiakAmount);
    event CancelRedeem(address indexed userAddress, uint256 xKodiakAmount);
    event UpdateRedeemRewardsAddress(address indexed userAddress, uint256 redeemIndex, address previousRewardsAddress, address newRewardsAddress);
    event Allocate(address indexed userAddress, address indexed usageAddress, uint256 amount);
    event Deallocate(address indexed userAddress, address indexed usageAddress, uint256 amount, uint256 fee);
    event BurnAddressSet(address burnAddress);
    /***********************************************/
    /****************** MODIFIERS ******************/
    /***********************************************/

    /// @dev Check if kdk has been set
    modifier kdkActive() {
        require(address(kdkToken) != address(0), "KDK not set");
        _;
    }

    /// @dev Check if caller is allowed to update the transfer whitelist
    modifier onlyWhiteLister() {
        require(isWhitelister(msg.sender), "onlyWhiteLister: not allowed");
        _;
    }

    /// @dev Check if a redeem entry exists
    modifier validateRedeem(address userAddress, uint256 redeemIndex) {
        require(redeemIndex < userRedeems[userAddress].length, "validateRedeem: redeem entry does not exist");
        _;
    }

    /**************************************************/
    /****************** PUBLIC VIEWS ******************/
    /**************************************************/

    /// @dev Returns user's xKDK balances
    function getXKodiakBalance(address userAddress) external view returns (uint256 allocatedAmount, uint256 redeemingAmount) {
        XKdkBalance storage balance = xKodiakBalances[userAddress];
        return (balance.allocatedAmount, balance.redeemingAmount);
    }

    /// @dev returns redeemable KDK for "amount" of xKDK vested for "duration" seconds
    function getKodiakByVestingDuration(uint256 amount, uint256 duration) public view returns (uint256) {
        if(duration < minRedeemDuration || address(kdkToken) == address(0)) {
            return 0;
        }

        // capped to maxRedeemDuration
        if (duration > maxRedeemDuration) {
            return amount.mul(maxRedeemRatio).div(100);
        }

        uint256 ratio = minRedeemRatio.add(
            (duration.sub(minRedeemDuration)).mul(maxRedeemRatio.sub(minRedeemRatio))
            .div(maxRedeemDuration.sub(minRedeemDuration))
        );

        return amount.mul(ratio).div(100);
    }

    /// @dev returns quantity of "userAddress" pending redeems
    function getUserRedeemsLength(address userAddress) external view returns (uint256) {
        return userRedeems[userAddress].length;
    }

    /// @dev returns "userAddress" info for a pending redeem identified by "redeemIndex"
    function getUserRedeem(address userAddress, uint256 redeemIndex) external view validateRedeem(userAddress, redeemIndex) returns (uint256 kdkAmount, uint256 xKdkAmount, uint256 endTime, address rewardsContract, uint256 rewardsAllocation) {
        RedeemInfo storage _redeem = userRedeems[userAddress][redeemIndex];
        return (_redeem.kdkAmount, _redeem.xKodiakAmount, _redeem.endTime, address(_redeem.rewardsAddress), _redeem.rewardsAllocation);
    }

    /// @dev returns approved xKodiak to allocate from "userAddress" to "usageAddress"
    function getUsageApproval(address userAddress, address usageAddress) external view returns (uint256) {
        return usageApprovals[userAddress][usageAddress];
    }

    /// @dev returns allocated xKodiak from "userAddress" to "usageAddress"
    function getUsageAllocation(address userAddress, address usageAddress) external view returns (uint256) {
        return usageAllocations[userAddress][usageAddress];
    }

    /// @dev returns length of transferWhitelist array
    function transferWhitelistLength() external view returns (uint256) {
        return _transferWhitelist.length();
    }

    /// @dev returns transferWhitelist array item's address for "index"
    function transferWhitelist(uint256 index) external view returns (address) {
        return _transferWhitelist.at(index);
    }

    /// @dev returns if "account" is allowed to send/receive xKDK
    function isTransferWhitelisted(address account) external override view returns (bool) {
        return _transferWhitelist.contains(account);
    }

    /// @dev returns if "account" is allowed to update transfer whitelist
    function isWhitelister(address account) public override view returns (bool) {
        return _whitelisters.contains(account) || account == owner();
    }

    /*******************************************************/
    /****************** OWNABLE FUNCTIONS ******************/
    /*******************************************************/
    /// @dev Set the KDK token address, can only be set once
    function setKdkAddress(address _kdk) external onlyOwner {
        require(address(kdkToken) == address(0), "KDK already set");
        kdkToken = IKdkToken(_kdk);
        require(kdkToken.balanceOf(address(this)) == totalSupply(), "xKDK not fully backed by KDK");
        emit SetKdkAddress(_kdk);
    }

    /// @dev Update name to Kodiak escrowed token after TGE
    function name() public view override returns (string memory) {
        return address(kdkToken) != address(0) ? "Kodiak escrowed token" : super.name();
    }

    /// @dev Allows owner to mint freely xKDK (before KDK is set)
    function mint(address recipient, uint256 amount) external onlyOwner {
        require(address(kdkToken) == address(0), "KDK already set, cannot mint anymore");
        require(totalSupply().add(amount) <= 100e6 ether, "Cannot exceed total supply");
        _mint(recipient, amount);
    }

    /// @dev Updates all redeem ratios and durations
    function updateRedeemSettings(uint256 minRedeemRatio_, uint256 maxRedeemRatio_, uint256 minRedeemDuration_, uint256 maxRedeemDuration_, uint256 redeemRewardsAdjustment_) external kdkActive onlyOwner {
        require(minRedeemRatio_ <= maxRedeemRatio_, "updateRedeemSettings: wrong ratio values");
        require(minRedeemDuration_ < maxRedeemDuration_, "updateRedeemSettings: wrong duration values");
        // should never exceed 100%
        require(maxRedeemRatio_ <= MAX_FIXED_RATIO && redeemRewardsAdjustment_ <= MAX_FIXED_RATIO, "updateRedeemSettings: wrong ratio values");

        minRedeemRatio = minRedeemRatio_;
        maxRedeemRatio = maxRedeemRatio_;
        minRedeemDuration = minRedeemDuration_;
        maxRedeemDuration = maxRedeemDuration_;
        redeemRewardsAdjustment = redeemRewardsAdjustment_;

        emit UpdateRedeemSettings(minRedeemRatio_, maxRedeemRatio_, minRedeemDuration_, maxRedeemDuration_, redeemRewardsAdjustment_);
    }

    /// @dev Updates rewards contract address
    function updateRewardsAddress(IXKdkTokenUsage rewardsAddress_) external kdkActive onlyOwner {
        // if set to 0, also set divs earnings while redeeming to 0
        if(address(rewardsAddress_) == address(0)) {
            redeemRewardsAdjustment = 0;
        }

        emit UpdateRewardsAddress(address(rewardsAddress), address(rewardsAddress_));
        rewardsAddress = rewardsAddress_;
    }

    /// @dev Updates fee paid by users when deallocating from "usageAddress"
    function updateDeallocationFee(address usageAddress, uint256 fee) external kdkActive onlyOwner {
        require(fee <= MAX_DEALLOCATION_FEE, "updateDeallocationFee: too high");

        usagesDeallocationFee[usageAddress] = fee;
        emit UpdateDeallocationFee(usageAddress, fee);
    }

    /// @dev Adds or removes addresses capable of updating the transfer whitelist
    function updateWhitelister(address account, bool add) external onlyOwner {
        require(account != owner(), "updateWhitelisters: Cannot add or remove owner from whitelisters");

        if(add) _whitelisters.add(account);
        else _whitelisters.remove(account);

        emit UpdateWhitelister(account, add);
    }

    /// @dev Adds or removes addresses from the transferWhitelist
    function updateTransferWhitelist(address account, bool add) external onlyWhiteLister {
        require(account != address(this), "updateTransferWhitelist: Cannot remove xKDK from whitelist");

        if(add) _transferWhitelist.add(account);
        else _transferWhitelist.remove(account);

        emit UpdateTransferWhitelist(account, add);
    }

    /// @dev Sets the burn address
    function setBurnAddress(address _burnAddress) external onlyOwner {
        burnAddress = _burnAddress;
        emit BurnAddressSet(_burnAddress);
    }

    /*****************************************************************/
    /******************  EXTERNAL PUBLIC FUNCTIONS  ******************/
    /*****************************************************************/


    /// @dev Approves "usage" address to get allocations up to "amount" of xKDK from msg.sender
    function approveUsage(IXKdkTokenUsage usage, uint256 amount) external kdkActive nonReentrant {
        require(address(usage) != address(0), "approveUsage: approve to the zero address");

        usageApprovals[msg.sender][address(usage)] = amount;
        emit ApproveUsage(msg.sender, address(usage), amount);
    }

    /// @dev Convert caller's "amount" of KDK to xKDK
    function convert(uint256 amount) external kdkActive nonReentrant {
        _convert(amount, msg.sender);
    }

    /// @dev Convert caller's "amount" of KDK to xKDK to "to" address
    function convertTo(uint256 amount, address to) external override kdkActive nonReentrant {
        require(address(msg.sender).isContract(), "convertTo: not allowed");
        _convert(amount, to);
    }

    /// @dev Initiates redeem process (xKDK to KDK)
    /// @notice Handles rewards' compensation allocation during the vesting process if needed
    function redeem(uint256 xKdkAmount, uint256 duration) external kdkActive nonReentrant {
        require(xKdkAmount > 0, "redeem: xKdkAmount cannot be null");
        require(duration >= minRedeemDuration, "redeem: duration too low");

        _transfer(msg.sender, address(this), xKdkAmount);
        XKdkBalance storage balance = xKodiakBalances[msg.sender];

        // get corresponding KDK amount
        uint256 kdkAmount = getKodiakByVestingDuration(xKdkAmount, duration);
        emit Redeem(msg.sender, xKdkAmount, kdkAmount, duration);

        // if redeeming is not immediate, go through vesting process
        if(duration > 0) {
            // add to SBT total
            balance.redeemingAmount = balance.redeemingAmount.add(xKdkAmount);

            // handle rewards during the vesting process
            uint256 rewardsAllocation = xKdkAmount.mul(redeemRewardsAdjustment).div(100);
            // only if compensation is active
            if(rewardsAllocation > 0) {
                // allocate to rewards
                rewardsAddress.allocate(msg.sender, rewardsAllocation, new bytes(0));
            }

            // add redeeming entry
            userRedeems[msg.sender].push(RedeemInfo(kdkAmount, xKdkAmount, _currentBlockTimestamp().add(duration), rewardsAddress, rewardsAllocation));
        } else {
            // immediately redeem for KDK
            _finalizeRedeem(msg.sender, xKdkAmount, kdkAmount);
        }
    }

    /// @dev Finalizes redeem process when vesting duration has been reached
    /// @notice Can only be called by the redeem entry owner
    function finalizeRedeem(uint256 redeemIndex) external kdkActive nonReentrant validateRedeem(msg.sender, redeemIndex) {
        XKdkBalance storage balance = xKodiakBalances[msg.sender];
        RedeemInfo storage _redeem = userRedeems[msg.sender][redeemIndex];
        require(_currentBlockTimestamp() >= _redeem.endTime, "finalizeRedeem: vesting duration has not ended yet");

        // remove from SBT total
        balance.redeemingAmount = balance.redeemingAmount.sub(_redeem.xKodiakAmount);
        _finalizeRedeem(msg.sender, _redeem.xKodiakAmount, _redeem.kdkAmount);

        // handle rewards compensation if any was active
        if(_redeem.rewardsAllocation > 0) {
            // deallocate from rewards
            IXKdkTokenUsage(_redeem.rewardsAddress).deallocate(msg.sender, _redeem.rewardsAllocation, new bytes(0));
        }

        // remove redeem entry
        _deleteRedeemEntry(redeemIndex);
    }

    /// @dev Updates rewards address for an existing active redeeming process
    /// @notice Can only be called by the redeem entry owner
    /// @notice Should only be used if rewards contract was to be migrated
    function updateRedeemRewardsAddress(uint256 redeemIndex) external kdkActive nonReentrant validateRedeem(msg.sender, redeemIndex) {
        RedeemInfo storage _redeem = userRedeems[msg.sender][redeemIndex];

        // only if the active rewards contract is not the same anymore
        if(rewardsAddress != _redeem.rewardsAddress && address(rewardsAddress) != address(0)) {
            if(_redeem.rewardsAllocation > 0) {
                // deallocate from old rewards contract
                _redeem.rewardsAddress.deallocate(msg.sender, _redeem.rewardsAllocation, new bytes(0));
                // allocate to new used rewards contract
                rewardsAddress.allocate(msg.sender, _redeem.rewardsAllocation, new bytes(0));
            }

            emit UpdateRedeemRewardsAddress(msg.sender, redeemIndex, address(_redeem.rewardsAddress), address(rewardsAddress));
            _redeem.rewardsAddress = rewardsAddress;
        }
    }

    /// @dev Cancels an ongoing redeem entry
    function cancelRedeem(uint256 redeemIndex) external kdkActive nonReentrant validateRedeem(msg.sender, redeemIndex) {
        XKdkBalance storage balance = xKodiakBalances[msg.sender];
        RedeemInfo storage _redeem = userRedeems[msg.sender][redeemIndex];

        // make redeeming xKDK available again
        balance.redeemingAmount = balance.redeemingAmount.sub(_redeem.xKodiakAmount);
        _transfer(address(this), msg.sender, _redeem.xKodiakAmount);

        // handle rewards compensation if any was active
        if(_redeem.rewardsAllocation > 0) {
            // deallocate from rewards
            IXKdkTokenUsage(_redeem.rewardsAddress).deallocate(msg.sender, _redeem.rewardsAllocation, new bytes(0));
        }

        emit CancelRedeem(msg.sender, _redeem.xKodiakAmount);

        // remove redeem entry
        _deleteRedeemEntry(redeemIndex);
    }


    /// @dev Allocates caller's "amount" of available xKDK to "usageAddress" contract
    /// @notice args specific to usage contract must be passed into "usageData"
    function allocate(address usageAddress, uint256 amount, bytes calldata usageData) external kdkActive nonReentrant {
        _allocate(msg.sender, usageAddress, amount);

        // allocates xKDK to usageContract
        IXKdkTokenUsage(usageAddress).allocate(msg.sender, amount, usageData);
    }

    /// @dev Allocates "amount" of available xKDK from "userAddress" to caller (ie usage contract)
    /// @notice Caller must have an allocation approval for the required xKDK from "userAddress"
    function allocateFromUsage(address userAddress, uint256 amount) external override kdkActive nonReentrant {
        _allocate(userAddress, msg.sender, amount);
    }

    /// @dev Deallocates caller's "amount" of available xKDK from "usageAddress" contract
    /// @notice args specific to usage contract must be passed into "usageData"
    function deallocate(address usageAddress, uint256 amount, bytes calldata usageData) external kdkActive nonReentrant {
        _deallocate(msg.sender, usageAddress, amount);

        // deallocate xKDK into usageContract
        IXKdkTokenUsage(usageAddress).deallocate(msg.sender, amount, usageData);
    }

    /// @dev Deallocates "amount" of allocated xKDK belonging to "userAddress" from caller (ie usage contract)
    /// @notice Caller can only deallocate xKDK from itself
    function deallocateFromUsage(address userAddress, uint256 amount) external override kdkActive nonReentrant {
        _deallocate(userAddress, msg.sender, amount);
    }

    /********************************************************/
    /****************** INTERNAL FUNCTIONS ******************/
    /********************************************************/
    /// @dev Convert caller's "amount" of KDK into xKDK to "to"
    function _convert(uint256 amount, address to) internal {
        require(amount != 0, "convert: amount cannot be null");

        // mint new xKDK
        _mint(to, amount);

        emit Convert(msg.sender, to, amount);
        kdkToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @dev Finalizes the redeeming process for "userAddress" by transferring him "kdkAmount" and removing "xKdkAmount" from supply
    /// @notice Any vesting check should be ran before calling this
    /// @notice KDK excess is automatically burnt
    function _finalizeRedeem(address userAddress, uint256 xKdkAmount, uint256 kdkAmount) internal {
        uint256 kdkExcess = xKdkAmount.sub(kdkAmount);

        // sends due KDK tokens
        kdkToken.safeTransfer(userAddress, kdkAmount);

        // burns KDK excess if any
        kdkToken.safeTransfer(burnAddress, kdkExcess);
        _burn(address(this), xKdkAmount);

        emit FinalizeRedeem(userAddress, xKdkAmount, kdkAmount);
    }

    /// @dev Allocates "userAddress" user's "amount" of available xKDK to "usageAddress" contract
    function _allocate(address userAddress, address usageAddress, uint256 amount) internal {
        require(amount > 0, "allocate: amount cannot be null");

        XKdkBalance storage balance = xKodiakBalances[userAddress];

        // approval checks if allocation request amount has been approved by userAddress to be allocated to this usageAddress
        uint256 approvedXKdk = usageApprovals[userAddress][usageAddress];
        require(approvedXKdk >= amount, "allocate: non authorized amount");

        // remove allocated amount from usage's approved amount
        usageApprovals[userAddress][usageAddress] = approvedXKdk.sub(amount);

        // update usage's allocatedAmount for userAddress
        usageAllocations[userAddress][usageAddress] = usageAllocations[userAddress][usageAddress].add(amount);

        // adjust user's xKDK balances
        balance.allocatedAmount = balance.allocatedAmount.add(amount);
        _transfer(userAddress, address(this), amount);

        emit Allocate(userAddress, usageAddress, amount);
    }

    /// @dev Deallocates "amount" of available xKDK to "usageAddress" contract
    /// @notice args specific to usage contract must be passed into "usageData"
    function _deallocate(address userAddress, address usageAddress, uint256 amount) internal {
        require(amount > 0, "deallocate: amount cannot be null");

        // check if there is enough allocated xKDK to this usage to deallocate
        uint256 allocatedAmount = usageAllocations[userAddress][usageAddress];
        require(allocatedAmount >= amount, "deallocate: non authorized amount");

        // remove deallocated amount from usage's allocation
        usageAllocations[userAddress][usageAddress] = allocatedAmount.sub(amount);

        uint256 deallocationFeeAmount = amount.mul(usagesDeallocationFee[usageAddress]).div(10000);

        // adjust user's xKDK balances
        XKdkBalance storage balance = xKodiakBalances[userAddress];
        balance.allocatedAmount = balance.allocatedAmount.sub(amount);
        _transfer(address(this), userAddress, amount.sub(deallocationFeeAmount));
        // burn corresponding KDK and xKDK
        kdkToken.safeTransfer(burnAddress, deallocationFeeAmount);
        _burn(address(this), deallocationFeeAmount);

        emit Deallocate(userAddress, usageAddress, amount, deallocationFeeAmount);
    }

    function _deleteRedeemEntry(uint256 index) internal {
        userRedeems[msg.sender][index] = userRedeems[msg.sender][userRedeems[msg.sender].length - 1];
        userRedeems[msg.sender].pop();
    }

    /// @dev Hook override to forbid transfers except from whitelisted addresses and minting
    function _beforeTokenTransfer(address from, address to, uint256 /*amount*/) internal view override {
        require(from == address(0) || _transferWhitelist.contains(from) || _transferWhitelist.contains(to), "transfer: not allowed");
    }

    /// @dev dev Utility function to get the current block timestamp
    function _currentBlockTimestamp() internal view virtual returns (uint256) {
        return block.timestamp;
    }

}