# Solidity API

## USDT

### constructor

```solidity
constructor() public
```

## VNSTProxy

VNST Stable Coin and VNST AMM

### usdt

```solidity
contract IERC20 usdt
```

USDT (u)
VNST (v)
R-center = v / u
Q-Support above
Q-Support bellow
R-Support above
R-Support bellow
k constant = u * v
operation_pool

### PAUSER_ROLE

```solidity
bytes32 PAUSER_ROLE
```

### usdt_pool

```solidity
uint256 usdt_pool
```

### vnst_pool

```solidity
uint256 vnst_pool
```

### r_center

```solidity
uint256 r_center
```

### q_support_above

```solidity
uint256 q_support_above
```

### q_support_bellow

```solidity
uint256 q_support_bellow
```

### r_support_above

```solidity
uint256 r_support_above
```

### r_support_bellow

```solidity
uint256 r_support_bellow
```

### k

```solidity
uint256 k
```

### operation_pool

```solidity
uint256 operation_pool
```

### initialize

```solidity
function initialize(address address_usdt) public
```

### _authorizeUpgrade

```solidity
function _authorizeUpgrade(address newImplementation) internal
```

_Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
{upgradeTo} and {upgradeToAndCall}.

Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.

```solidity
function _authorizeUpgrade(address) internal override onlyOwner {}
```_

### pause

```solidity
function pause() external
```

### unpause

```solidity
function unpause() external
```

### emergencyWithdraw

```solidity
function emergencyWithdraw() external
```

_transfer the token from the address of this contract
to address of the owner_

### withdrawUSDT

```solidity
function withdrawUSDT(uint256 _amount) external
```

### _beforeTokenTransfer

```solidity
function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual
```

## VNST

### version

```solidity
function version() external pure returns (string)
```

### EMint

```solidity
event EMint(address address_mint, uint256 amount_usdt_in, uint256 amount_vnsc_out, uint256 created_at)
```

Event

### EBurn

```solidity
event EBurn(address address_withdrawl, uint256 vnsc_in, uint256 usdt_out, uint256 created_at)
```

### reBootPool

```solidity
function reBootPool(uint256 _usdt_pool, uint256 _vnst_pool, uint256 _q_support_above, uint256 _q_support_bellow, uint256 _r_support_above, uint256 _r_support_bellow) external
```

### mint

```solidity
function mint(uint256 amount_usdt) external
```

### burn

```solidity
function burn(uint256 amount_vnst) external
```

