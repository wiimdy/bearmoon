// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/core/ILiquidStabilityPool.sol";
import "../interfaces/core/ILiquidationManager.sol";
import "../interfaces/core/ISortedDens.sol";
import "../interfaces/core/IBorrowerOperations.sol";
import "../interfaces/core/IDenManager.sol";
import "../interfaces/core/IFactory.sol";
import "../dependencies/BeraborrowMath.sol";
import "../dependencies/BeraborrowBase.sol";

/**
    @title Beraborrow Liquidation Manager
    @notice Based on Liquity's `DenManager`
            https://github.com/liquity/dev/blob/main/packages/contracts/contracts/DenManager.sol

            This contract has a 1:n relationship with `DenManager`, handling liquidations
            for every active collateral within the system.

            Anyone can call to liquidate an eligible den at any time. There is no requirement
            that liquidations happen in order according to den ICRs. There are three ways that
            a liquidation can occur:

            1. ICR <= 100
               The den's entire debt and collateral is redistributed between remaining active dens.

            2. 100 < ICR < MCR
               The den is liquidated using stability pool deposits. The collateral is distributed
               amongst stability pool depositors. If the stability pool's balance is insufficient to
               completely repay the den, the remaining debt and collateral is redistributed between
               the remaining active dens.

            3. MCR <= ICR < TCR && TCR < CCR
               The den is liquidated using stability pool deposits. Collateral equal to MCR of
               the value of the debt is distributed between stability pool depositors. The remaining
               collateral is left claimable by the den owner.
 */
