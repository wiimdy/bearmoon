//SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

interface IKodiakIslandFactory {
    event IslandCreated(address indexed uniPool, address indexed manager, address indexed island, address implementation);
    event TreasurySet(address indexed treasury);
    event IslandFeeSet(uint16 fee);
    event UpdateIslandImplementation(address newImplementation);

    function deployVault(
        address tokenA,
        address tokenB,
        uint24 uniFee,
        address manager,
        address managerTreasury,
        uint16 managerFee,
        int24 lowerTick,
        int24 upperTick
    ) external returns (address island);

    function setIslandImplementation(address newImplementation) external;

    function islandImplementation() external view returns (address);

    function treasury() external view returns (address);

    function islandFee() external view returns (uint16);

}
