pragma solidity =0.8.19;

import {LibClone} from "lib/solady/src/utils/LibClone.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IFarm} from "./interfaces/IFarm.sol";
import {IXKdkToken} from "src/tokens/interfaces/tokens/IXKdkToken.sol";

contract FarmFactory is Ownable {

    //List of allowed implementations of Farms. Multiple canonical implementations can be allowed
    mapping(address => bool) public isImplementationAllowed;
    address[] public allowedImplementations;
    IXKdkToken public xkdk;

    //Deployed farms information
    address[] public allFarms; //list of all farms
    mapping(address => address) public farmToImplementation; //map farm to canonical implementation

    //*********************** CONSTRUCTOR ***************************************************
    constructor() {}

    //*********************** EXTERNAL FUNCTIONS *********************************************
    function deployFarm(
        address _implementation,
        address _stakingToken,
        address[] memory _rewardTokens,
        address[] memory _rewardManagers,
        uint256[] memory _rewardRates,
        bytes calldata _data
    ) external returns(address) {
        require(isImplementationAllowed[_implementation], "FarmFactory: Implementation not allowed");
        require(_stakingToken != address(0), "FarmFactory: Staking token cannot be zero address");
        address farm = LibClone.clone(_implementation);
        IFarm(farm).initialize(msg.sender, _stakingToken, _rewardTokens, _rewardManagers, _rewardRates, _data);

        if(address(xkdk) != address(0) && xkdk.isWhitelister(address(this))) {
            xkdk.updateTransferWhitelist(farm, true);
        }

        farmToImplementation[farm] = _implementation;
        allFarms.push(farm);
        emit FarmDeployed(farm, _implementation);

        return farm;
    }

    //*********************** VIEW FUNCTIONS *************************************************
    //Return if a farm address is legitimately deployed through this factory
    function isLegitFarm(address _farm) public view returns (bool) {
        return farmToImplementation[_farm] != address(0);
    }

    function allFarmsLength() external view returns (uint) {
        return allFarms.length;
    }

    function allowedImplementationsLength() external view returns (uint) {
        return allowedImplementations.length;
    }

    //*********************** OWNERONLY CONFIGURATIONS ****************************************
    function setXKdk(address _xkdk) external onlyOwner {
        require(address(xkdk) == address(0), "FarmFactory: XKdk already set");
        require(_xkdk != address(0), "FarmFactory: Cannot set zero address");
        require(IXKdkToken(_xkdk).isWhitelister(address(this)), "FarmFactory: FarmFactory should be whitelister");
        xkdk = IXKdkToken(_xkdk);
        emit XKdkSet(_xkdk);
    }

    //Whitelist a farm implementation to be allowed to be deployed by the factory
    function setAllowedImplementation(address _implementation, bool _allowed) external onlyOwner {
        require(isImplementationAllowed[_implementation] != _allowed, "FarmFactory: No change needed");
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

    event FarmDeployed(address indexed farm, address indexed implementation);
    event AllowedImplementationSet(address indexed implementation, bool allowed);
    event XKdkSet(address indexed xkdk);
}