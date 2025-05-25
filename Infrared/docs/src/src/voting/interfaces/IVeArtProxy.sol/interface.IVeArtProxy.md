# IVeArtProxy
[Git Source](https://github.com-infrared/infrared-dao/infrared-mono-repo/blob/1a33f96723b9edc4ba92aebe8d11b7108d5353c3/src/voting/interfaces/IVeArtProxy.sol)


## Functions
### tokenURI

Generate a SVG based on veNFT metadata


```solidity
function tokenURI(uint256 _tokenId)
    external
    view
    returns (string memory output);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|Unique veNFT identifier|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`output`|`string`|SVG metadata as HTML tag|


### lineArtPathsOnly

Generate only the foreground <path> elements of the line art for an NFT (excluding SVG header), for flexibility purposes.


```solidity
function lineArtPathsOnly(uint256 _tokenId)
    external
    view
    returns (bytes memory output);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|Unique veNFT identifier|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`output`|`bytes`|Encoded output of generateShape()|


### generateConfig

Generate the master art config metadata for a veNFT


```solidity
function generateConfig(uint256 _tokenId)
    external
    view
    returns (Config memory cfg);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|Unique veNFT identifier|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`cfg`|`Config`|Config struct|


### twoStripes

Generate the points for two stripe lines based on the config generated for a veNFT


```solidity
function twoStripes(Config memory cfg, int256 l)
    external
    pure
    returns (Point[100] memory Line);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`cfg`|`Config`|Master art config metadata of a veNFT|
|`l`|`int256`|Number of line drawn|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`Line`|`Point[100]`|(x, y) coordinates of the drawn stripes|


### circles

Generate the points for circles based on the config generated for a veNFT


```solidity
function circles(Config memory cfg, int256 l)
    external
    pure
    returns (Point[100] memory Line);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`cfg`|`Config`|Master art config metadata of a veNFT|
|`l`|`int256`|Number of circles drawn|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`Line`|`Point[100]`|(x, y) coordinates of the drawn circles|


### interlockingCircles

Generate the points for interlocking circles based on the config generated for a veNFT


```solidity
function interlockingCircles(Config memory cfg, int256 l)
    external
    pure
    returns (Point[100] memory Line);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`cfg`|`Config`|Master art config metadata of a veNFT|
|`l`|`int256`|Number of interlocking circles drawn|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`Line`|`Point[100]`|(x, y) coordinates of the drawn interlocking circles|


### corners

Generate the points for corners based on the config generated for a veNFT


```solidity
function corners(Config memory cfg, int256 l)
    external
    pure
    returns (Point[100] memory Line);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`cfg`|`Config`|Master art config metadata of a veNFT|
|`l`|`int256`|Number of corners drawn|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`Line`|`Point[100]`|(x, y) coordinates of the drawn corners|


### curves

Generate the points for a curve based on the config generated for a veNFT


```solidity
function curves(Config memory cfg, int256 l)
    external
    pure
    returns (Point[100] memory Line);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`cfg`|`Config`|Master art config metadata of a veNFT|
|`l`|`int256`|Number of curve drawn|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`Line`|`Point[100]`|(x, y) coordinates of the drawn curve|


### spiral

Generate the points for a spiral based on the config generated for a veNFT


```solidity
function spiral(Config memory cfg, int256 l)
    external
    pure
    returns (Point[100] memory Line);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`cfg`|`Config`|Master art config metadata of a veNFT|
|`l`|`int256`|Number of spiral drawn|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`Line`|`Point[100]`|(x, y) coordinates of the drawn spiral|


### explosion

Generate the points for an explosion based on the config generated for a veNFT


```solidity
function explosion(Config memory cfg, int256 l)
    external
    pure
    returns (Point[100] memory Line);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`cfg`|`Config`|Master art config metadata of a veNFT|
|`l`|`int256`|Number of explosion drawn|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`Line`|`Point[100]`|(x, y) coordinates of the drawn explosion|


### wormhole

Generate the points for a wormhole based on the config generated for a veNFT


```solidity
function wormhole(Config memory cfg, int256 l)
    external
    pure
    returns (Point[100] memory Line);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`cfg`|`Config`|Master art config metadata of a veNFT|
|`l`|`int256`|Number of wormhole drawn|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`Line`|`Point[100]`|(x, y) coordinates of the drawn wormhole|


## Structs
### Config
*Art configuration*


```solidity
struct Config {
    int256 _tokenId;
    int256 _balanceOf;
    int256 _lockedEnd;
    int256 _lockedAmount;
    int256 shape;
    uint256 palette;
    int256 maxLines;
    int256 dash;
    int256 seed1;
    int256 seed2;
    int256 seed3;
}
```

### lineConfig
*Individual line art path variables.*


```solidity
struct lineConfig {
    bytes8 color;
    uint256 stroke;
    uint256 offset;
    uint256 offsetHalf;
    uint256 offsetDashSum;
    uint256 pathLength;
}
```

### Point
*Represents an (x,y) coordinate in a line.*


```solidity
struct Point {
    int256 x;
    int256 y;
}
```

