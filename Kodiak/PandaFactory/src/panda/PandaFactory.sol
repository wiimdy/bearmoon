// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {IPandaPool} from "src/interfaces/IPandaPool.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "src/interfaces/IPandaFactory.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {PandaMath} from "src/libraries/PandaMath.sol";
import {TransferHelper} from "src/libraries/TransferHelper.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IWETH} from "src/interfaces/IWETH.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract PandaFactory is Ownable, IPandaFactory, ReentrancyGuard {
    using Math for uint256;

    //Panda Configs (can be set by owner)
    PandaFees private poolFees = PandaFees({buyFee: 0, sellFee: 200, graduationFee: 500, deployerFeeShare: 0});
    address public override treasury;
    address public override wbera;
    mapping(address => uint256) public override minRaise;
    mapping(address => uint256) public override minTradeSize;

    //Panda Pool Constants - bounding the conditions reasonably
    uint256 public override constant MIN_TOKENSINPOOL_SHARE = 5000; //50%
    uint256 public override constant MAX_TOKENSINPOOL_SHARE = 9000; //90%
    uint256 public override constant MIN_SQRTP_MULTIPLE = 11_000; //1.1x in sqrtP minimum distance
    uint256 public override constant MAX_SQRTP_MULTIPLE = 10*10_000; //10x in sqrtP = 100x in P = ~90% tokensInPool

    //Panda Token Defaults
    uint256 public override constant TOKEN_SUPPLY = 1_000_000_000 * 1e18;
    uint16 public override constant DEPLOYER_MAX_BPS = 5000; // 50%

    //Move Liquidity Defaults
    address public dexFactory; //UniV2 style dex factory
    bytes32 public initCodeHash; //UniV2 style initCodeHash (for deterministic pair creation)

    //List of allowed implementations of PandaPools. Multiple canonical implementations can be allowed
    mapping(address => bool) public override isImplementationAllowed;
    address[] public override allowedImplementations;

    //Deployer incentives
    address public override incentiveToken;
    uint256 public override incentiveAmount;
    mapping(address => bool) public override poolToIncentiveClaimed;
    mapping(address => uint256) public override deployerNonce; //Keep track of how many deployments by each deployer (for deterministic address)

    //Deployed Pools information
    address[] public override allPools; //list of all pandaPools
    mapping(address => address) public override poolToImplementation; //map pandaPool to canonical implementation (e.g. PandaToken)

    //*********************** CONSTRUCTOR ***************************************************
    constructor(address _treasury, address _dexFactory, bytes32 _initCodeHash, address _wbera) {
        treasury = _treasury;
        dexFactory = _dexFactory;
        initCodeHash = _initCodeHash;
        wbera = _wbera;
        _transferOwnership(_treasury);
    }

    //*********************** EXTERNAL FUNCTIONS *********************************************
    //To deploy a PandaToken + PandaPool with optional deployer buy
    function deployPandaToken(
        address implementation,
        IPandaFactory.PandaPoolParams calldata pp,  //baseToken, sqrtPa, sqrtPb, vestingPeriod
        string calldata name,
        string calldata symbol,
        uint16 deployerSupplyBps
    ) external nonReentrant override returns (address pandaToken) {
        require(deployerSupplyBps <= DEPLOYER_MAX_BPS, "PandaFactory: INVALID_DEPLOYER_BUY");
        pandaToken = _deployPandaToken(implementation, pp, name, symbol);

        if(deployerSupplyBps > 0) {
            _buyTokens(pandaToken, pp.baseToken, deployerSupplyBps);
        }
    }

     function deployPandaTokenWithBera(
        address implementation,
        IPandaFactory.PandaPoolParams calldata pp,  //baseToken, sqrtPa, sqrtPb, vestingPeriod
        string calldata name,
        string calldata symbol,
        uint16 deployerSupplyBps
    ) external payable nonReentrant override returns (address pandaToken) {
        require(wbera == pp.baseToken, "PandaFactory: INVALID_BERA");
        require(deployerSupplyBps <= DEPLOYER_MAX_BPS, "PandaFactory: INVALID_DEPLOYER_BUY");
        pandaToken = _deployPandaToken(implementation, pp, name, symbol);

        if(msg.value > 0) {
            uint256 amountIn = _buyTokensWithBera(pandaToken, deployerSupplyBps);
            TransferHelper.safeTransferETH(msg.sender, msg.value - amountIn);
        }
    }

    //To deploy an implementation of PandaPool that's not also creating a PandaToken
    //This requires specifying the PandaToken, and approving the tokens to be sent to the pool from the deployer
    function deployPandaPool(
        address implementation,
        IPandaFactory.PandaPoolParams calldata pp,  //baseToken, sqrtPa, sqrtPb, vestingPeriod
        uint256 totalTokens,
        address pandaToken,
        bytes calldata data
    ) external nonReentrant override returns (address) {
        require(isImplementationAllowed[implementation], "PandaFactory: INVALID_IMPLEMENTATION");
        IPandaPool panda = IPandaPool(implementation);
        require(!panda.isPandaToken(), "PandaFactory: IS_PANDATOKEN");
        require(pandaToken != address(0), "PandaFactory: INVALID_PANDATOKEN");

        //Check inputs are good
        _checkDeploymentInputs(pp, totalTokens, panda);

        //Deploy
        IPandaPool pandaPool = _createClone(implementation, msg.sender);

        //Send in the pandaTokens
        TransferHelper.safeTransferFrom(pandaToken, msg.sender, address(pandaPool), totalTokens);

        //Initialize
        pandaPool.initializePool(
            pandaToken,
            pp,
            totalTokens,
            msg.sender,
            data
        );

        //Push to list
        allPools.push(address(pandaPool));
        poolToImplementation[address(pandaPool)] = implementation;
        emit PandaDeployed(address(pandaPool), address(implementation));
        return address(pandaPool);
    }


    function _deployPandaToken(
        address implementation,
        IPandaFactory.PandaPoolParams calldata pp,  //baseToken, sqrtPa, sqrtPb, vestingPeriod
        string calldata name,
        string calldata symbol
    ) internal returns (address) {
        require(isImplementationAllowed[implementation], "PandaFactory: INVALID_IMPLEMENTATION");
        IPandaPool panda = IPandaPool(implementation);

        {
            //Check inputs are good
            require(panda.isPandaToken(), "PandaFactory: NOT_PANDATOKEN");
            _checkDeploymentInputs(pp, TOKEN_SUPPLY, panda);
        }

        //Deploy
        IPandaPool pandaToken = _createClone(implementation, msg.sender);

        //Initialize
        {
            bytes memory data = abi.encode(name, symbol);
            pandaToken.initializePool(
                address(pandaToken),
                pp,
                TOKEN_SUPPLY,
                msg.sender,
                data
            );
        }

        //Push to list
        {
            allPools.push(address(pandaToken));
            poolToImplementation[address(pandaToken)] = implementation;
            emit PandaDeployed(address(pandaToken), address(implementation));
        }
        return address(pandaToken);
    }

    function _buyTokens(address pool, address baseToken, uint16 deployerSupplyBps) internal {
        uint256 amountOut = TOKEN_SUPPLY * deployerSupplyBps / PandaMath.FEE_SCALE;

        try IPandaPool(pool).getAmountInBuy(amountOut) returns (uint256 amountIn, uint256, uint256) {
            uint256 allowance = IERC20(baseToken).allowance(msg.sender, address(this));
            if(allowance < amountIn) {
                return;
            }
            // Proceed with the transfers and token buy if getAmountInBuy doesn't revert
            TransferHelper.safeTransferFrom(baseToken, msg.sender, address(this), amountIn);
            TransferHelper.safeApprove(baseToken, address(pool), amountIn);
            IPandaPool(pool).buyTokens(amountIn, amountOut * 9900/10000, msg.sender);
        } catch {
            return;
        }
    }

    function _buyTokensWithBera(address pool, uint16 deployerSupplyBps) internal returns (uint256) {
        uint256 amountOut = TOKEN_SUPPLY * deployerSupplyBps / PandaMath.FEE_SCALE;

        try IPandaPool(pool).getAmountInBuy(amountOut) returns (uint256 amountIn, uint256, uint256) {
            if(msg.value < amountIn) {
                TransferHelper.safeTransferETH(msg.sender, msg.value);
                return 0;
            }
            IPandaPool(pool).buyTokensWithBera{value: amountIn}(amountOut * 9900/10000, msg.sender);
            return amountIn;
        } catch {
            return 0;
        }
    }
    
    function _createClone(address _implementation, address _deployer) internal returns (IPandaPool) {
        bytes32 salt = keccak256(abi.encodePacked(_deployer, deployerNonce[_deployer]++));
        return IPandaPool(Clones.cloneDeterministic(_implementation, salt));
    }

    function _checkDeploymentInputs(PandaPoolParams calldata pp, uint256 totalTokens, IPandaPool panda) internal view {
        require(minRaise[pp.baseToken] > 0 && minTradeSize[pp.baseToken] > 0, "PandaFactory: INVALID_BASE");
        require(pp.sqrtPb * PandaMath.FEE_SCALE / pp.sqrtPa >= MIN_SQRTP_MULTIPLE, "PandaFactory: PRICES_TOO_CLOSE");
        require(pp.sqrtPb * PandaMath.FEE_SCALE / pp.sqrtPa <= MAX_SQRTP_MULTIPLE, "PandaFactory: PRICES_TOO_FAR");
        require(pp.sqrtPa > 0, "PandaFactory: INVALID_PRICE");

        uint256 tokensInPool = panda.getTokensInPool(pp.sqrtPa, pp.sqrtPb, totalTokens, poolFees.graduationFee);
        require(tokensInPool <= totalTokens, "PandaFactory: INVALID_TOKENSINPOOL");
        uint256 tokensInPoolShare = tokensInPool * PandaMath.FEE_SCALE / totalTokens;
        require(tokensInPoolShare >= MIN_TOKENSINPOOL_SHARE && tokensInPoolShare <= MAX_TOKENSINPOOL_SHARE, "PandaFactory: INVALID_TOKENSINPOOL");

        uint256 totalRaised = panda.getTotalRaise(pp.sqrtPa, pp.sqrtPb, tokensInPool);
        require(totalRaised >= minRaise[pp.baseToken], "PandaFactory: RAISE_TOO_LOW");
    }

    //Claim incentives after pool graduation
    //Anyone can call, but only once per pool. Incentive is paid to deployer as configured during deployment
    //Incentive is subject to availability (if contract balance is empty, no incentive can be claimed)
    function claimIncentive(address _pandaPool) external override nonReentrant {
        require(isLegitPool(_pandaPool), "PandaFactory: Invalid pool");
        require(poolToIncentiveClaimed[_pandaPool] == false, "PandaFactory: Incentive already claimed");
        require(IPandaPool(_pandaPool).canClaimIncentive(), "PandaFactory: Pool not graduated");
        poolToIncentiveClaimed[_pandaPool] = true;
        TransferHelper.safeTransfer(incentiveToken, IPandaPool(_pandaPool).deployer(), incentiveAmount);
        emit IncentiveClaimed(_pandaPool, incentiveAmount);
    }

    //*********************** VIEW FUNCTIONS *************************************************
    //Predict the address of the PandaPool / PandaToken before it is deployed
    function predictPoolAddress(address implementation, address deployer) external override view returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(deployer, deployerNonce[deployer]));
        return Clones.predictDeterministicAddress(implementation, salt, address(this));
    }

    //Helper to get sqrtP in the correct scale
    function getSqrtP(uint256 scaledPrice) external pure override returns (uint256) {
        return PandaMath.getSqrtP(scaledPrice);
    }

    //Get fee config
    function getPoolFees() external view override returns (PandaFees memory) {
        return poolFees;
    }

    //Return if a PandaPool / PandaToken address is legitimately deployed through this factory
    function isLegitPool(address _pandaPool) public view override returns (bool) {
        return poolToImplementation[_pandaPool] != address(0);
    }

    function allPoolsLength() external view override returns (uint) {
        return allPools.length;
    }

    function allowedImplementationsLength() external view returns (uint) {
        return allowedImplementations.length;
    }

    //*********************** OWNERONLY CONFIGURATIONS ****************************************
    //Set the minimum amount of baseTokens that need to be raised in a PandaPool (to avoid de-minimus pools)
    function setMinRaise(address baseToken, uint256 _minRaise) external override onlyOwner {
        require(baseToken != address(0), "PandaFactory: Invalid token address");
        require(_minRaise > 0, "PandaFactory: Invalid minRaise");
        minRaise[baseToken] = _minRaise;
        emit MinRaiseSet(baseToken, _minRaise);
    }

    //Set the minimum swap size in PandaPool (to avoid dust trades that can cause precision issues in the math)
    function setMinTradeSize(address _baseToken, uint256 _minTradeSize) external override onlyOwner {
        require(_baseToken != address(0), "PandaFactory: Invalid token address");
        require(_minTradeSize > 0, "PandaFactory: Invalid minTradeSize");
        minTradeSize[_baseToken] = _minTradeSize;
        emit MinTradeSizeSet(_baseToken, _minTradeSize);
    }

    //Set the fee recipient address
    function setTreasury(address _treasury) external override onlyOwner {
        require(_treasury != address(0), "PandaFactory: Invalid treasury");
        treasury = _treasury;
        emit TreasurySet(_treasury);
    }

    ///@param _factory: UniswapV2 style dex factory address
    ///@param _initCodeHash: Init code hash of dex, needed to calculate pair addresses
    function setDexFactory(address _factory, bytes32 _initCodeHash) external override onlyOwner {
        require(_factory != address(0), "PandaFactory: Invalid factory");
        dexFactory = _factory;
        initCodeHash = _initCodeHash;
        emit FactorySet(_factory, _initCodeHash);
    }

    //Whitelist a PandaPool implementation to be allowed to be deployed by the factory
    function setAllowedImplementation(address _implementation, bool _allowed) external override onlyOwner {
        require(isImplementationAllowed[_implementation] != _allowed, "PandaFactory: No change needed");
        isImplementationAllowed[_implementation] = _allowed;
        if(_allowed) {
            allowedImplementations.push(_implementation);
        } else {
            uint256 length = allowedImplementations.length;
            for(uint256 i = 0; i < length; ++i) {
                if(allowedImplementations[i] == _implementation) {
                    allowedImplementations[i] = allowedImplementations[length - 1];
                    allowedImplementations.pop();
                    break;
                }
            }
        }
        emit AllowedImplementationSet(_implementation, _allowed);
    }

    //Set the wbera address. Must be set to enable native BERA swaps
    function setWbera(address _wbera) external override onlyOwner {
        require(_wbera != address(0));
        wbera = _wbera;
        emit WberaSet(_wbera);
    }

    //Set incentive to be paid to deployer after pool graduation.
    //Incentive tokens to be distributed must be held by this contract
    function setIncentive(address _incentiveToken, uint256 _incentiveAmount) external override onlyOwner {
        require(address(_incentiveToken) != address(0) || _incentiveAmount == 0, "Invalid incentive token");
        incentiveToken = _incentiveToken;
        incentiveAmount = _incentiveAmount;
        emit IncentiveSet(_incentiveToken, _incentiveAmount);
    }

    //Set fees
    ///param: _buyFee: buyFee in bps. Taken in baseToken terms
    ///param: _sellFee: sellFee in bps. Taken in baseToken terms
    ///param: _graduationFee: graduationFee in bps. Share of total baseToken raised that is taken as fee (remainder is added to LP)
    ///param: _deployerFeeShare: Share of graduationFee that is shared with deployer
    function setPandaPoolFees(uint16 _buyFee, uint16 _sellFee, uint16 _graduationFee, uint16 _deployerFeeShare) external override onlyOwner {
        require(_buyFee <= PandaMath.MAX_FEE, "PandaFactory: Invalid buy fee");
        require(_sellFee <= PandaMath.MAX_FEE, "PandaFactory: Invalid sell fee");
        require(_graduationFee <= PandaMath.MAX_FEE, "PandaFactory: Invalid graduation fee");
        require(_deployerFeeShare <= PandaMath.MAX_DEPLOYER_FEE_SHARE, "PandaFactory: Invalid deployer fee share");

        poolFees = PandaFees(_buyFee, _sellFee, _graduationFee, _deployerFeeShare);

        emit PandaPoolFeesSet(_buyFee, _sellFee, _graduationFee, _deployerFeeShare);
    }


    event PandaDeployed(address indexed pandaPool, address indexed implementation);
    event IncentiveSet(address indexed token, uint256 amount);
    event FactorySet(address indexed factory, bytes32 initCodeHash);
    event WberaSet(address indexed wbera);
    event TreasurySet(address indexed treasury);
    event PandaPoolFeesSet(uint16 buyFee, uint16 sellFee, uint16 graduationFee, uint16 deployerFeeShare);
    event MinRaiseSet(address indexed baseToken, uint256 minEndPrice);
    event MinTradeSizeSet(address indexed baseToken, uint256 minTradeSize);
    event AllowedImplementationSet(address indexed implementation, bool allowed);
    event IncentiveClaimed(address indexed pandaPool, uint256 amount);
}