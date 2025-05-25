// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IPriceFeed {
    struct FeedType {
        address spotOracle;
        bool isCollVault;
    }

    event NewOracleRegistered(address token, address chainlinkAggregator, address underlyingDerivative);
    event PriceFeedStatusUpdated(address token, address oracle, bool isWorking);
    event PriceRecordUpdated(address indexed token, uint256 _price);
    event NewCollVaultRegistered(address collVault, bool enable);
    event NewSpotOracleRegistered(address token, address spotOracle);

    function fetchPrice(address _token) external view returns (uint256);

    function getMultiplePrices(address[] memory _tokens) external view returns (uint256[] memory prices);

    function setOracle(
        address _token,
        address _chainlinkOracle,
        uint32 _heartbeat,
        uint16 _staleThreshold,
        address underlyingDerivative
    ) external;

    function whitelistCollateralVault(address _collateralVaultShareToken, bool enable) external;
    
    function setSpotOracle(address _token, address _spotOracle) external;
    
    function MAX_PRICE_DEVIATION_FROM_PREVIOUS_ROUND() external view returns (uint256);

    function BERABORROW_CORE() external view returns (address);

    function RESPONSE_TIMEOUT() external view returns (uint256);

    function TARGET_DIGITS() external view returns (uint256);

    function guardian() external view returns (address);

    function oracleRecords(
        address
    )
        external
        view
        returns (
        address chainLinkOracle,
        uint8 decimals,
        uint32 heartbeat,
        uint16 staleThreshold,
        address underlyingDerivative
    );

    function isCollVault(address _collateralVaultShareToken) external view returns (bool);

    function isStableBPT(address _oracle) external view returns (bool);

    function isWeightedBPT(address _oracle) external view returns (bool);

    function getSpotOracle(address _token) external view returns (address);

    function feedType(address _token) external view returns (FeedType memory);

    function owner() external view returns (address);
}
