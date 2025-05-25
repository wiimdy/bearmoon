// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IKdkToken} from "./IKdkToken.sol";
import {IXKdkTokenUsage} from "../IXKdkTokenUsage.sol";

interface IXKdkToken is IERC20 {
    function kdkToken() external view returns (IKdkToken);
    function usageAllocations(address userAddress, address usageAddress) external view returns (uint256 allocation);

    function allocateFromUsage(address userAddress, uint256 amount) external;
    function convertTo(uint256 amount, address to) external;
    function deallocateFromUsage(address userAddress, uint256 amount) external;

    function isTransferWhitelisted(address account) external view returns (bool);
    function isWhitelister(address account) external view returns (bool);

    //Ownable functions
    function setKdkAddress(address _kdkAddress) external;
    function mint(address recipient, uint256 amount) external;
    function updateRedeemSettings(uint256 minRedeemRatio_, uint256 maxRedeemRatio_, uint256 minRedeemDuration_, uint256 maxRedeemDuration_, uint256 redeemRewardsAdjustment_) external;
    function updateRewardsAddress(IXKdkTokenUsage _rewardsAddress) external;
    function updateDeallocationFee(address usageAddress, uint256 fee) external;
    function updateWhitelister(address account, bool value) external;
    function updateTransferWhitelist(address account, bool value) external;
}