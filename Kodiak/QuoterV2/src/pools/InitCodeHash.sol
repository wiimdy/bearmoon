pragma solidity >=0.5.0 <0.8.0;

library InitCode {

    //Make sure to calculate the init_code_hash and enter it here
    //First, create a pool using

    //Before deploying the routers, you will need to run the CreatePool and CreateV2Pair scripts in kodiak-core
    //in order to initialize the first pairs, and get the "initCode" from the broadcast files
    //With the initCode, run keccak256 on it to get the new INIT_CODE_HASH

    bytes32 internal constant V2_INIT_CODE_HASH = 0x190cc7bdd70507a793b76d7bc2bf03e1866989ca7881812e0e1947b23e099534;

    bytes32 internal constant V3_INIT_CODE_HASH = 0xd8e2091bc519b509176fc39aeb148cc8444418d3ce260820edc44e806c2c2339;
}
