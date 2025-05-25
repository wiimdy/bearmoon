// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 
import { IERC3156FlashBorrower } from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "./IBeraborrowCore.sol";

interface IDebtToken is IERC20 {
    // --- Events ---
    event FlashLoanFeeUpdated(uint256 newFee);

    // --- Public constants ---
    function version() external view returns (string memory);
    function permitTypeHash() external view returns (bytes32);

    // --- Public immutables ---
    function gasPool() external view returns (address);
    function DEBT_GAS_COMPENSATION() external view returns (uint256);
    function PSMBond() external view returns (address);

    // --- Public mappings ---
    function liquidStabilityPools(address) external view returns (bool);
    function borrowerOperations(address) external view returns (bool);
    function factories(address) external view returns (bool);
    function peripheries(address) external view returns (bool);
    function denManagers(address) external view returns (bool);

    // --- External functions ---

    function enableDenManager(address _denManager) external;
    function mintWithGasCompensation(address _account, uint256 _amount) external returns (bool);
    function burnWithGasCompensation(address _account, uint256 _amount) external returns (bool);
    function mint(address _account, uint256 _amount) external;
    function burn(address _account, uint256 _amount) external;
    function decimals() external view returns (uint8);
    function sendToPeriphery(address _sender, uint256 _amount) external;
    function sendToSP(address _sender, uint256 _amount) external;
    function returnFromPool(address _poolAddress, address _receiver, uint256 _amount) external;
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function maxFlashLoan(address token) external view returns (uint256);
    function flashFee(address token, uint256 amount) external view returns (uint256);
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);
    function whitelistLiquidStabilityPoolAddress(address _liquidStabilityPool, bool active) external;
    function whitelistBorrowerOperationsAddress(address _borrowerOperations, bool active) external;
    function whitelistFactoryAddress(address _factory, bool active) external;
    function whitelistPeripheryAddress(address _periphery, bool active) external;
    function setDebtGasCompensation(uint256 _gasCompensation, bool _isFinalValue) external;
    function setFlashLoanFee(uint256 _fee) external;
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function permit(
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
    function nonces(address owner) external view returns (uint256);
}
