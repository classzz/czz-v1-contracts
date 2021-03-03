# czz-v1-contracts

v1.4

1.contract address
heco(test-net)：
```
    token-mdx:
    0xD5974f172d6C5ecF5fdF3BC5354cd4824873802D
    wht:
    0x11D89c7966db767F2c933E7F1E009CD740b03677
    token-hczz-new:
    0xE30d43717DB115D2f205acCfeCedec67aDfDE089
    factory:
    0x9416ACA496e63594a0a53c1fFd5c15fef64887a9
    router2:  test-swap
    0xb8AbD85C2a6D47CF78491819FfAeFCFD8aC3bFA9
    routerv1-new: our-contract
    0xdf2269de8df11919401A5D6A82a1C590f2181dd1
```

ETH ropsten:
eczz:
0xBa96eE26FEb89BDBc5b9c8b55234c118ebe5E660
czzuser:
0x03B4870f6Bb10DDc16f0B6827Aa033D4374678E2
uniswap_routerv2:
0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
routerV1:
0xE7896c192E9b5AeE64CcD928c6aC0827Cf9e0919

```
ETH：
```
token-user:
0x8D9400e53dDc4C5b2Fb7F115C7f5E4B2C074C42B
weth9:
0x533c65434b96c533ae5A5590516303B8b7A2bB3B
token-eczz:
0xd25b078A0c4B60C52f8f6D5620eeea94284Bef7A
factory:
0x353489De250Ff4698b896A02729675360BF14C1F
router2: test-uniswap
0x5bBd3C4E652011ffE71D832B17c0e8162DeE6985
routerV1 our-contract - eth:
0xBdc797c19bD4c2aDFa286bB57254F4397C4E61e7
```

2.function

2.1
```
approve:     Authorization to swap user tokens
	function approve(address spender, uint256 amount) public virtual override returns (bool) 
	
contact address：
	token-user
	
param：
	spender： swap user address
	amount： allow swap amount
```

2.2
```
swap_burn_get_amount：  get swap token rate  
	 function swap_burn_get_amount(uint amountIn, address[] memory path) public view returns (uint[] memory amounts)
	 
contact address:
	routerV1

param：
	amountIn  swap token amount
	path:	  token path array
```

2.3
```
swapAndBurn:  Token swap for hczztoken and burn hczz for cross mainnet

	function swapAndBurn( uint _amountIn, uint _amountOutMin, address fromToken, uint256 ntype, string memory toToken, uint deadline) payable public
	
contact address:
	routerV1

param:
	_amountIn: The amount of token to transfer
	
	_amountOutMin： The minimum amount of tokens to be transferred
	
	
	fromToken： token address  (HT:token-mdx   ETH:token-user)
	
	ntype：   0：eth   1: czz  2: ht
	
	
	toToken:  The address of the token contract to be transferred to
```	
2.4
```
swapAndBurnHt:  heco swap for hczztoken and burn hczz for cross mainnet
	function swapAndBurnHt( uint _amountInMin, uint256 ntype, string memory toToken, uint deadline) payable public

swapAndBurnEth: uniswap swap for eczztoken and burn eczz for cross mainnet
	function swapAndBurnEth( uint _amountInMin, uint256 ntype, string memory toToken, uint deadline) payable public


Token address:
	routerV1

param:
	
	_amountInMin： The minimum amount of tokens to be transferred
	
	ntype：   0：eth   1: czz  2: ht
	
	
	toToken:  The address of the token contract to be transferred to
```

2.5
```
swapToken:   
HT: HRC20 token swap for another HRC20 token 
ETH: ERC20 token swap for another ERC20 token 
	function swapToken(address _to, uint _amountIn, uint256 mid, address toToken, uint256 gas, uint deadline) payable public isManager
```

2.6
```
swapTokenForHt:  HRC20 token swap for HT 
	function swapTokenForHt(address _to, uint _amountIn, uint256 mid, uint256 gas, uint deadline) payable public isManager 
	
swapTokenForEth:  ERC20 token swap for ETH 
	function swapTokenForETH(address _to, uint _amountIn, uint256 mid, uint256 ga, uint deadlines) payable public isManager
```

2.7
```
swap_burn_get_getReserves: get pair reserves
	function swap_burn_get_getReserves(address factory, address tokenA, address tokenB) public view isManager returns (uint reserveA, uint reserveB)

Toden address:
	routerV1

param：
	factory： 
	tokenA：  
	okenB：   
```