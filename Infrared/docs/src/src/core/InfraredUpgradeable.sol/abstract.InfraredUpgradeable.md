# InfraredUpgradeable
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/core/InfraredUpgradeable.sol)

**Inherits:**
UUPSUpgradeable, AccessControlUpgradeable, [IInfraredUpgradeable](/src/interfaces/IInfraredUpgradeable.sol/interface.IInfraredUpgradeable.md)

This contract provides base upgradeability functionality for Infrared.


## State Variables
### KEEPER_ROLE

```solidity
bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
```


### GOVERNANCE_ROLE

```solidity
bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
```


### infrared
Infrared coordinator contract


```solidity
IInfrared public immutable infrared;
```


## Functions
### onlyKeeper


```solidity
modifier onlyKeeper();
```

### onlyGovernor


```solidity
modifier onlyGovernor();
```

### onlyInfrared


```solidity
modifier onlyInfrared();
```

### whenInitialized


```solidity
modifier whenInitialized();
```

### constructor


```solidity
constructor(address _infrared);
```

### _checkRole

*Overrides to check role on infrared contract*


```solidity
function _checkRole(bytes32 role, address account)
    internal
    view
    virtual
    override;
```

### __InfraredUpgradeable_init


```solidity
function __InfraredUpgradeable_init() internal onlyInitializing;
```

### _authorizeUpgrade


```solidity
function _authorizeUpgrade(address newImplementation)
    internal
    override
    onlyGovernor;
```

### currentImplementation


```solidity
function currentImplementation() external view returns (address);
```

