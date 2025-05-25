// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {FeeLib} from "src/libraries/FeeLib.sol";
import {IMetaBeraborrowCore} from "src/interfaces/core/IMetaBeraborrowCore.sol";
import {IDebtToken} from "src/interfaces/core/IDebtToken.sol";
import {IFeeHook} from "src/interfaces/utils/integrations/IFeeHook.sol";

/**
 * @title PermissionlessPSM
 * @author Beraborrow Team
 * @notice Multi-stablecoin Permissionless Peg Stability Module, dynamic entry/exit fees with mint caps
 * @dev Granted mint and burn permissions by NECT
 * @dev Inspired by IERC4626, but not strictly compliant
 */
contract PermissionlessPSM {
    using Math for uint;
    using SafeERC20 for IERC20;
    using FeeLib for uint;

    uint16 public constant DEFAULT_FEE = 30; // 0.3%
    uint16 constant BP = 1e4;

    IMetaBeraborrowCore public metaBeraborrowCore;
    IDebtToken public nect;
    IFeeHook public feeHook;
    address public feeReceiver;
    bool public paused;
    mapping(address stable => uint) public nectMinted;
    mapping(address stable => uint) public mintCap;

    /// @dev Scale factor to NECT
    mapping(address => uint64 wadOffset) public stables;

    error OnlyOwner(address caller);
    error AddressZero();
    error AmountZero();
    error Paused();
    error NotListedToken(address token);
    error AlreadyListed(address token);
    error PassedMintCap(uint mintCap, uint minted);
    error SurpassedFeePercentage(uint feePercentage, uint maxFeePercentage);

    event NectMinted(uint nectMinted, address stable);
    event NectBurned(uint nectBurned, address stable);
    event FeeHookSet(address feeHook);
    event PausedSet(bool paused);
    event MintCap(uint mintCap);
    event Deposit(address indexed caller, address indexed stable, uint stableAmount, uint mintedNect, uint fee);
    event Withdraw(address indexed caller, address indexed stable, uint stableAmount, uint burnedNect, uint fee);
    event FeeReceiverSet(address feeReceiver);

    modifier onlyOwner() {
        if (msg.sender != metaBeraborrowCore.owner()) revert OnlyOwner(msg.sender);
        _;
    }

    modifier notPaused() {
        if (paused) revert Paused();
        _;
    }

    constructor(address _metaBeraborrowCore, address _nect, address[] memory _stables, address _feeHook, address _feeReceiver) {
        if (_metaBeraborrowCore == address(0) || _nect == address(0) || _feeHook == address(0)) revert AddressZero();

        metaBeraborrowCore = IMetaBeraborrowCore(_metaBeraborrowCore);
        nect = IDebtToken(_nect);
        feeHook = IFeeHook(_feeHook);
        feeReceiver = _feeReceiver;

        for (uint i; i < _stables.length; i++) {
            if (_stables[i] == address(0)) revert AddressZero();

            _whitelistStable(_stables[i]);
        }
    }

    function deposit(address stable, uint stableAmount, address receiver, uint16 maxFeePercentage) public notPaused returns (uint mintedNect) {
        if (stableAmount == 0) revert AmountZero();

        uint nectFee;
        (mintedNect, nectFee) = previewDeposit(stable, stableAmount, maxFeePercentage);

        uint cap = mintCap[stable];
        uint _nectMinted = nectMinted[stable] + mintedNect + nectFee;
        if (_nectMinted > cap) revert PassedMintCap(cap, _nectMinted);

        nectMinted[stable] = _nectMinted;

        nect.mint(receiver, mintedNect);
        nect.mint(feeReceiver, nectFee);

        IERC20(stable).safeTransferFrom(msg.sender, address(this), stableAmount);

        emit Deposit(msg.sender, stable, stableAmount, mintedNect, nectFee);
    }

    function mint(address stable, uint nectAmount, address receiver, uint16 maxFeePercentage) public notPaused returns (uint stableAmount) {
        uint nectFee;
        (stableAmount, nectFee) = previewMint(stable, nectAmount, maxFeePercentage);

        if (stableAmount == 0) revert AmountZero();

        uint cap = mintCap[stable];
        uint _nectMinted = nectMinted[stable] + nectAmount + nectFee;
        if (_nectMinted > cap) revert PassedMintCap(cap, _nectMinted);

        nectMinted[stable] = _nectMinted;

        nect.mint(receiver, nectAmount);
        nect.mint(feeReceiver, nectFee);

        IERC20(stable).safeTransferFrom(msg.sender, address(this), stableAmount);

        emit Deposit(msg.sender, stable, stableAmount, nectAmount, nectFee);
    }

    function withdraw(address stable, uint stableAmount, address receiver, uint16 maxFeePercentage)
        public
        notPaused
        returns (uint burnedNect)
    {
        uint stableFee;
        (burnedNect, stableFee) = previewWithdraw(stable, stableAmount, maxFeePercentage);

        if (burnedNect == 0) revert AmountZero();

        nect.burn(msg.sender, burnedNect);

        nectMinted[stable] -= burnedNect;

        IERC20(stable).safeTransfer(receiver, stableAmount);
        IERC20(stable).safeTransfer(feeReceiver, stableFee);

        emit Withdraw(msg.sender, stable, stableAmount, burnedNect, stableFee);
    }

    function redeem(address stable, uint nectAmount, address receiver, uint16 maxFeePercentage)
        public
        notPaused
        returns (uint stableAmount)
    {
        if (nectAmount == 0) revert AmountZero();

        uint stableFee;
        (stableAmount, stableFee) = previewRedeem(stable, nectAmount, maxFeePercentage);

        nect.burn(msg.sender, nectAmount);

        nectMinted[stable] -= nectAmount;

        IERC20(stable).safeTransfer(receiver, stableAmount);
        IERC20(stable).safeTransfer(feeReceiver, stableFee);

        emit Withdraw(msg.sender, stable, stableAmount, nectAmount, stableFee);
    }

    /**
     * @dev Takes NECT as fee, returns the amount of NECT that would be minted
     */
    function previewDeposit(address stable, uint stableAmount, uint16 maxFeePercentage) public view returns (uint mintedNect, uint nectFee) {
        uint64 wadOffset = stables[stable];

        if (wadOffset == 0) revert NotListedToken(stable);

        uint grossMintedNect = stableAmount * wadOffset;

        uint fee = feeHook.calcFee(msg.sender, stable, grossMintedNect, IFeeHook.Action.DEPOSIT);
        fee = fee == 0 ? DEFAULT_FEE : fee;
        if (fee > maxFeePercentage) revert SurpassedFeePercentage(fee, maxFeePercentage);

        nectFee = grossMintedNect.feeOnRaw(fee);
        mintedNect = grossMintedNect - nectFee;
    }

    /**
     * @dev Takes NECT as fee, returns the amount of stable needed to mint NECT
     */
    function previewMint(address stable, uint nectAmount, uint16 maxFeePercentage) public view returns (uint stableAmount, uint nectFee) {
        uint64 wadOffset = stables[stable];

        if (wadOffset == 0) revert NotListedToken(stable);

        uint fee = feeHook.calcFee(msg.sender, stable, nectAmount, IFeeHook.Action.MINT);
        fee = fee == 0 ? DEFAULT_FEE : fee;
        if (fee > maxFeePercentage) revert SurpassedFeePercentage(fee, maxFeePercentage);

        nectFee = nectAmount.mulDiv(fee, BP - fee, Math.Rounding.Up);        
        stableAmount = (nectAmount + nectFee).ceilDiv(wadOffset);
    }

    /**
     * @dev Takes stable as fee, returns the amount of NECT that would be burned
     */
    function previewWithdraw(address stable, uint stableAmount, uint16 maxFeePercentage) public view returns (uint burnedNect, uint stableFee) {
        uint64 wadOffset = stables[stable];

        if (wadOffset == 0) revert NotListedToken(stable);

        uint grossBurnedNect = stableAmount * wadOffset;

        uint fee = feeHook.calcFee(msg.sender, stable, grossBurnedNect, IFeeHook.Action.WITHDRAW);
        fee = fee == 0 ? DEFAULT_FEE : fee;
        if (fee > maxFeePercentage) revert SurpassedFeePercentage(fee, maxFeePercentage);

        stableFee = stableAmount.mulDiv(fee, BP - fee, Math.Rounding.Up);
        burnedNect = grossBurnedNect + stableFee * wadOffset;
    }

    /**
     * @dev Takes stable as fee, returns the amount of stable given for redeeming NECT
     */
    function previewRedeem(address stable, uint nectAmount, uint16 maxFeePercentage) public view returns (uint stableAmount, uint stableFee) {
        uint64 wadOffset = stables[stable];

        if (wadOffset == 0) revert NotListedToken(stable);

        uint grossStable = nectAmount / wadOffset;

        uint fee = feeHook.calcFee(msg.sender, stable, nectAmount, IFeeHook.Action.REDEEM);
        fee = fee == 0 ? DEFAULT_FEE : fee;
        if (fee > maxFeePercentage) revert SurpassedFeePercentage(fee, maxFeePercentage);

        stableFee = grossStable.mulDiv(fee, BP, Math.Rounding.Up);
        stableAmount = grossStable - stableFee;
    }

    function whitelistStable(address _stable) external onlyOwner {
        if (stables[_stable] != 0) revert AlreadyListed(_stable);

        _whitelistStable(_stable);
    }

    function blacklistStable(address _stable) external onlyOwner {
        delete stables[_stable];
    }

    function setFeeHook(address _feeHook) external onlyOwner {
        if (_feeHook == address(0)) revert AddressZero();
        
        feeHook = IFeeHook(_feeHook);

        emit FeeHookSet(_feeHook);
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;

        emit PausedSet(_paused);
    }

    function setMintCap(address stable, uint _mintCap) external onlyOwner {
        mintCap[stable] = _mintCap;

        emit MintCap(_mintCap);
    }

    function setFeeReceiver(address _feeReceiver) external onlyOwner {
        feeReceiver = _feeReceiver;

        emit FeeReceiverSet(_feeReceiver);
    }

    function _whitelistStable(address _stable) private {
        IERC20Metadata stable = IERC20Metadata(_stable);

        uint64 wadOffset = uint64(10 ** (nect.decimals() - stable.decimals()));

        stables[_stable] = wadOffset;
    }
}