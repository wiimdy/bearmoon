// SPDX-License-Identifier: MIT
//
// =========================== Kodiak Vaults =============================
// =======================================================================
// Modified from Arrakis (https://github.com/ArrakisFinance/vault-v1-core)
// Built for the Beras
// =======================================================================

pragma solidity =0.8.19;

import {LibClone} from "lib/solady/src/utils/LibClone.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IUniswapV3Factory} from "./interfaces/IUniswapV3Factory.sol";
import {IUniswapV3TickSpacing} from "./interfaces/IUniswapV3TickSpacing.sol";
import {IKodiakIslandFactory} from "./interfaces/IKodiakIslandFactory.sol";
import {IKodiakIslandStorage} from "./interfaces/IKodiakIslandStorage.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract KodiakIslandFactory is IKodiakIslandFactory, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    address public immutable factory;
    address public override islandImplementation;
    address public override treasury;
    uint16 public override islandFee = 500;

    EnumerableSet.AddressSet internal _deployers;
    mapping(address => EnumerableSet.AddressSet) internal _islands;

    constructor(address _uniswapV3Factory, address _treasury) {
        factory = _uniswapV3Factory;
        treasury = _treasury;
    }

    /// @notice Set the address of the island implementation
    /// @param _implementation The deployed island contract to clone
    function setIslandImplementation(address _implementation) external onlyOwner {
        require(_implementation != address(0), "invalid zero address implementation");
        islandImplementation = _implementation;
        emit UpdateIslandImplementation(_implementation);
    }

    /// @notice Set the fee recipient address
    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "IslandFactory: Invalid treasury");
        treasury = _treasury;
        emit TreasurySet(_treasury);
    }

    /// @notice Set the fee for permissionless islands
    function setIslandFee(uint16 _islandFee) external onlyOwner {
        require(_islandFee <= 2000, "IslandFactory: Invalid fee");
        islandFee = _islandFee;
        emit IslandFeeSet(_islandFee);
    }

    /// @notice deployVault creates a new instance of a Vault on a specified
    /// UniswapV3Pool. The msg.sender is the initial manager of the pool and will
    /// forever be associated with the Vault as it's `deployer`
    /// @param tokenA one of the tokens in the uniswap pair
    /// @param tokenB the other token in the uniswap pair
    /// @param uniFee fee tier of the uniswap pair
    /// @param manager address of the managing account
    /// @param managerFee proportion of earned fees that go to pool manager in Basis Points
    /// @param lowerTick initial lower bound of the Uniswap V3 position
    /// @param upperTick initial upper bound of the Uniswap V3 position
    /// @return island the address of the newly created Vault
    function deployVault(
        address tokenA,
        address tokenB,
        uint24 uniFee,
        address manager,
        address managerTreasury,
        uint16 managerFee,
        int24 lowerTick,
        int24 upperTick
    ) external override returns (address island) {
        if (manager == address(0)) {
            require(managerTreasury == address(0), "IslandFactory: must be 0");
            require(managerFee == 0, "IslandFactory: must be 0");
        }
        return _deployVault(tokenA, tokenB, uniFee, manager, managerTreasury, managerFee, lowerTick, upperTick);
    }

    function _deployVault(
        address tokenA,
        address tokenB,
        uint24 uniFee,
        address manager,
        address managerTreasury,
        uint16 managerFee,
        int24 lowerTick,
        int24 upperTick
    ) internal returns (address island) {
        address uniPool;
        string memory symbolStr;
        (island, uniPool, symbolStr) = _preDeploy(tokenA, tokenB, uniFee, lowerTick, upperTick, manager);

        IKodiakIslandStorage(island).initialize(
            string(abi.encodePacked("Kodiak Island", symbolStr, _feeStr(uniFee))),
            string(abi.encodePacked("KODI", symbolStr)),
            uniPool,
            managerFee,
            lowerTick,
            upperTick,
            manager,
            managerTreasury
        );
        _deployers.add(manager);
        _islands[manager].add(island);
    }

    function _preDeploy(
        address tokenA,
        address tokenB,
        uint24 uniFee,
        int24 lowerTick,
        int24 upperTick,
        address manager
    ) internal returns (address island, address uniPool, string memory symbolStr) {
        (address token0, address token1) = _getTokenOrder(tokenA, tokenB);

        uniPool = IUniswapV3Factory(factory).getPool(token0, token1, uniFee);
        require(uniPool != address(0), "uniswap pool does not exist");
        require(_validateTickSpacing(uniPool, lowerTick, upperTick), "tickSpacing mismatch");

        try this.getSymbols(token0, token1) returns (string memory res) {
            symbolStr = res;
        } catch {
            symbolStr = "";
        }

        address _implementation = islandImplementation;
        island = address(LibClone.clone(_implementation));
        emit IslandCreated(uniPool, manager, island, _implementation);
    }

    function _validateTickSpacing(address uniPool, int24 lowerTick, int24 upperTick) internal view returns (bool) {
        int24 spacing = IUniswapV3TickSpacing(uniPool).tickSpacing();
        return lowerTick < upperTick && lowerTick % spacing == 0 && upperTick % spacing == 0;
    }

    function getSymbols(address token0, address token1) external view returns (string memory res) {
        string memory symbol0 = IERC20Metadata(token0).symbol();
        string memory symbol1 = IERC20Metadata(token1).symbol();
        return string(abi.encodePacked(" ", symbol0, "-", symbol1));
    }

    /// @notice getDeployers fetches all addresses that have deployed a Vault
    /// @return deployers the list of deployer addresses
    function getDeployers() public view returns (address[] memory) {
        uint256 length = numDeployers();
        address[] memory deployers = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            deployers[i] = _getDeployer(i);
        }
        return deployers;
    }

    /// @notice getIslands fetches all the Vault addresses deployed by `deployer`
    /// @param deployer address that has potentially deployed Harvesters (can return empty array)
    /// @return islands the list of Vault addresses deployed by `deployer`
    function getIslands(address deployer) public view returns (address[] memory islands) {
        uint256 length = numIslands(deployer);
        islands = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            islands[i] = _getIsland(deployer, i);
        }
    }

    /// @notice numIslands counts the total number of islands deployed through this factory
    /// @return result total number of islands deployed
    function numIslands() public view returns (uint256 result) {
        address[] memory deployers = getDeployers();
        for (uint256 i = 0; i < deployers.length; i++) {
            result += numIslands(deployers[i]);
        }
    }

    /// @notice numDeployers counts the total number of Vault deployer addresses
    /// @return total number of Vault deployer addresses
    function numDeployers() public view returns (uint256) {
        return _deployers.length();
    }

    /// @notice numIslands counts the total number of Harvesters deployed by `deployer`
    /// @param deployer deployer address
    /// @return total number of Harvesters deployed by `deployer`
    function numIslands(address deployer) public view returns (uint256) {
        return _islands[deployer].length();
    }

    function _getDeployer(uint256 _index) internal view returns (address) {
        return _deployers.at(_index);
    }

    function _getIsland(address deployer, uint256 _index) internal view returns (address) {
        return _islands[deployer].at(_index);
    }

    function _getTokenOrder(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, "same token");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "no address zero");
    }

    function _feeStr(uint24 uniFee) internal pure returns (string memory) {
        if(uniFee == 100) {
            return "-0.01%";
        } else if(uniFee == 500) {
            return "-0.05%";
        } else if(uniFee == 3000) {
            return "-0.3%";
        } else if(uniFee == 10000) {
            return "-1%";
        } else if(uniFee == 20000) {
            return "-2%";
        } else {
            return "";
        }
    }
}
