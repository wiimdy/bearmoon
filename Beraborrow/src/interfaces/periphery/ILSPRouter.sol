// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

interface ILSPRouter {

    struct RedeemPreferredUnderlyingParams {
        uint shares;
        address[] preferredUnderlyingTokens;
        address receiver;
        uint minAssetsWithdrawn;
        uint[] minUnderlyingWithdrawn;
        bool unwrap;
        uint8 redeemedTokensLength;
    }

    struct RedeemPreferredUnderlyingToOneParams {
        uint shares;
        address[] preferredUnderlyingTokens;
        address receiver;
        address targetToken;
        uint minAssetsWithdrawn;
        uint[] minUnderlyingWithdrawn;
        bytes[] pathDefinitions;
        uint[] minOutputs;
        uint[] quoteAmounts;
        uint minTargetTokenAmount;
        address executor;
        uint32 referralCode;
        uint8 redeemedTokensLength;
    }

    struct RedeemWithoutPrederredUnderlyingParams {
        uint shares;
        address receiver;
        uint minAssetsWithdrawn;
        uint[] minUnderlyingWithdrawn;
        uint receivedTokensLengthHint;
        address[] tokensToClaim;
        bool unwrap;
    }

    struct WithdrawFromlspParams {
        uint assets;
        address receiver;
        uint maxSharesWithdrawn;
        bool unwrap;     
        uint[] minUnderlyingWithdrawn;
        uint receivedTokensLengthHint;
        address[] tokensToClaim;
    }

    struct SwapAllTokensToOneParams {
        address receiver;
        bytes[] pathDefinitions;
        uint[] minOutputs;
        uint[] quoteAmounts;
        uint minTargetTokenAmount;
        address executor;
        uint32 referralCode;
    }

    struct DepositTokenParams {
        address inputToken;
        uint inputAmount; 
        uint minSharesReceived;  
        address receiver;   
        bytes dexCalldata;
    }

    function redeemPreferredUnderlying(
        RedeemPreferredUnderlyingParams calldata p
    ) external returns (uint assets, address[] memory tokens, uint[] memory amounts);

    function redeemPreferredUnderlyingToOne(
        RedeemPreferredUnderlyingToOneParams calldata params
    ) external returns (uint assets, uint totalAmountOut);

    function redeem(
        RedeemWithoutPrederredUnderlyingParams calldata params
    ) external returns (uint assets, address[] memory tokens, uint[] memory amounts);

    function withdraw(
        WithdrawFromlspParams calldata params
    ) external returns (uint shares, address[] memory tokens, uint[] memory amounts);

    function deposit(
        DepositTokenParams calldata params
    ) external payable returns (uint shares);

    function previewRedeemPreferredUnderlying(uint shares, address[] calldata preferredUnderlyingTokens, bool unwrap) external view returns (uint assets, address[] memory tokens, uint[] memory amounts);
}
