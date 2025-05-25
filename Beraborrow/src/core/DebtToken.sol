// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { IERC20, ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol"; 
import { IERC3156FlashBorrower } from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "../interfaces/core/IBeraborrowCore.sol";

/**
    @title Beraborrow Debt Token "Nectar"
    @notice CDP minted against collateral deposits within `DenManager`.
            This contract has a 1:n relationship with multiple deployments of `DenManager`,
            each of which hold one collateral type which may be used to mint this token.
 */
contract DebtToken is ERC20 {
    string public constant version = "1";

    // --- ERC 3156 Data ---
    bytes32 private constant _RETURN_VALUE = keccak256("ERC3156FlashBorrower.onFlashLoan");

    // --- Data for EIP2612 ---

    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant permitTypeHash = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant _TYPE_HASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

    // Cache the domain separator as an immutable value, but also store the chain id that it corresponds to, in order to
    // invalidate the cached domain separator if the chain id changes.
    bytes32 private immutable _CACHED_DOMAIN_SEPARATOR;
    uint256 private immutable _CACHED_CHAIN_ID;

    bytes32 private immutable _HASHED_NAME;
    bytes32 private immutable _HASHED_VERSION;

    mapping(address => uint256) private _nonces;

    IMetaBeraborrowCore private immutable _metaBeraborrowCore;
    address public gasPool;

    // --- Addresses ---
    /// @dev Whitelist of addresses that are allowed to mint and burn NECT.
    /// @dev Will make NECT multi-protocol in the future.
    mapping(address => bool) public liquidStabilityPools;
    mapping(address => bool) public borrowerOperations;
    mapping(address => bool) public factories;
    mapping(address => bool) public peripheries;
    mapping(address => bool) public denManagers;
    mapping(address => bool) public PSMBonds;

    // Amount of debt to be locked in gas pool on opening dens
    uint256 public DEBT_GAS_COMPENSATION;
    bool definitiveGasCompensation;

    event LiquidStabilityPoolWhitelisted(address indexed liquidStabilityPool, bool active);
    event BorrowerOperationsWhitelisted(address indexed borrowerOperations, bool active);
    event FactoryWhitelisted(address indexed factory, bool active);
    event PeripheryWhitelisted(address indexed periphery, bool active);
    event GasPoolSet(address indexed gasPool);
    event PSMBondSet(address indexed PSMBond);

    constructor(
        string memory _name,
        string memory _symbol,
        address _liquidStabilityPool,
        address _borrowerOperations,
        IMetaBeraborrowCore metaBeraborrowCore_,
        address _factory,
        address _gasPool,
        address _PSMBond,
        uint256 _gasCompensation
    ) ERC20(_name, _symbol) {
        if (_liquidStabilityPool == address(0) || _borrowerOperations == address(0) || _factory == address(0) || _gasPool == address(0)) {
            revert("Debt: 0 address");
        }

        liquidStabilityPools[_liquidStabilityPool] = true;
        borrowerOperations[_borrowerOperations] = true;
        factories[_factory] = true;
        PSMBonds[_PSMBond] = true;

        _metaBeraborrowCore = metaBeraborrowCore_;
        gasPool = _gasPool;

        DEBT_GAS_COMPENSATION = _gasCompensation;

        bytes32 hashedName = keccak256(bytes(_name));
        bytes32 hashedVersion = keccak256(bytes(version));

        _HASHED_NAME = hashedName;
        _HASHED_VERSION = hashedVersion;
        _CACHED_CHAIN_ID = block.chainid;
        _CACHED_DOMAIN_SEPARATOR = _buildDomainSeparator(_TYPE_HASH, hashedName, hashedVersion);
    }

    function enableDenManager(address _denManager) external {
        require(factories[msg.sender], "!Factory");
        denManagers[_denManager] = true;
    }

    // --- Functions for intra-Beraborrow calls ---

    function mintWithGasCompensation(address _account, uint256 _amount) external returns (bool) {
        require(borrowerOperations[msg.sender]);
        _mint(_account, _amount);
        _mint(gasPool, DEBT_GAS_COMPENSATION);

        return true;
    }

    function burnWithGasCompensation(address _account, uint256 _amount) external returns (bool) {
        require(borrowerOperations[msg.sender]);
        _burn(_account, _amount);
        _burn(gasPool, DEBT_GAS_COMPENSATION);

        return true;
    }

    function mint(address _account, uint256 _amount) external {
        require(borrowerOperations[msg.sender] || denManagers[msg.sender] || PSMBonds[msg.sender], "Debt: Caller not BO/DM");
        _mint(_account, _amount);
    }

    function burn(address _account, uint256 _amount) external {
        require(denManagers[msg.sender] || PSMBonds[msg.sender], "Debt: Caller not DenManager");
        _burn(_account, _amount);
    }
    
    function sendToPeriphery(address _sender, uint256 _amount) external {
        require(peripheries[msg.sender], "Debt: Caller not periphery");
        _transfer(_sender, msg.sender, _amount);
    }

    function sendToSP(address _sender, uint256 _amount) external {
        require(liquidStabilityPools[msg.sender], "Debt: Caller not StabilityPool");
        _transfer(_sender, msg.sender, _amount);
    }

    function returnFromPool(address _poolAddress, address _receiver, uint256 _amount) external {
        require(liquidStabilityPools[msg.sender] || denManagers[msg.sender], "Debt: Caller not DM/SP");
        _transfer(_poolAddress, _receiver, _amount);
    }

    // --- External functions ---

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _requireValidRecipient(recipient);
        return super.transfer(recipient, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _requireValidRecipient(recipient);
        return super.transferFrom(sender, recipient, amount);
    }

    // --- ERC 3156 Functions ---

    /**
     * @dev Returns the maximum amount of tokens available for loan.
     * @param token The address of the token that is requested.
     * @return The amount of token that can be loaned.
     */
    function maxFlashLoan(address token) public view returns (uint256) {
        return token == address(this) ? type(uint256).max - totalSupply() : 0;
    }

    /**
     * @dev Returns the fee applied when doing flash loans. This function calls
     * the {_flashFee} function which returns the fee applied when doing flash
     * loans.
     * @param token The token to be flash loaned.
     * @param amount The amount of tokens to be loaned.
     * @return The fees applied to the corresponding flash loan.
     */
    function flashFee(address token, uint256 amount) public view returns (uint256) {
        require(token == address(this), "ERC20FlashMint: wrong token");
        return _flashFee(amount);
    }

    /**
     * @dev Returns the fee applied when doing flash loans. By default this
     * implementation has 0 fees. This function can be overloaded to make
     * the flash loan mechanism deflationary.
     * @param amount The amount of tokens to be loaned.
     * @return The fees applied to the corresponding flash loan.
     */
    function _flashFee(uint256 amount) internal view returns (uint256) {
        uint effectiveFee = _metaBeraborrowCore.getPeripheryFlashLoanFee(msg.sender);

        return (amount * effectiveFee) / 1e4;
    }

    /**
     * @dev Performs a flash loan. New tokens are minted and sent to the
     * `receiver`, who is required to implement the {IERC3156FlashBorrower}
     * interface. By the end of the flash loan, the receiver is expected to own
     * amount + fee tokens and have them approved back to the token contract itself so
     * they can be burned.
     * @param receiver The receiver of the flash loan. Should implement the
     * {IERC3156FlashBorrower-onFlashLoan} interface.
     * @param token The token to be flash loaned. Only `address(this)` is
     * supported.
     * @param amount The amount of tokens to be loaned.
     * @param data An arbitrary datafield that is passed to the receiver.
     * @return `true` if the flash loan was successful.
     */
    // This function can reenter, but it doesn't pose a risk because it always preserves the property that the amount
    // minted at the beginning is always recovered and burned at the end, or else the entire function will revert.
    // slither-disable-next-line reentrancy-no-eth
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external returns (bool) {
        uint256 fee = flashFee(token, amount);
        require(amount <= maxFlashLoan(token), "ERC20FlashMint: amount exceeds maxFlashLoan");

        _mint(address(receiver), amount);
        require(
            receiver.onFlashLoan(msg.sender, token, amount, fee, data) == _RETURN_VALUE,
            "ERC20FlashMint: invalid return value"
        );
        _spendAllowance(address(receiver), address(this), amount + fee);
        _burn(address(receiver), amount);
        _transfer(address(receiver), _metaBeraborrowCore.feeReceiver(), fee);
        return true;
    }

    modifier onlyOwner() {
        require(_metaBeraborrowCore.owner() == msg.sender, "Caller not BeraborowCore::owner()");
        _;
    }

    // OnlyOwner setters

    /// @dev Allows NECT to be protocol transferable
    function whitelistLiquidStabilityPoolAddress(address _liquidStabilityPool, bool active) external onlyOwner {
        liquidStabilityPools[_liquidStabilityPool] = active;
        emit LiquidStabilityPoolWhitelisted(_liquidStabilityPool, active);
    }

    function whitelistBorrowerOperationsAddress(address _borrowerOperations, bool active) external onlyOwner {
        borrowerOperations[_borrowerOperations] = active;
        emit BorrowerOperationsWhitelisted(_borrowerOperations, active);
    }

    function whitelistFactoryAddress(address _factory, bool active) external onlyOwner {
        factories[_factory] = active;
        emit FactoryWhitelisted(_factory, active);
    }

    function whitelistPeripheryAddress(address _periphery, bool active) external onlyOwner {
        peripheries[_periphery] = active;
        emit PeripheryWhitelisted(_periphery, active);
    }

    function setGasPool(address _gasPool) external onlyOwner {
        gasPool = _gasPool;
        emit GasPoolSet(_gasPool);
    }

    function setDebtGasCompensation(uint256 _gasCompensation, bool _isFinalValue) external onlyOwner {
        require(!definitiveGasCompensation);

        DEBT_GAS_COMPENSATION = _gasCompensation;
        definitiveGasCompensation = _isFinalValue;
    }

    function whitelistPSMBond(address _PSMBond, bool active) external onlyOwner {
        PSMBonds[_PSMBond] = active;
        emit PSMBondSet(_PSMBond);
    }

    // --- EIP 2612 Functionality ---

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        if (block.chainid == _CACHED_CHAIN_ID) {
            return _CACHED_DOMAIN_SEPARATOR;
        } else {
            return _buildDomainSeparator(_TYPE_HASH, _HASHED_NAME, _HASHED_VERSION);
        }
    }

    function permit(
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(deadline >= block.timestamp, "Debt: expired deadline");
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(abi.encode(permitTypeHash, owner, spender, amount, _nonces[owner]++, deadline))
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress == owner, "Debt: invalid signature");
        _approve(owner, spender, amount);
    }

    function nonces(address owner) external view returns (uint256) {
        // FOR EIP 2612
        return _nonces[owner];
    }

    // --- Internal operations ---

    function _buildDomainSeparator(bytes32 typeHash, bytes32 name_, bytes32 version_) private view returns (bytes32) {
        return keccak256(abi.encode(typeHash, name_, version_, block.chainid, address(this)));
    }

    // --- 'require' functions ---

    function _requireValidRecipient(address _recipient) internal view {
        require(
            _recipient != address(0) && _recipient != address(this),
            "Debt: Cannot transfer tokens directly to the Debt token contract or the zero address"
        );
        require(
            !denManagers[_recipient] && !borrowerOperations[_recipient],
            "Debt: Cannot transfer tokens directly to the DenManager or BorrowerOps"
        );
    }
}
