// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IPyth, PythStructs } from "@pythnetwork/IPyth.sol";

/**
 * @author Berachain Team
 */
contract MockPyth is IPyth {
    mapping(bytes32 id => PythStructs.Price data) public feeds;

    function setData(bytes32 id, int64 price, uint64 conf, int32 expo, uint256 publishTime) external {
        feeds[id].price = price;
        feeds[id].conf = conf;
        feeds[id].expo = expo;
        feeds[id].publishTime = publishTime;
    }

    function setReturn(bytes32 id, PythStructs.Price memory price) public {
        feeds[id] = price;
    }

    // Mocked functions
    function getPrice(bytes32 id) external view returns (PythStructs.Price memory) {
        return feeds[id];
    }

    function getPriceUnsafe(bytes32 id) external view returns (PythStructs.Price memory) {
        return feeds[id];
    }

    function getPriceNoOlderThan(bytes32 id, uint256 age) external view returns (PythStructs.Price memory) {
        age;
        return feeds[id];
    }

    function getValidTimePeriod() external view returns (uint256 validTimePeriod) {
        validTimePeriod;
    }

    function getEmaPrice(bytes32 id) external view returns (PythStructs.Price memory price) {
        id;
    }

    function getEmaPriceUnsafe(bytes32 id) external view returns (PythStructs.Price memory price) {
        id;
    }

    function getEmaPriceNoOlderThan(
        bytes32 id,
        uint256 age
    )
        external
        view
        override
        returns (PythStructs.Price memory price)
    {
        id;
    }

    function updatePriceFeeds(bytes[] calldata updateData) external payable override {
        updateData[0];
    }

    function updatePriceFeedsIfNecessary(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64[] calldata publishTimes
    )
        external
        payable
        override
    {
        updateData[0];
    }

    function getUpdateFee(bytes[] calldata updateData) external view override returns (uint256 feeAmount) {
        updateData[0];
    }

    function parsePriceFeedUpdates(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64 minPublishTime,
        uint64 maxPublishTime
    )
        external
        payable
        override
        returns (PythStructs.PriceFeed[] memory priceFeeds)
    {
        updateData[0];
    }

    function parsePriceFeedUpdatesUnique(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64 minPublishTime,
        uint64 maxPublishTime
    )
        external
        payable
        override
        returns (PythStructs.PriceFeed[] memory priceFeeds)
    {
        updateData[0];
    }

    function parseTwapPriceFeedUpdates(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds
    )
        external
        payable
        returns (PythStructs.TwapPriceFeed[] memory twapPriceFeeds)
    {
        updateData[0];
    }

    function parsePriceFeedUpdatesWithSlots(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64 minPublishTime,
        uint64 maxPublishTime
    )
        external
        payable
        returns (PythStructs.PriceFeed[] memory priceFeeds, uint64[] memory slots)
    {
        updateData[0];
    }
}
