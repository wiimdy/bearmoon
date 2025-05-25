# SafeCastLibrary
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/voting/libraries/SafeCastLibrary.sol)

**Author:**
velodrome.finance

Safely convert unsigned and signed integers without overflow / underflow


## Functions
### toInt128

*Safely convert uint256 to int128*


```solidity
function toInt128(uint256 value) internal pure returns (int128);
```

### toUint256

*Safely convert int128 to uint256*


```solidity
function toUint256(int128 value) internal pure returns (uint256);
```

## Errors
### SafeCastOverflow

```solidity
error SafeCastOverflow();
```

### SafeCastUnderflow

```solidity
error SafeCastUnderflow();
```

