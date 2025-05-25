// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;
import "../interfaces/utils/integrations/IAggregatorV3Interface.sol";
import "../dependencies/BeraborrowMath.sol";
import "../dependencies/BeraborrowOwnable.sol";
import {IInfraredCollateralVault} from "../interfaces/core/vaults/IInfraredCollateralVault.sol";
import {ISpotOracle} from "../interfaces/core/spotOracles/ISpotOracle.sol";

/**
    @title Beraborrow Multi Token Price Feed
    @notice Based on Gravita's PriceFeed:
            https://github.com/Gravita-Protocol/Gravita-SmartContracts/blob/9b69d555f3567622b0f84df8c7f1bb5cd9323573/contracts/PriceFeed.sol
 */
contract PriceFeed is BeraborrowOwnable {
    uint public constant MAX_ORACLE_HEARTBEAT = 2 days;

    struct OracleRecord {
        IAggregatorV3Interface chainLinkOracle;
        uint8 decimals;
        uint32 heartbeat;
        // Responses are considered stale this many seconds after the oracle's heartbeat
        uint16 staleThreshold;
        address underlyingDerivative;
    }

    struct FeedResponse {
        uint80 roundId;
        int256 answer;
        uint256 timestamp;
        bool success;
    }

    struct FeedType {
        ISpotOracle spotOracle;
        bool isCollVault;
    }

    // Custom Errors --------------------------------------------------------------------------------------------------

    error PriceFeed__PotentialDos();
    error PriceFeed__InvalidFeedResponseError(address token);
    error PriceFeed__FeedFrozenError(address token);
    error PriceFeed__HeartbeatOutOfBoundsError();
    error PriceFeed__InvalidResponse(address _token);

    // Events ---------------------------------------------------------------------------------------------------------

    event NewOracleRegistered(address token, address chainlinkAggregator, address underlyingDerivative);
    event NewCollVaultRegistered(address collVault, bool enable);
    event NewSpotOracleRegistered(address token, address spotOracle);

    /** Constants ---------------------------------------------------------------------------------------------------- */

    // Used to convert a chainlink price answer to an 18-digit precision uint
    uint256 public constant TARGET_DIGITS = 18;

    // Maximum deviation allowed between two consecutive Chainlink oracle prices. 18-digit precision.
    uint256 public constant MAX_PRICE_DEVIATION_FROM_PREVIOUS_ROUND = 5e17; // 50%

    // State ------------------------------------------------------------------------------------------------------------

    mapping(address => OracleRecord) public oracleRecords;
    mapping(address => FeedType) public feedType;

    constructor(address _metaBeraborrowCore) BeraborrowOwnable(_metaBeraborrowCore) {
        if (_metaBeraborrowCore == address(0)) {
            revert("PriceFeed: 0 address");
        }
    }

    modifier onlyOwnerOrManager() {
        require(msg.sender == owner() || msg.sender == BERABORROW_CORE.manager(), "Only owner or manager");
        _;
    }

    // Admin routines ---------------------------------------------------------------------------------------------------

    /**
        @notice Set the oracle for a specific token
        @dev IMPORTANT: When the collateral whitelisted is a reward token in any InfraredCollateralVault, `internalizeDonations` should be called for the rewards taken meanwhile the feed was not set.
        @param _token Address of the token to set the oracle for
        @param _chainlinkOracle Address of the chainlink oracle for this token
        @param _heartbeat Oracle heartbeat, in seconds
        @param _staleThreshold Time in seconds after which the price is considered stale
        @param underlyingDerivative Address of the underlying derivative token, if any
     */
    function setOracle(
        address _token,
        address _chainlinkOracle,
        uint32 _heartbeat,
        uint16 _staleThreshold,
        address underlyingDerivative
    ) public onlyOwnerOrManager {
        require(_token != underlyingDerivative, "PriceFeed: token cannot point to itself");
        require(oracleRecords[underlyingDerivative].underlyingDerivative == address(0), "PriceFeed: only to USD pairs");
        require(_isSpotOracleNotSet(_token) && !isCollVault(_token), "PriceFeed: token already whitelisted");
        if (_heartbeat > MAX_ORACLE_HEARTBEAT) revert PriceFeed__HeartbeatOutOfBoundsError();
        IAggregatorV3Interface newFeed = IAggregatorV3Interface(_chainlinkOracle);
        (FeedResponse memory currResponse, FeedResponse memory prevResponse) = _fetchFeedResponses(newFeed);
        
        if (_token == address(0)) revert PriceFeed__PotentialDos();

        if (!_isFeedWorking(currResponse, prevResponse)) {
            revert PriceFeed__InvalidFeedResponseError(_token);
        }
        if (_isPriceStale(currResponse.timestamp, _heartbeat, _staleThreshold)) {
            revert PriceFeed__FeedFrozenError(_token);
        }

        OracleRecord memory record = OracleRecord({
            chainLinkOracle: newFeed,
            decimals: newFeed.decimals(),
            heartbeat: _heartbeat,
            staleThreshold: _staleThreshold,
            underlyingDerivative: underlyingDerivative
        });

        oracleRecords[_token] = record;

        _processFeedResponses(_token, record, currResponse, prevResponse);
        emit NewOracleRegistered(_token, _chainlinkOracle, underlyingDerivative);
    }

    function whitelistCollateralVault(address _token, bool _enable) external onlyOwnerOrManager {
        require(_token != address(0), "PriceFeed: token 0 address");
        require(!_enable || _isClOracleNotSet(_token) && _isSpotOracleNotSet(_token), "PriceFeed: token already whitelisted");

        feedType[_token].isCollVault = _enable;

        emit NewCollVaultRegistered(_token, _enable);
    }

    function setSpotOracle(address _token, address _spotOracle) external onlyOwnerOrManager {
        require(_token != address(0), "PriceFeed: token 0 address");
        require(_spotOracle == address(0) || _isClOracleNotSet(_token) && !isCollVault(_token), "PriceFeed: token already whitelisted");

        feedType[_token].spotOracle = ISpotOracle(_spotOracle);

        emit NewSpotOracleRegistered(_token, _spotOracle);
    }

    // Public functions -------------------------------------------------------------------------------------------------

    /**
        @notice Get the latest price returned from the oracle
        @dev You can obtain these values by calling `DenManager.fetchPrice()`
             rather than directly interacting with this contract.
        @param _token Token to fetch the price for
        @return The latest valid price for the requested token
     */
    function fetchPrice(address _token) public view returns (uint256) {
        if (feedType[_token].isCollVault) {
            return IInfraredCollateralVault(_token).fetchPrice();
        }

        ISpotOracle spotOracle = feedType[_token].spotOracle;
        if (address(spotOracle) != address(0)) {
            return spotOracle.fetchPrice();
        }

        OracleRecord memory oracle = oracleRecords[_token];

        require(address(oracle.chainLinkOracle) != address(0), "PriceFeed: token not supported");

        (FeedResponse memory currResponse, FeedResponse memory prevResponse) = _fetchFeedResponses(
            oracle.chainLinkOracle
        );

        return _processFeedResponses(_token, oracle, currResponse, prevResponse);
    }

    // Internal functions -----------------------------------------------------------------------------------------------

    function _processFeedResponses(
        address _token,
        OracleRecord memory oracle,
        FeedResponse memory _currResponse,
        FeedResponse memory _prevResponse
    ) internal view returns (uint256) {
        uint8 decimals = oracle.decimals;
        bool isValidResponse = _isFeedWorking(_currResponse, _prevResponse) &&
            !_isPriceStale(_currResponse.timestamp, oracle.heartbeat, oracle.staleThreshold) &&
            !_isPriceChangeAboveMaxDeviation(_currResponse, _prevResponse, decimals);

        if (isValidResponse) {
            uint256 scaledPrice = _scalePriceByDigits(uint256(_currResponse.answer), decimals);
            if (oracle.underlyingDerivative != address(0)) {
                uint256 underlyingPrice = fetchPrice(oracle.underlyingDerivative);
                scaledPrice = (scaledPrice * underlyingPrice) / 1 ether;
            }
            return scaledPrice;
        } else {
            revert PriceFeed__InvalidResponse(_token);
        }
    }

    function _fetchFeedResponses(
        IAggregatorV3Interface oracle
    ) internal view returns (FeedResponse memory currResponse, FeedResponse memory prevResponse) {
        currResponse = _fetchCurrentFeedResponse(oracle);
        prevResponse = _fetchPrevFeedResponse(oracle, currResponse.roundId);
    }

    function _isPriceStale(uint256 _priceTimestamp, uint256 _heartbeat, uint16 _staleThreshold) internal view returns (bool) {
        return block.timestamp - _priceTimestamp > _heartbeat + _staleThreshold;
    }

    function _isFeedWorking(
        FeedResponse memory _currentResponse,
        FeedResponse memory _prevResponse
    ) internal view returns (bool) {
        return _isValidResponse(_currentResponse) && _isValidResponse(_prevResponse);
    }

    function _isValidResponse(FeedResponse memory _response) internal view returns (bool) {
        return
            (_response.success) &&
            (_response.roundId != 0) &&
            (_response.timestamp != 0) &&
            (_response.timestamp <= block.timestamp) &&
            (_response.answer > 0);
    }

    function _isPriceChangeAboveMaxDeviation(
        FeedResponse memory _currResponse,
        FeedResponse memory _prevResponse,
        uint8 decimals
    ) internal pure returns (bool) {
        uint256 currentScaledPrice = _scalePriceByDigits(uint256(_currResponse.answer), decimals);
        uint256 prevScaledPrice = _scalePriceByDigits(uint256(_prevResponse.answer), decimals);
        
        uint256 minPrice = BeraborrowMath._min(currentScaledPrice, prevScaledPrice);
        uint256 maxPrice = BeraborrowMath._max(currentScaledPrice, prevScaledPrice);

        uint256 percentDeviation = ((maxPrice - minPrice) * BeraborrowMath.DECIMAL_PRECISION) / prevScaledPrice;
        
        return percentDeviation > MAX_PRICE_DEVIATION_FROM_PREVIOUS_ROUND;
    }

    function _scalePriceByDigits(uint256 _price, uint256 _answerDigits) internal pure returns (uint256) {
        if (_answerDigits == TARGET_DIGITS) {
            return _price;
        } else if (_answerDigits < TARGET_DIGITS) {
            // Scale the returned price value up to target precision
            return _price * (10 ** (TARGET_DIGITS - _answerDigits));
        } else {
            // Scale the returned price value down to target precision
            return _price / (10 ** (_answerDigits - TARGET_DIGITS));
        }
    }

    function _fetchCurrentFeedResponse(
        IAggregatorV3Interface _priceAggregator
    ) internal view returns (FeedResponse memory response) {
        try _priceAggregator.latestRoundData() returns (
            uint80 roundId,
            int256 answer,
            uint256 /* startedAt */,
            uint256 timestamp,
            uint80 /* answeredInRound */
        ) {
            // If call to Chainlink succeeds, return the response and success = true
            response.roundId = roundId;
            response.answer = answer;
            response.timestamp = timestamp;
            response.success = true;
        } catch {
            // If call to Chainlink aggregator reverts, return a zero response with success = false
            return response;
        }
    }

    function _fetchPrevFeedResponse(
        IAggregatorV3Interface _priceAggregator,
        uint80 _currentRoundId
    ) internal view returns (FeedResponse memory prevResponse) {
        if (_currentRoundId == 0) {
            return prevResponse;
        }
        unchecked {
            try _priceAggregator.getRoundData(_currentRoundId - 1) returns (
                uint80 roundId,
                int256 answer,
                uint256 /* startedAt */,
                uint256 timestamp,
                uint80 /* answeredInRound */
            ) {
                prevResponse.roundId = roundId;
                prevResponse.answer = answer;
                prevResponse.timestamp = timestamp;
                prevResponse.success = true;
            } catch {}
        }
    }

    function isCollVault(address _token) public view returns (bool) {
        return feedType[_token].isCollVault;
    }

    function getSpotOracle(address _token) public view returns (address) {
        return address(feedType[_token].spotOracle);
    }

    function getMultiplePrices(address[] memory _tokens) external view returns (uint256[] memory prices) {
        uint length = _tokens.length;
        prices = new uint256[](length);
        for (uint256 i; i < length; i++) {
            prices[i] = fetchPrice(_tokens[i]);
        }
    }

    function _isClOracleNotSet(address token) private view returns (bool) {
        return oracleRecords[token].chainLinkOracle == IAggregatorV3Interface(address(0));
    }

    function _isSpotOracleNotSet(address token) private view returns (bool) {
        return feedType[token].spotOracle == ISpotOracle(address(0));
    }
}
