# IInfraredUpgradeable
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/interfaces/IInfraredUpgradeable.sol)

**Inherits:**
IAccessControl


## Functions
### KEEPER_ROLE

Access control for keeper role


```solidity
function KEEPER_ROLE() external view returns (bytes32);
```

### GOVERNANCE_ROLE

Access control for governance role


```solidity
function GOVERNANCE_ROLE() external view returns (bytes32);
```

### infrared

Infrared coordinator contract


```solidity
function infrared() external view returns (IInfrared);
```

