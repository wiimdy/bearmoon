// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "../interfaces/core/IBeraborrowCore.sol";
import "../interfaces/core/ILiquidStabilityPool.sol";
import "../dependencies/BeraborrowOwnable.sol";
import {IERC20, Math, SafeERC20} from "@openzeppelin-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol";

contract ValidatorPool is BeraborrowOwnable {
    using SafeERC20 for IERC20;

    address[] public validators;
    mapping(address => uint) public shares; // Validators' shares, 100 is 1%, 1000 is 10%
    uint public constant BASIS_POINT = 10000;

    ILiquidStabilityPool public immutable _liquidStabilityPool;

    enum Operation { ADD, REMOVE, UPDATE }
    
    struct ValidatorOperation {
        Operation op;
        address validator;
        uint share;
    }

    event ValidatorAdded(address indexed validator, uint share);
    event ValidatorRemoved(address indexed validator);
    event ShareDistributed();

    constructor(
        address metaBeraborrowCore_,
        ILiquidStabilityPool liquidStabilityPool_
    ) BeraborrowOwnable(metaBeraborrowCore_) {
        _liquidStabilityPool = liquidStabilityPool_;
    }

    function bulkValidatorOperations(ValidatorOperation[] calldata operations) external onlyOwner {
        for (uint i; i < operations.length; i++) {
            ValidatorOperation memory op = operations[i];
            
            if (op.op == Operation.ADD) {
                _addValidator(op.validator, op.share);
            } 
            else if (op.op == Operation.REMOVE) {
                require(_removeValidator(op.validator), "no matching validator");
            }
            else if (op.op == Operation.UPDATE) {
                _setShare(op.validator, op.share);
            }
        }

        // Validate final state
        _validateTotalShares();
    }

    function distribute() external {
        address[] memory collateralTokens = _liquidStabilityPool
            .getCollateralTokens();

        uint validatorCount = validators.length;
        address[] memory memValidators = new address[](validatorCount);
        uint[] memory memShares = new uint[](validatorCount);

        // For gas optimization, pre-load validators and their shares into memory
        for (uint i; i < validatorCount; i++) {
            memValidators[i] = validators[i];
            memShares[i] = shares[memValidators[i]];
        }

        uint[][] memory collateralTokenToValidatorAmount = new uint[][](collateralTokens.length);
        for (uint i; i < collateralTokens.length; i++) {
            collateralTokenToValidatorAmount[i] = new uint[](validatorCount);
    
            uint tokenBalance = IERC20(collateralTokens[i]).balanceOf(address(this));
            if (tokenBalance != 0) {
                for (uint j; j < validatorCount; j++) {
                    uint amount = (tokenBalance * memShares[j]) / BASIS_POINT;
                    if (amount != 0) {
                        collateralTokenToValidatorAmount[i][j] = amount;
                    }
                }
            }
        }

        for (uint i; i < collateralTokens.length; i++) {
            for (uint j; j < validatorCount; j++) {
                if (collateralTokenToValidatorAmount[i][j] != 0) {
                    IERC20(collateralTokens[i]).safeTransfer(memValidators[j], collateralTokenToValidatorAmount[i][j]);
                }
            }
        }

        emit ShareDistributed();
    }

    function recoverLockedSunsettedAsset(address sunsettedCollateral, address receiver) external onlyOwner {
        address[] memory collateralTokens = _liquidStabilityPool
            .getCollateralTokens();

        for (uint i; i < collateralTokens.length; i++) {
            if (collateralTokens[i] == sunsettedCollateral) {
                revert("Asset is not sunsetted");
            }
        }

        uint balanceOfToken = IERC20(sunsettedCollateral).balanceOf(address(this));
        IERC20(sunsettedCollateral).safeTransfer(receiver, balanceOfToken);        
    }

        function _addValidator(address _validator, uint _share) internal {
        require(shares[_validator] == 0, "already exist");
        require(_share > 0, "share shouldn't be zero");

        validators.push(_validator);
        shares[_validator] = _share;

        emit ValidatorAdded(_validator, _share);
    }

    function _removeValidator(address _validator) internal returns (bool) {
        uint len = validators.length;
        uint i;

        for (; i < len; i++) {
            if (validators[i] == _validator) {
                validators[i] = validators[len - 1];
                validators.pop();
                delete shares[_validator];
                emit ValidatorRemoved(_validator);
                return true;
            }
        }
        return false;
    }

    function _setShare(address _validator, uint _share) internal {
        require(_share > 0, "share shouldn't be zero");
        require(shares[_validator] > 0, "validator doesn't exist");
        
        shares[_validator] = _share;
    }


    function _validateTotalShares() internal view {
        uint totalShares;
        for (uint i; i < validators.length; i++) {
            totalShares += shares[validators[i]];
        }
        require(totalShares == BASIS_POINT || validators.length == 0, "total shares must equal BASIS_POINT");
    }
}

