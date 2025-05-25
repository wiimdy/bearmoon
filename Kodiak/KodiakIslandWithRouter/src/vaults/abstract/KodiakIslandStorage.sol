// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.19;

import {OwnableUninitialized} from "./OwnableUninitialized.sol";
import {ERC20} from "lib/solady/src/tokens/ERC20.sol";
import {IUniswapV3Pool} from "../interfaces/IUniswapV3Pool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "lib/solady/src/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import {IKodiakIslandFactory} from "../interfaces/IKodiakIslandFactory.sol";

abstract contract KodiakIslandStorage is ERC20, ReentrancyGuard, OwnableUninitialized, Pausable {
    string public constant version = "1.0.0";
    uint256 internal constant Q96 = 1 << 96;
    uint256 internal constant INITIAL_MINT = 1e3;

    string private _islandName;
    string private _islandSymbol;
    bool public restrictedMint;

    int24 public lowerTick;
    int24 public upperTick;

    uint16 public compounderSlippageBPS;
    uint32 public compounderSlippageInterval;

    uint16 public managerFeeBPS;
    address public managerTreasury;
    IKodiakIslandFactory public islandFactory;

    uint256 public managerBalance0;
    uint256 public managerBalance1;

    IUniswapV3Pool public pool;
    IERC20 public token0;
    IERC20 public token1;

    mapping(address => bool) public pauser;

    event UpdateManagerParams(uint16 managerFeeBPS, address managerTreasury, uint16 compounderSlippageBPS, uint32 compounderSlippageInterval);
    event PauserSet(address indexed pauser, bool status);
    event RestrictedMintSet(bool status);

    modifier onlyPauserOrAbove() {
        require(pauser[msg.sender] || msg.sender == _manager, "Ownable: caller is not the pauser");
        _;
    }

    function name() public view override returns (string memory) {
        return _islandName;
    }

    function symbol() public view override returns (string memory) {
        return _islandSymbol;
    }

    /// @notice initialize storage variables on a new pool, only called once
    /// @param _name name of Vault (immutable)
    /// @param _symbol symbol of Vault (immutable)
    /// @param _pool address of Uniswap V3 pool (immutable)
    /// @param _managerFeeBPS proportion of fees earned that go to manager treasury
    /// @param _lowerTick initial lowerTick (only changeable with executiveRebalance)
    /// @param _lowerTick initial upperTick (only changeable with executiveRebalance)
    /// @param _manager_ address of manager (ownership can be transferred)
    function initialize(
        string memory _name,
        string memory _symbol,
        address _pool,
        uint16 _managerFeeBPS,
        int24 _lowerTick,
        int24 _upperTick,
        address _manager_,
        address _managerTreasury
    ) external {
        require(address(pool) == address(0), "KodiakIslandStorage: already initialized");
        require(_managerFeeBPS <= 10000, "managerFeeBps over max");
        // these variables are immutable after initialization
        islandFactory = IKodiakIslandFactory(msg.sender);
        pool = IUniswapV3Pool(_pool);
        token0 = IERC20(pool.token0());
        token1 = IERC20(pool.token1());

        // these variables can be updated by the manager,
        // If manager is address(0), these are immutable
        _manager = _manager_;
        managerTreasury = _managerTreasury;
        managerFeeBPS = _managerFeeBPS;
        compounderSlippageInterval = 5 minutes; // default: last five minutes;
        compounderSlippageBPS = 500; // default: 5% slippage
        lowerTick = _lowerTick;
        upperTick = _upperTick;
        _islandName = _name;
        _islandSymbol = _symbol;

        syncToFactory();
    }

    /// @notice change configurable gelato parameters, only manager can call
    /// @param newManagerFeeBPS Basis Points of fees earned credited to manager (negative to ignore)
    /// @param newManagerTreasury address that collects manager fees (Zero address to ignore)
    /// @param newSlippageBPS frontrun protection parameter (negative to ignore)
    /// @param newSlippageInterval frontrun protection parameter (negative to ignore)
    function updateManagerParams(int16 newManagerFeeBPS, address newManagerTreasury, int16 newSlippageBPS, int32 newSlippageInterval) external onlyManager {
        require(newSlippageBPS <= 10000, "BPS");
        require(newManagerFeeBPS <= 10000, "managerFeeBps over max");
        if (newManagerFeeBPS >= 0) managerFeeBPS = uint16(newManagerFeeBPS);
        if (address(0) != newManagerTreasury) managerTreasury = newManagerTreasury;
        if (newSlippageBPS >= 0) compounderSlippageBPS = uint16(newSlippageBPS);
        if (newSlippageInterval >= 0) compounderSlippageInterval = uint32(newSlippageInterval);
        emit UpdateManagerParams(managerFeeBPS, managerTreasury, compounderSlippageBPS, compounderSlippageInterval);
    }

    /// @notice returns whether the island has a manager
    function isManaged() public view returns (bool) {
        return _manager != address(0);
    }

    /// @notice allows manager to restrict minting to only the manager
    /// @param _status true to allow only manager, false to allow everyone
    function setRestrictedMint(bool _status) external onlyManager {
        restrictedMint = _status;
        emit RestrictedMintSet(_status);
    }

    /// @notice Triggers paused state.
    function pause() external onlyPauserOrAbove {
        require(address(_manager) != address(0), "Pausable: cannot pause without a valid manager");
        _pause();
    }

    /// @notice Returns to normal state.
    function unpause() external onlyManager {
        _unpause();
    }

    /// @notice allows manager to add / remove pausers, can do while paused
    /// @param _pauser address that can pause the vault (but not unpause)
    /// @param _status true to add, false to remove
    function setPauser(address _pauser, bool _status) external onlyManager {
        require(_pauser != address(0), "Zero address");
        pauser[_pauser] = _status;
        emit PauserSet(_pauser, _status);
    }

    /// @notice Can only renounce when not paused (otherwise can't unpause)
    /// @dev Leaves the contract without manager.
    function renounceOwnership() external whenNotPaused onlyManager {
        managerTreasury = islandFactory.treasury();
        managerFeeBPS = islandFactory.islandFee();
        managerBalance0 = 0;
        managerBalance1 = 0;
        _manager = address(0);
        emit OwnershipTransferred(_manager, address(0));
    }

    /// @notice sync to factory settings for non managed islands
    function syncToFactory() public {
        if(!isManaged()) {
            managerTreasury = islandFactory.treasury();
            managerFeeBPS = islandFactory.islandFee();
            emit UpdateManagerParams(managerFeeBPS, managerTreasury, compounderSlippageBPS, compounderSlippageInterval);
        }
    }

    function getPositionID() external view returns (bytes32 positionID) {
        return _getPositionID();
    }

    function _getPositionID() internal view returns (bytes32 positionID) {
        return keccak256(abi.encodePacked(address(this), lowerTick, upperTick));
    }
}
