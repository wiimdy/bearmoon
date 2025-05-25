// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {IPandaStructs} from "./IPandaStructs.sol";

interface IPandaFactory is IPandaStructs {

    function treasury() external view returns (address);
    function wbera() external view returns (address);
    function minRaise(address) external view returns (uint256);
    function minTradeSize(address) external view returns (uint256);

    function MIN_TOKENSINPOOL_SHARE() external view returns (uint256);
    function MAX_TOKENSINPOOL_SHARE() external view returns (uint256);
    function MIN_SQRTP_MULTIPLE() external view returns (uint256);
    function MAX_SQRTP_MULTIPLE() external view returns (uint256);

    function TOKEN_SUPPLY() external view returns (uint256);
    function DEPLOYER_MAX_BPS() external view returns (uint16);

    function dexFactory() external view returns (address);
    function initCodeHash() external view returns (bytes32);

    function isImplementationAllowed(address _implementation) external view returns (bool);
    function allowedImplementations(uint256 index) external view returns (address);

    function incentiveToken() external view returns (address);
    function incentiveAmount() external view returns (uint256);

    function poolToIncentiveClaimed(address) external view returns (bool);
    function deployerNonce(address) external view returns (uint256);

    function allPools(uint256 index) external view returns (address);
    function poolToImplementation(address) external view returns (address);


    function deployPandaToken(
        address implementation,
        IPandaFactory.PandaPoolParams calldata pp,  //baseToken, sqrtPa, sqrtPb, vestingPeriod
        string calldata name,
        string calldata symbol,
        uint16 deployerSupplyBps
    ) external returns (address);

    function deployPandaTokenWithBera(
        address implementation,
        IPandaFactory.PandaPoolParams calldata pp,  //baseToken, sqrtPa, sqrtPb, vestingPeriod
        string calldata name,
        string calldata symbol,
        uint16 deployerSupplyBps
    ) external payable returns (address);

    function deployPandaPool(
        address implementation,
        IPandaFactory.PandaPoolParams calldata pp,  //baseToken, sqrtPa, sqrtPb, vestingPeriod
        uint256 totalTokens,
        address pandaToken,
        bytes calldata data
    ) external returns (address);

    function claimIncentive(address _pandaPool) external;

    function predictPoolAddress(address _implementation, address _deployer) external view returns (address);
    function getSqrtP(uint256 scaledPrice) external view returns (uint256);
    function getPoolFees() external view returns (PandaFees memory);
    function isLegitPool(address _pandaPool) external view returns (bool);
    function allPoolsLength() external view returns (uint256);
    function allowedImplementationsLength() external view returns (uint256);

    function setMinRaise(address _token, uint256 _minRaise) external;
    function setMinTradeSize(address _token, uint256 _minTradeSize) external;
    function setTreasury(address _treasury) external;
    function setPandaPoolFees(uint16 _buyFee, uint16 _sellFee, uint16 _graduationFee, uint16 _deployerFeeShare) external;
    function setDexFactory(address _dexFactory, bytes32 _initCodeHash) external;
    function setAllowedImplementation(address _implementation, bool _allowed) external;
    function setWbera(address _wbera) external;
    function setIncentive(address _incentiveToken, uint256 _incentiveAmount) external;






}