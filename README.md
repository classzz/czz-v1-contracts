# czz-v1-contracts

v1.6

1.contract address
heco(test-net)：
```
    token-mdx:
    0xD5974f172d6C5ecF5fdF3BC5354cd4824873802D
	token-hczz-new:
    0x5E8fb243AD8B9c10B2211a8C6d0D21231A3f9039

	DogeSwap:
    factory:
    0x0419082bb45f47Fe5c530Ea489e16478819910F3
    router2: 
    0x539A9Fbb81D1D2DC805c698B55C8DF81cbA6b350
	wht:
    0xA9e7417c676F70E5a13c919e78FB1097166568C5

	Mdex:
    factory:
    0x0419082bb45f47Fe5c530Ea489e16478819910F3
    router2: 
    0x539A9Fbb81D1D2DC805c698B55C8DF81cbA6b350
	wht:
    0xA9e7417c676F70E5a13c919e78FB1097166568C5



    routerv1: our-contract
    0x64Dd2D13dA5469a50D747B9CE35a5EcB4865d054
```

ETH ropsten:
	czzuser:
	0x03B4870f6Bb10DDc16f0B6827Aa033D4374678E2
	eczz:
	0x0041a3A63A5844f878B1c08f9d3c28E17f3ce14a

	Uniswap
	factory:
	0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f
	routerv2:
	0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
	weth:
	0xc778417E063141139Fce010982780140Aa0cD5Ab
	

	SushiSwap
	factory:
	0xc35DADB65012eC5796536bD9864eD8773aBc74C4
	routerv2:
	0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506
	weth:
	0xc778417e063141139fce010982780140aa0cd5ab

	routerV1:
	0x6aE86268312A815831A5cfe35187d1f3D2B6dE76
```

BSC:
	bczz:
	0x271b97370aCEED5aFa7d39bBb3dB952CeEc0287D

	Pancakeswap
	factory:
	0x6725F303b657a9451d8BA641348b6761A6CC7a17
	routerv2:
	0xD99D1c33F9fC3444f8101754aBC46c52416550D1
	BNB:
	0x47C77A7959637b7505D15858558e077D601bCA16
	INIT_CODE_PAIR_HASH:
	0xd0d4c4cd0848c93cb4fd1f498d7013ee6bfb25783ea21593d5834f5d250ece66

	routerv1:
	0xb39E84c6AD0574af30fb5f0185ad2d4f2DBa4262


```



ETH test token:

USDT (Tether USD)
0x30c55DF9dFc2fD4cf389908f8A0407515b2e28D8

UNI (Uniswap)
0xB60B0f8a908678330bd6C0bA148e40DE66e2E70a

SUSHI (SushiToken)
0xe5A02cbb143599C737B7EcED3091611af60837a5

WBTC  (Wrapped BTC)
0x7711258921a1d0E37F8bD5B4F78b64595Fe8DB37


HECO test token:

MDX 
0xd5974f172d6c5ecf5fdf3bc5354cd4824873802d

USDT (Tether USD)
0x04f535663110a392a6504839beed34e019fdb4e0

HUNI (Uniswap)
0x4d879F43f6644784248553Ee91A2e4Dfb06fE0BC

HBTC 
0x1D8684e6CdD65383AfFd3D5CF8263fCdA5001F13



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
	 function swap_burn_get_amount(uint amountIn, address[] memory path, address routerAddr) public view returns (uint[] memory amounts)
	 
contact address:
	routerV1

param：
	amountIn  swap token amount
	path:	  token path array
	routerAddr: swap address
```

2.3
```
swapAndBurn:  Token swap for hczztoken and burn hczz for cross mainnet

	function swapAndBurn( uint _amountIn, uint _amountOutMin, address fromToken, uint256 ntype, string memory toToken, address routerAddr, address WethAddr, uint deadline) payable public
	
contact address:
	routerV1

param:
	_amountIn: The amount of token to transfer
	
	_amountOutMin： The minimum amount of tokens to be transferred
	
	
	fromToken： token address  (HT:token-mdx   ETH:token-user)
	
	ntype：   0：eth   1: czz  2: ht
	
	
	toToken:  The address of the token contract to be transferred to

	routerAddr: swap address

	WethAddr: ETH->weth address or HT->wth address
```	
2.4
```
swapAndBurnHt:  heco swap for hczztoken and burn hczz for cross mainnet
	function swapAndBurnHt( uint _amountInMin, uint256 ntype, string memory toToken, address routerAddr, address WethAddr, uint deadline) payable public

swapAndBurnEth: uniswap swap for eczztoken and burn eczz for cross mainnet
	function swapAndBurnEth( uint _amountInMin, uint256 ntype, string memory toToken, address routerAddr, address WethAddr, uint deadline) payable public

swapAndBurnBsc: uniswap swap for bczztoken and burn eczz for cross mainnet
	function swapAndBurnBsc( uint _amountInMin, uint256 ntype, string memory toToken, address routerAddr, address WethAddr, uint deadline) payable public


Token address:
	routerV1

param:
	
	_amountInMin： The minimum amount of tokens to be transferred
	
	ntype：   0：eth   1: czz  2: ht
	
	
	toToken:  The address of the token contract to be transferred to

	routerAddr: swap address

	WethAddr: ETH->weth address or HT->wth address
```

2.5
```
swapToken:   
HT: HRC20 token swap for another HRC20 token 
ETH: ERC20 token swap for another ERC20 token 
	function swapToken(address _to, uint _amountIn, uint256 mid, address toToken, uint256 gas, address routerAddr, address WethAddr, uint deadline) payable public isManager
```

2.6
```
swapTokenForHt:  HRC20 token swap for HT 
	function swapTokenForHt(address _to, uint _amountIn, uint256 mid, uint256 gas, address routerAddr, address WethAddr, uint deadline) payable public isManager 
	
swapTokenForEth:  ERC20 token swap for ETH 
	function swapTokenForETH(address _to, uint _amountIn, uint256 mid, uint256 gas, address routerAddr, address WethAddr, uint deadlines) payable public isManager

swapTokenForBsc:  ERC20 token swap for BSC 
	function swapTokenForBsc(address _to, uint _amountIn, uint256 mid, uint256 gas, address routerAddr, address WethAddr, uint deadlines) payable public isManager
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
	tokenB：   
```