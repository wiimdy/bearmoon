# DataTypes
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/utils/DataTypes.sol)


## State Variables
### NATIVE_ASSET
*The address of the native asset as of EIP-7528.*


```solidity
address public constant NATIVE_ASSET =
    0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
```


## Structs
### Validator

```solidity
struct Validator {
    bytes pubKey;
    address coinbase;
}
```

### ValidatorSet

```solidity
struct ValidatorSet {
    EnumerableSet.Bytes32Set keys;
    mapping(bytes32 => Validator) map;
}
```

### Token

```solidity
struct Token {
    address tokenAddress;
    uint256 amount;
}
```

## Enums
### ValidatorSetAction

```solidity
enum ValidatorSetAction {
    Add,
    Remove,
    Replace
}
```

### RewardContract

```solidity
enum RewardContract {
    Distribution,
    Rewards
}
```