contract LiquidationManager is BeraborrowBase {
    ILiquidStabilityPool public immutable liquidStabilityPool;
    IBorrowerOperations public immutable borrowerOperations;
    address public immutable factory;

    address public validatorPool;
    address public sNectGauge;

    uint public liquidatorFee;
    uint public sNectGaugeFee;
    uint public poolFee;

    // To not redistribute more debt than collateral into LSP, we account for the coll gas compensation
    uint256 private constant _LSP_CR_LIMIT = 1e18 + 1e18 / PERCENT_DIVISOR; // 1e18 == 100%

    mapping(IDenManager denManager => bool enabled) internal _enabledDenManagers;

    mapping(address => uint256) public nonces;  // Track nonces to prevent replay attacks

    bytes32 private constant TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 private immutable _hashedName;
    bytes32 private immutable _hashedVersion;

    bytes32 private immutable _cachedDomainSeparator;
    uint256 private immutable _cachedChainId;
    address private immutable _cachedThis;

    // EIP-712 structured data type hash
    bytes32 public constant PERMIT_TYPEHASH1 =
        keccak256("Permit(address liquidator,address denManager,address borrower,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH2 =
        keccak256("Permit(address liquidator,address denManager,uint256 maxDensToLiquidate,uint256 maxICR,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH3 =
        keccak256("Permit(address liquidator,address denManager,address[] denArray,uint256 nonce,uint256 deadline)");

    /*
     * --- Variable container structs for liquidations ---
     *
     * These structs are used to hold, return and assign variables inside the liquidation functions,
     * in order to avoid the error: "CompilerError: Stack too deep".
     **/

    struct DenManagerValues {
        address brimeDen;
        ISortedDens sortedDens;
        uint256 price;
        uint256 MCR;
        bool sunsetting;
    }

    struct LiquidationValues {
        uint256 entireDenDebt;
        uint256 entireDenColl;
        uint256 collGasCompensation;
        uint256 debtGasCompensation;
        uint256 debtToOffset;
        uint256 collToSendToSP;
        uint256 debtToRedistribute;
        uint256 collToRedistribute;
        uint256 collSurplus;
    }

    struct LiquidationTotals {
        uint256 totalCollInSequence;
        uint256 totalDebtInSequence;
        uint256 totalCollGasCompensation;
        uint256 totalDebtGasCompensation;
        uint256 totalDebtToOffset;
        uint256 totalCollToSendToSP;
        uint256 totalDebtToRedistribute;
        uint256 totalCollToRedistribute;
        uint256 totalCollSurplus;
    }

    event DenUpdated(
        IDenManager indexed _denManager,
        address indexed _borrower,
        uint256 _debt,
        uint256 _coll,
        uint256 _stake,
        DenManagerOperation _operation
    );
    event DenLiquidated(IDenManager indexed _denManager, address indexed _borrower, uint256 _debt, uint256 _coll, DenManagerOperation _operation);
    event Liquidation(
        IDenManager indexed _denManager,
        uint256 _liquidatedDebt,
        uint256 _liquidatedColl,
        uint256 _collGasCompensation,
        uint256 _debtGasCompensation
    );
    event ValidatorPoolSet(address indexed _validatorPool);
    event SnectGaugeSet(address indexed _sNectGauge);

    event FeesChanged(uint _liquidatorFee, uint _sNectGaugeFee, uint _poolFee);

    enum DenManagerOperation {
        applyPendingRewards,
        liquidateInNormalMode,
        liquidateInRecoveryMode,
        redeemCollateral
    }

    constructor(
        ILiquidStabilityPool _liquidStabilityPoolAddress,
        IBorrowerOperations _borrowerOperations,
        address _factory,
        uint256 _gasCompensation,
        address _validatorPool,
        address _sNectGauge,
        uint256 _liquidatorFee,
        uint256 _sNectGaugeFee,
        uint256 _poolFee
    ) BeraborrowBase(_gasCompensation) {
        if (address(_liquidStabilityPoolAddress) == address(0) || address(_borrowerOperations) == address(0) || _factory == address(0)) {
            revert("LiquidationManager: 0 address");
        }
        require(_liquidatorFee + _sNectGaugeFee + _poolFee == 1e18, "fees must equal 100%");

        liquidStabilityPool = _liquidStabilityPoolAddress;
        borrowerOperations = _borrowerOperations;
        factory = _factory;

        require(_validatorPool != address(0), "ValidatorPool can't be zero address");
        require(_sNectGauge != address(0), "sNectGauge can't be zero address");
        validatorPool = _validatorPool;
        sNectGauge = _sNectGauge;

        _hashedName = keccak256(bytes("LiquidationManager"));
        _hashedVersion = keccak256(bytes("1"));

        _cachedChainId = block.chainid;
        _cachedDomainSeparator = _buildDomainSeparator(TYPE_HASH, _hashedName, _hashedVersion);
        _cachedThis = address(this);

        liquidatorFee = _liquidatorFee;
        sNectGaugeFee = _sNectGaugeFee;
        poolFee = _poolFee;
    }

    // --- EIP 2612 Functionality ---

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        if (address(this) == _cachedThis && block.chainid == _cachedChainId) {
            return _cachedDomainSeparator;
        } else {
            return _buildDomainSeparator(TYPE_HASH, _hashedName, _hashedVersion);
        }
    }

    function _buildDomainSeparator(
        bytes32 typeHash,
        bytes32 name_,
        bytes32 version_
    ) private view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    typeHash,
                    name_,
                    version_,
                    block.chainid,
                    address(this)
                )
            );
    }

    function enableDenManager(IDenManager _denManager) external {
        require(msg.sender == factory, "Not factory");
        _enabledDenManagers[_denManager] = true;
    }

    function setFees(uint _liquidatorFee, uint _sNectGaugeFee, uint _poolFee) external {
        require(msg.sender == IFactory(factory).owner(), "not owner");
        require(_liquidatorFee + _sNectGaugeFee + _poolFee == 1e18, "sum doesn't equal to 100%");

        liquidatorFee = _liquidatorFee;
        sNectGaugeFee = _sNectGaugeFee;
        poolFee = _poolFee;

        emit FeesChanged(_liquidatorFee, _sNectGaugeFee, _poolFee);
    }

    // --- Den Liquidation functions ---

    /**
        @notice Liquidate a single den
        @dev Reverts if the den is not active, or cannot be liquidated
        @param borrower Borrower address to liquidate
        @param liquidator Address to which the liquidator coll gas compensation is sent
     */
    function liquidate(IDenManager denManager, address borrower, address liquidator) public {
        require(denManager.getDenStatus(borrower) == 1, "DenManager: Den does not exist or is closed");

        address[] memory borrowers = new address[](1);
        borrowers[0] = borrower;
        batchLiquidateDens(denManager, borrowers, liquidator);
    }

     // Liquidation with permit using EIP-712 signature
    function liquidateWithPermit(
        IDenManager denManager,
        address borrower,
        address liquidator,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(block.timestamp <= deadline, "Permit expired");

        bytes32 structHash;
        unchecked {
            structHash = keccak256(
                abi.encode(
                    PERMIT_TYPEHASH1,
                    liquidator,
                    address(denManager),
                    borrower,
                    nonces[liquidator]++,
                    deadline
                )
            );
        }

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), structHash)
        );

        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == liquidator, "Invalid signature");

        liquidate(denManager, borrower, liquidator);
    }

    /**
        @notice Liquidate a sequence of dens
        @dev Iterates through dens starting with the lowest ICR
        @param maxDensToLiquidate The maximum number of dens to liquidate
        @param maxICR Maximum ICR to liquidate. Should be set to MCR if the system
                      is not in recovery mode, to minimize gas costs for this call.
        @param liquidator Address to which the liquidator coll gas compensation is sent
     */
    function liquidateDens(IDenManager denManager, uint256 maxDensToLiquidate, uint256 maxICR, address liquidator) public {
        require(_enabledDenManagers[denManager], "DenManager not approved");

        denManager.updateBalances();

        LiquidationValues memory singleLiquidation;
        LiquidationTotals memory totals;
        DenManagerValues memory denManagerValues;

        uint256 densRemaining = maxDensToLiquidate;
        uint256 denCount = denManager.getDenOwnersCount();
        denManagerValues.price = denManager.fetchPrice();
        denManagerValues.sunsetting = denManager.sunsetting();
        denManagerValues.MCR = denManager.MCR();
        denManagerValues.brimeDen = denManager.brimeDen();
        denManagerValues.sortedDens = ISortedDens(denManager.sortedDens());

        uint debtInStabPool = liquidStabilityPool.getTotalDebtTokenDeposits();

        while (densRemaining > 0 && denCount > 1) {
            address account = denManagerValues.sortedDens.getLast();
            uint ICR = denManager.getCurrentICR(account, denManagerValues.price);
            uint applicableMCR = _getApplicableMCR(account, denManagerValues);
            if (ICR > maxICR) {
                // set to 0 to ensure the next if block evaluates false
                densRemaining = 0;
                break;
            }
            if (ICR <= _LSP_CR_LIMIT) {
                singleLiquidation = _liquidateWithoutSP(denManager, account);
                _applyLiquidationValuesToTotals(totals, singleLiquidation);
            } else if (ICR < applicableMCR) {
                singleLiquidation = _liquidateNormalMode(
                    denManager,
                    account,
                    debtInStabPool,
                    denManagerValues.sunsetting
                );
                debtInStabPool -= singleLiquidation.debtToOffset;
                _applyLiquidationValuesToTotals(totals, singleLiquidation);
            } else break; // break if the loop reaches a Den with ICR >= MCR
            unchecked {
                --densRemaining;
                --denCount;
            }
        }
        if (densRemaining > 0 && !denManagerValues.sunsetting && denCount > 1) {
            (uint entireSystemColl, uint entireSystemDebt) = borrowerOperations.getGlobalSystemBalances();
            entireSystemColl -= (totals.totalCollGasCompensation + totals.totalCollToSendToSP) * denManagerValues.price;
            entireSystemDebt -= totals.totalDebtToOffset;
            address nextAccount = denManagerValues.sortedDens.getLast();
            while (densRemaining > 0 && denCount > 1) {
                uint ICR = denManager.getCurrentICR(nextAccount, denManagerValues.price);
                if (ICR > maxICR) break;
                unchecked {
                    --densRemaining;
                }
                address account = nextAccount;
                nextAccount = denManagerValues.sortedDens.getPrev(account);

                {
                    uint256 TCR = BeraborrowMath._computeCR(entireSystemColl, entireSystemDebt);
                    if (TCR >= borrowerOperations.BERABORROW_CORE().CCR() || ICR >= TCR) break;
                }

                singleLiquidation = _tryLiquidateWithCap(
                    denManager,
                    account,
                    debtInStabPool,
                    _getApplicableMCR(account, denManagerValues),
                    denManagerValues.price
                );
                if (singleLiquidation.debtToOffset == 0) continue;
                debtInStabPool -= singleLiquidation.debtToOffset;
                entireSystemColl -=
                    (singleLiquidation.collToSendToSP + singleLiquidation.collSurplus
                    + singleLiquidation.collGasCompensation) * denManagerValues.price;
                entireSystemDebt -= singleLiquidation.debtToOffset;
                _applyLiquidationValuesToTotals(totals, singleLiquidation);
                unchecked {
                    --denCount;
                }
            }
        }

        require(totals.totalDebtInSequence > 0, "DenManager: nothing to liquidate");
        if (totals.totalDebtToOffset > 0 || totals.totalCollToSendToSP > 0) {
            // Move liquidated collateral and Debt to the appropriate pools
            liquidStabilityPool.offset(
                denManager.collateralToken(),
                totals.totalDebtToOffset,
                totals.totalCollToSendToSP
            );
            denManager.decreaseDebtAndSendCollateral(
                address(liquidStabilityPool),
                totals.totalDebtToOffset,
                totals.totalCollToSendToSP
            );
        }
        denManager.finalizeLiquidation(
            liquidator,
            totals.totalDebtToRedistribute,
            totals.totalCollToRedistribute,
            totals.totalCollSurplus,
            totals.totalDebtGasCompensation,
            totals.totalCollGasCompensation
        );

        emit Liquidation(
            denManager,
            totals.totalDebtInSequence,
            totals.totalCollInSequence - totals.totalCollGasCompensation - totals.totalCollSurplus,
            totals.totalCollGasCompensation,
            totals.totalDebtGasCompensation
        );
    }

    function liquidateDensWithPermit(
        IDenManager denManager,
        uint256 maxDensToLiquidate,
        uint256 maxICR,
        address liquidator,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(block.timestamp <= deadline, "Permit expired");

        bytes32 structHash;
        unchecked {
            structHash = keccak256(
                abi.encode(
                    PERMIT_TYPEHASH2,
                    liquidator,
                    address(denManager),
                    maxDensToLiquidate,
                    maxICR,
                    nonces[liquidator]++,
                    deadline
                )
            );
        }

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), structHash)
        );

        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == liquidator, "Invalid signature");

        liquidateDens(denManager, maxDensToLiquidate, maxICR, liquidator);
    }

    /**
        @notice Liquidate a custom list of dens
        @dev Reverts if there is not a single den that can be liquidated
        @param _denArray List of borrower addresses to liquidate. Dens that were already
                           liquidated, or cannot be liquidated, are ignored.
        @param liquidator Address to which the liquidator coll gas compensation is sent
     */
    /*
     * Attempt to liquidate a custom list of dens provided by the caller.
     */
    function batchLiquidateDens(IDenManager denManager, address[] memory _denArray, address liquidator) public {
        require(_enabledDenManagers[denManager], "DenManager not approved");
        require(_denArray.length != 0, "DenManager: Calldata address array must not be empty");
        denManager.updateBalances();

        LiquidationValues memory singleLiquidation;
        LiquidationTotals memory totals;
        DenManagerValues memory denManagerValues;

        ILiquidStabilityPool liquidStabilityPoolCached = liquidStabilityPool;
        uint debtInStabPool = liquidStabilityPoolCached.getTotalDebtTokenDeposits();
        denManagerValues.price = denManager.fetchPrice();
        denManagerValues.sunsetting = denManager.sunsetting();
        denManagerValues.MCR = denManager.MCR();
        denManagerValues.brimeDen = denManager.brimeDen();

        uint denCount = denManager.getDenOwnersCount();
        uint denIter;
        while (denIter < _denArray.length && denCount > 1) {
            // first iteration round, when all liquidated dens have ICR < MCR we do not need to track TCR
            address account = _denArray[denIter];
            // closed / non-existent dens return an ICR of type(uint).max and are ignored
            uint ICR = denManager.getCurrentICR(account, denManagerValues.price);
            uint applicableMCR = _getApplicableMCR(account, denManagerValues);

            if (ICR <= _LSP_CR_LIMIT) {
                singleLiquidation = _liquidateWithoutSP(denManager, account);
            } else if (ICR < applicableMCR) {
                singleLiquidation = _liquidateNormalMode(
                    denManager,
                    account,
                    debtInStabPool,
                    denManagerValues.sunsetting
                );
                debtInStabPool -= singleLiquidation.debtToOffset;
            } else {
                // As soon as we find a den with ICR >= MCR we need to start tracking the global TCR with the next loop
                break;
            }
            _applyLiquidationValuesToTotals(totals, singleLiquidation);
            unchecked {
                ++denIter;
                --denCount;
            }
        }

        if (denIter < _denArray.length && denCount > 1) {
            // second iteration round, if we receive a den with ICR > MCR and need to track TCR
            (uint256 entireSystemColl, uint256 entireSystemDebt) = borrowerOperations.getGlobalSystemBalances();
            entireSystemColl -= (totals.totalCollGasCompensation + totals.totalCollToSendToSP) * denManagerValues.price;
            entireSystemDebt -= totals.totalDebtToOffset;
            while (denIter < _denArray.length && denCount > 1) {
                address account = _denArray[denIter];
                uint ICR = denManager.getCurrentICR(account, denManagerValues.price);
                unchecked {
                    ++denIter;
                }

                uint applicableMCR = _getApplicableMCR(account, denManagerValues);

                if (ICR <= _LSP_CR_LIMIT) {
                    singleLiquidation = _liquidateWithoutSP(denManager, account);
                } else if (ICR < applicableMCR) {
                    singleLiquidation = _liquidateNormalMode(
                        denManager,
                        account,
                        debtInStabPool,
                        denManagerValues.sunsetting
                    );
                } else {
                    if (denManagerValues.sunsetting) continue;
                    {
                        uint256 TCR = BeraborrowMath._computeCR(entireSystemColl, entireSystemDebt);
                        if (TCR >= borrowerOperations.BERABORROW_CORE().CCR() || ICR >= TCR) continue;
                    }
                    singleLiquidation = _tryLiquidateWithCap(
                        denManager,
                        account,
                        debtInStabPool,
                        applicableMCR,
                        denManagerValues.price
                    );

                    if (singleLiquidation.debtToOffset == 0) continue;
                }

                debtInStabPool -= singleLiquidation.debtToOffset;
                entireSystemColl -=
                    (singleLiquidation.collToSendToSP + singleLiquidation.collSurplus
                    + singleLiquidation.collGasCompensation) * denManagerValues.price;
                entireSystemDebt -= singleLiquidation.debtToOffset;
                _applyLiquidationValuesToTotals(totals, singleLiquidation);
                unchecked {
                    --denCount;
                }
            }
        }

        require(totals.totalDebtInSequence > 0, "DenManager: nothing to liquidate");

        if (totals.totalDebtToOffset > 0 || totals.totalCollToSendToSP > 0) {
            // Move liquidated collateral and Debt to the appropriate pools
            liquidStabilityPoolCached.offset(
                denManager.collateralToken(),
                totals.totalDebtToOffset,
                totals.totalCollToSendToSP
            );
            denManager.decreaseDebtAndSendCollateral(
                address(liquidStabilityPoolCached),
                totals.totalDebtToOffset,
                totals.totalCollToSendToSP
            );
        }
        denManager.finalizeLiquidation(
            liquidator,
            totals.totalDebtToRedistribute,
            totals.totalCollToRedistribute,
            totals.totalCollSurplus,
            totals.totalDebtGasCompensation,
            totals.totalCollGasCompensation
        );

        emit Liquidation(
            denManager,
            totals.totalDebtInSequence,
            totals.totalCollInSequence - totals.totalCollGasCompensation - totals.totalCollSurplus,
            totals.totalCollGasCompensation,
            totals.totalDebtGasCompensation
        );
    }

    function batchLiquidateDensWithPermit(
        IDenManager denManager, 
        address[] memory _denArray,
        address liquidator,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        require(block.timestamp <= deadline, "Permit expired");

        bytes32 structHash;
        unchecked {
            structHash = keccak256(
                abi.encode(
                    PERMIT_TYPEHASH3,
                    liquidator,
                    address(denManager),
                    _denArray,
                    nonces[liquidator]++,
                    deadline
                )
            );
        }

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), structHash)
        );

        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == liquidator, "Invalid signature");
        
        batchLiquidateDens(denManager, _denArray, liquidator);
    }

    /**
        @dev Perform a "normal" liquidation, where 100% < ICR < MCR. The den
             is liquidated as much as possible using the stability pool. Any
             remaining debt and collateral are redistributed between active dens.
     */
    function _liquidateNormalMode(
        IDenManager denManager,
        address _borrower,
        uint256 _debtInStabPool,
        bool sunsetting
    ) internal returns (LiquidationValues memory singleLiquidation) {
        uint pendingDebtReward;
        uint pendingCollReward;

        (
            singleLiquidation.entireDenDebt,
            singleLiquidation.entireDenColl,
            pendingDebtReward,
            pendingCollReward
        ) = denManager.getEntireDebtAndColl(_borrower);

        denManager.movePendingDenRewardsToActiveBalances(pendingDebtReward, pendingCollReward);

        singleLiquidation.collGasCompensation = _getCollGasCompensation(singleLiquidation.entireDenColl);
        singleLiquidation.debtGasCompensation = DEBT_GAS_COMPENSATION;
        uint256 collToLiquidate = singleLiquidation.entireDenColl - singleLiquidation.collGasCompensation;

        (
            singleLiquidation.debtToOffset,
            singleLiquidation.collToSendToSP,
            singleLiquidation.debtToRedistribute,
            singleLiquidation.collToRedistribute
        ) = _getOffsetAndRedistributionVals(
            singleLiquidation.entireDenDebt,
            collToLiquidate,
            _debtInStabPool,
            sunsetting
        );

        denManager.closeDenByLiquidation(_borrower);
        emit DenLiquidated(
            denManager,
            _borrower,
            singleLiquidation.entireDenDebt,
            singleLiquidation.entireDenColl,
            DenManagerOperation.liquidateInNormalMode
        );
        emit DenUpdated(denManager, _borrower, 0, 0, 0, DenManagerOperation.liquidateInNormalMode);
        return singleLiquidation;
    }

    /**
        @dev Attempt to liquidate a single den in recovery mode.
             If MCR <= ICR < current TCR (accounting for the preceding liquidations in the current sequence)
             and there is Debt in the Stability Pool, only offset, with no redistribution,
             but at a capped rate of 1.1 and only if the whole debt can be liquidated.
             The remainder due to the capped rate will be claimable as collateral surplus.
     */
    function _tryLiquidateWithCap(
        IDenManager denManager,
        address _borrower,
        uint256 _debtInStabPool,
        uint256 _MCR,
        uint256 _price
    ) internal returns (LiquidationValues memory singleLiquidation) {
        uint entireDenDebt;
        uint entireDenColl;
        uint pendingDebtReward;
        uint pendingCollReward;

        (entireDenDebt, entireDenColl, pendingDebtReward, pendingCollReward) = denManager.getEntireDebtAndColl(
            _borrower
        );

        if (entireDenDebt > _debtInStabPool) {
            // do not liquidate if the entire den cannot be liquidated via SP
            return singleLiquidation;
        }

        denManager.movePendingDenRewardsToActiveBalances(pendingDebtReward, pendingCollReward);

        singleLiquidation.entireDenDebt = entireDenDebt;
        singleLiquidation.entireDenColl = entireDenColl;
        uint256 collToOffset = (entireDenDebt * _MCR) / _price;

        singleLiquidation.collGasCompensation = _getCollGasCompensation(collToOffset);
        singleLiquidation.debtGasCompensation = DEBT_GAS_COMPENSATION;

        singleLiquidation.debtToOffset = entireDenDebt;
        singleLiquidation.collToSendToSP = collToOffset - singleLiquidation.collGasCompensation;

        denManager.closeDenByLiquidation(_borrower);

        uint256 collSurplus = entireDenColl - collToOffset;
        if (collSurplus > 0) {
            singleLiquidation.collSurplus = collSurplus;
            denManager.addCollateralSurplus(_borrower, collSurplus);
        }

        emit DenLiquidated(
            denManager,
            _borrower,
            entireDenDebt,
            singleLiquidation.collToSendToSP,
            DenManagerOperation.liquidateInRecoveryMode
        );
        emit DenUpdated(denManager, _borrower, 0, 0, 0, DenManagerOperation.liquidateInRecoveryMode);

        return singleLiquidation;
    }

    /**
        @dev Liquidate a den without using the stability pool. All debt and collateral
             are distributed porportionally between the remaining active dens.
     */
    function _liquidateWithoutSP(
        IDenManager denManager,
        address _borrower
    ) internal returns (LiquidationValues memory singleLiquidation) {
        uint pendingDebtReward;
        uint pendingCollReward;

        (
            singleLiquidation.entireDenDebt,
            singleLiquidation.entireDenColl,
            pendingDebtReward,
            pendingCollReward
        ) = denManager.getEntireDebtAndColl(_borrower);

        singleLiquidation.collGasCompensation = _getCollGasCompensation(singleLiquidation.entireDenColl);
        singleLiquidation.debtGasCompensation = DEBT_GAS_COMPENSATION;
        denManager.movePendingDenRewardsToActiveBalances(pendingDebtReward, pendingCollReward);

        singleLiquidation.debtToOffset = 0;
        singleLiquidation.collToSendToSP = 0;
        singleLiquidation.debtToRedistribute = singleLiquidation.entireDenDebt;
        singleLiquidation.collToRedistribute =
            singleLiquidation.entireDenColl -
            singleLiquidation.collGasCompensation;

        denManager.closeDenByLiquidation(_borrower);
        emit DenLiquidated(
            denManager,
            _borrower,
            singleLiquidation.entireDenDebt,
            singleLiquidation.entireDenColl,
            DenManagerOperation.liquidateInRecoveryMode
        );
        emit DenUpdated(denManager, _borrower, 0, 0, 0, DenManagerOperation.liquidateInRecoveryMode);
        return singleLiquidation;
    }

    /* In a full liquidation, returns the values for a den's coll and debt to be offset, and coll and debt to be
     * redistributed to active dens.
     */
    function _getOffsetAndRedistributionVals(
        uint256 _debt,
        uint256 _coll,
        uint256 _debtInStabPool,
        bool sunsetting
    )
        internal
        pure
        returns (uint256 debtToOffset, uint256 collToSendToSP, uint256 debtToRedistribute, uint256 collToRedistribute)
    {
        if (_debtInStabPool > 0 && !sunsetting) {
            /*
             * Offset as much debt & collateral as possible against the Stability Pool, and redistribute the remainder
             * between all active dens.
             *
             *  If the den's debt is larger than the deposited Debt in the Stability Pool:
             *
             *  - Offset an amount of the den's debt equal to the Debt in the Stability Pool
             *  - Send a fraction of the den's collateral to the Stability Pool, equal to the fraction of its offset debt
             *
             */
            debtToOffset = BeraborrowMath._min(_debt, _debtInStabPool);
            collToSendToSP = (_coll * debtToOffset) / _debt;
            debtToRedistribute = _debt - debtToOffset;
            collToRedistribute = _coll - collToSendToSP;
        } else {
            debtToOffset = 0;
            collToSendToSP = 0;
            debtToRedistribute = _debt;
            collToRedistribute = _coll;
        }
    }

    /**
        @dev Adds values from `singleLiquidation` to `totals`
             Calling this function mutates `totals`, the change is done in-place
             to avoid needless expansion of memory
     */
    function _applyLiquidationValuesToTotals(
        LiquidationTotals memory totals,
        LiquidationValues memory singleLiquidation
    ) internal pure {
        // Tally all the values with their respective running totals
        totals.totalCollGasCompensation = totals.totalCollGasCompensation + singleLiquidation.collGasCompensation;
        totals.totalDebtGasCompensation = totals.totalDebtGasCompensation + singleLiquidation.debtGasCompensation;
        totals.totalDebtInSequence = totals.totalDebtInSequence + singleLiquidation.entireDenDebt;
        totals.totalCollInSequence = totals.totalCollInSequence + singleLiquidation.entireDenColl;
        totals.totalDebtToOffset = totals.totalDebtToOffset + singleLiquidation.debtToOffset;
        totals.totalCollToSendToSP = totals.totalCollToSendToSP + singleLiquidation.collToSendToSP;
        totals.totalDebtToRedistribute = totals.totalDebtToRedistribute + singleLiquidation.debtToRedistribute;
        totals.totalCollToRedistribute = totals.totalCollToRedistribute + singleLiquidation.collToRedistribute;
        totals.totalCollSurplus = totals.totalCollSurplus + singleLiquidation.collSurplus;
    }

    // Helper function to get applicable MCR
    function _getApplicableMCR(address account, DenManagerValues memory denManagerValues) internal view returns (uint) {
        if(account == denManagerValues.brimeDen) {
            uint brimeMCR = borrowerOperations.brimeMCR();
            return brimeMCR;
        } else {
            return denManagerValues.MCR;
        }
    }

    function setValidatorPool(address _validatorPool) public {
        require(msg.sender == IFactory(factory).owner(), "not owner");
        require(_validatorPool != address(0), "can't be zero address");
        require(validatorPool != _validatorPool, "already set");

        validatorPool = _validatorPool;
        emit ValidatorPoolSet(_validatorPool);
    }

    function setSNECTGauge(address _sNectGauge) public {
        require(msg.sender == IFactory(factory).owner(), "not owner");
        require(_sNectGauge != address(0), "can't be zero address");
        require(sNectGauge != _sNectGauge, "already set");

        sNectGauge = _sNectGauge;
        emit SnectGaugeSet(_sNectGauge);
    }

    function liquidationsFeeAndRecipients() external view returns (ILiquidationManager.LiquidationFeeData memory data) {
        data = ILiquidationManager.LiquidationFeeData({
            liquidatorFee: liquidatorFee,
            sNectGaugeFee: sNectGaugeFee,
            poolFee: poolFee,
            validatorPool: validatorPool,
            sNectGauge: sNectGauge
        });
    }

    /**
    * @dev Get liquidation fee data for liquidator
     */
     function liquidatorLiquidationFee() external view returns (uint256) {
        return liquidatorFee;
     }

     /**
    * @dev Get liquidation fee data for sNECT gauge incentives
     */
     function sNectGaugeLiquidationFee() external view returns (address, uint256) {
        return (sNectGauge, sNectGaugeFee);
     }

     /**
     @dev Get liquidation fee for a validator pool
      */
    function poolLiquidationFee() external view returns (address, uint256) {
        return (validatorPool, poolFee);
    }
}
