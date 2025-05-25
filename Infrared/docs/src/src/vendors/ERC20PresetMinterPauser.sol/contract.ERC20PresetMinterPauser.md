# ERC20PresetMinterPauser
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/vendors/ERC20PresetMinterPauser.sol)

**Inherits:**
Context, AccessControlEnumerable, ERC20Burnable, ERC20Pausable

*{ERC20} token, including:
- ability for holders to burn (destroy) their tokens
- a minter role that allows for token minting (creation)
- a pauser role that allows to stop all token transfers
This contract uses {AccessControl} to lock permissioned functions using the
different roles - head to its documentation for details.
The account that deploys the contract will be granted the minter and pauser
roles, as well as the default admin role, which will let it grant both minter
and pauser roles to other accounts.
_Deprecated in favor of https://wizard.openzeppelin.com/[Contracts Wizard]._*


## State Variables
### MINTER_ROLE

```solidity
bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
```


### PAUSER_ROLE

```solidity
bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
```


## Functions
### constructor

*Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE` and `PAUSER_ROLE` to the
account that deploys the contract.
See [ERC20-constructor](/src/core/IBGT.sol/contract.IBGT.md#constructor).*


```solidity
constructor(string memory name, string memory symbol) ERC20(name, symbol);
```

### mint

*Creates `amount` new tokens for `to`.
See [ERC20-_mint](/src/voting/VotingEscrow.sol/contract.VotingEscrow.md#_mint).
Requirements:
- the caller must have the `MINTER_ROLE`.*


```solidity
function mint(address to, uint256 amount) public virtual;
```

### pause

*Pauses all token transfers.
See {ERC20Pausable} and {Pausable-_pause}.
Requirements:
- the caller must have the `PAUSER_ROLE`.*


```solidity
function pause() public virtual;
```

### unpause

*Unpauses all token transfers.
See {ERC20Pausable} and {Pausable-_unpause}.
Requirements:
- the caller must have the `PAUSER_ROLE`.*


```solidity
function unpause() public virtual;
```

### _update


```solidity
function _update(address from, address to, uint256 value)
    internal
    virtual
    override(ERC20, ERC20Pausable)
    whenNotPaused;
```

