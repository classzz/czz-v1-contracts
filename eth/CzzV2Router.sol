pragma solidity =0.6.6;

//import './SafeMath.sol';
import './IERC20.sol';
import './UniswapV2Library.sol';
import './TransferHelper.sol';
import './IWETH.sol';

abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface ICzzSwap is IERC20 {
    function mint(address _to, uint256 _amount) external;
    function burn(address _account, uint256 _amount) external;
    function transferOwnership(address newOwner) external;
}

interface IUniswapV2Router02 {
    function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

contract CzzV1Router is Ownable {
    using SafeMath for uint;
    address internal CONTRACT_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;  // uniswap router_v2
    address internal WETH_CONTRACT_ADDRESS = 0xc778417E063141139Fce010982780140Aa0cD5Ab;  // WETHADDRESS
    IUniswapV2Router02 internal uniswap;
    address internal factory = 0x353489De250Ff4698b896A02729675360BF14C1F;    //factory
    address public czzToken;
    
    uint constant MIN_SIGNATURES = 1;
    uint minSignatures = 0;
    mapping (address => uint8) private managers;
    mapping (uint => MintItem) private mintItems;
    uint256[] private pendingItems;

    struct MintItem {
        address to;
        uint256 amount;
        uint8 signatureCount;
        mapping (address => uint8) signatures;
    }
   
    event MintItemCreated(
        address indexed from,
        address to,
        uint256 amount,
        uint256 mId
    );
    event MintToken(
        address indexed to,
        uint256 amount,
        uint256 mid,
        uint256 amountIn
    );
    event BurnToken(
        address  indexed to,
        uint256  amount,
        uint256  ntype,
        string   toToken
    );
    event SwapToken(
        address indexed to,
        uint256 inAmount,
        uint256 outAmount,
        string   flag
    );
    event TransferToken(
        address  indexed to,
        uint256  amount
    );

    modifier isManager {
        require(
            msg.sender == owner() || managers[msg.sender] == 1);
        _;
    }
    
    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'UniswapV2Router: EXPIRED');
        _;
    }

    constructor(address _token) public {
        czzToken = _token;
        minSignatures = MIN_SIGNATURES;
        uniswap = IUniswapV2Router02(CONTRACT_ADDRESS);
    }
    
    receive() external payable {}
    
    function addManager(address manager) public onlyOwner{
        managers[manager] = 1;
    }
    
    function removeManager(address manager) public onlyOwner{
        managers[manager] = 0;
    }
    
    function deleteItems(uint256 mid) internal isManager {
        uint8 replace = 0;
        for(uint i = 0; i< pendingItems.length; i++){
            if(1==replace){
                pendingItems[i-1] = pendingItems[i];
            }else if(mid == pendingItems[i]){
                replace = 1;
            }
        } 
        delete pendingItems[pendingItems.length - 1];
        // pendingItems.length--;
        // delete mintItems[mid];
    }
    
    function getItem(uint256 mid) internal view returns (uint8 ret){    //0 ok  1 error
        for(uint i = 0; i< pendingItems.length; i++){
            if(mid == pendingItems[i]){
                return 0;
            }
        } 
        return 1;
    }
    
    function _swap(
        uint amountIn,
        uint amountOutMin,
        address[] memory path,
        address to, uint deadline
        ) internal {
      
        address uniswap_token = CONTRACT_ADDRESS;
        //bytes4 id = bytes4(keccak256(bytes('swapExactTokensForTokens(uint256,uint256,address[],address,uint256)')));
        (bool success, ) = uniswap_token.delegatecall(abi.encodeWithSelector(0x38ed1739, amountIn, amountOutMin,path,to,deadline));
        require(
            success ,'uniswap_token::uniswap_token: uniswap_token failed'
        );
    }
    
    function _swapEthBurn(
        uint amountInMin,
        address[] memory path,
        address to, uint deadline
        ) internal {
      
        address uniswap_token = CONTRACT_ADDRESS;
        //bytes4 id = bytes4(keccak256(bytes('swapExactETHForTokens(uint256,address[],address,uint256)')));
        (bool success, ) = uniswap_token.delegatecall(abi.encodeWithSelector(0x7ff36ab5, amountInMin, path,to,deadline));
        require(
            success ,'uniswap_token::uniswap_token: uniswap_token_eth failed'
        );
    }

    function _swapEthmint(
        uint amountIn,
        uint amountOurMin,
        address[] memory path,
        address to, uint deadline
        ) internal {
      
        address uniswap_token = CONTRACT_ADDRESS;
        // /bytes4 id = bytes4(keccak256(bytes('swapExactTokensForETH(uint256,uint256,address[],address,uint256)')));
        (bool success, ) = uniswap_token.delegatecall(abi.encodeWithSelector(0x18cbafe5, amountIn, amountOurMin, path,to,deadline));
        require(
            success ,'uniswap_token::uniswap_token: uniswap_token_eth failed'
        );
    }
    
    function swap_burn_get_getReserves(address tokenA, address tokenB) public view isManager returns (uint reserveA, uint reserveB){
        return UniswapV2Library.getReserves(factory, tokenA, tokenB);
    }
    
     function swap_burn_get_amount(uint amountIn, address[] memory path) public view returns (uint[] memory amounts){
        return uniswap.getAmountsOut(amountIn,path);
    }
    
    function swap_mint_get_amount(uint amountOut, address[] memory path) public view returns (uint[] memory amounts){
        return uniswap.getAmountsOut(amountOut,path);
    }
    
    function swapToken(address _to, uint _amountIn, uint256 mid, address toToken, uint256 gas, uint deadline) payable public isManager {
        require(address(0) != _to);
        require(_amountIn > 0);
        //require(address(this).balance >= _amountIn);
     
        MintItem storage item = mintItems[mid];
        require(item.signatures[msg.sender]==0, "repeat sign");
        item.to = _to;
        item.amount = _amountIn;
        item.signatures[msg.sender] = 1;
        if(item.signatureCount++ == 0) {
            pendingItems.push(mid);
            emit MintItemCreated(msg.sender, _to, _amountIn, mid);
        }
        if(item.signatureCount >= minSignatures)
        {
            //require(item.to == _to, "mismatch to address");
            //require(item.amount == _amountIn, "mismatch amount");
            if(getItem(mid) != 0){
                return;
            }
            address[] memory path = new address[](3);
            path[0] = czzToken;
            path[1] = WETH_CONTRACT_ADDRESS;
            path[2] = toToken;
            require(_amountIn >= gas, "ROUTER: transfer amount exceeds gas");
            ICzzSwap(czzToken).mint(msg.sender, _amountIn);    // mint to contract address   
            uint[] memory amounts = swap_mint_get_amount(_amountIn, path);
            //_swap(_amountIn, 0, path, _to);
            if(gas > 0){
                address[] memory path1 = new address[](2);
                path1[0] = czzToken;
                path1[1] = WETH_CONTRACT_ADDRESS;
                 _swapEthmint(gas, 0, path1, msg.sender, deadline);
            }
            _swap(_amountIn-gas, 0, path, _to, deadline);
            emit MintToken(_to, amounts[amounts.length - 1],mid,_amountIn-gas);
            deleteItems(mid);
            return;
        }
        // MintItem item;
        mintItems[mid] = item;
    }
    
    
    function swapTokenForEth(address _to, uint _amountIn, uint256 mid, uint256 gas, uint deadline) payable public isManager {
        require(address(0) != _to);
        require(_amountIn > 0);
        //require(address(this).balance >= _amountIn);
     
        MintItem storage item = mintItems[mid];
        require(item.signatures[msg.sender]==0, "repeat sign");
        item.to = _to;
        item.amount = _amountIn;
        item.signatures[msg.sender] = 1;
        if(item.signatureCount++ == 0) {
            pendingItems.push(mid);
            emit MintItemCreated(msg.sender, _to, _amountIn, mid);
        }
        if(item.signatureCount >= minSignatures)
        {
            //require(item.to == _to, "mismatch to address");
            //require(item.amount == _amountIn, "mismatch amount");
            if(getItem(mid) != 0){
                return;
            }
            address[] memory path = new address[](2);
            path[0] = czzToken;
            path[1] = WETH_CONTRACT_ADDRESS;
            require(_amountIn >= gas, "ROUTER: transfer amount exceeds gas");
            ICzzSwap(czzToken).mint(msg.sender, _amountIn);    // mint to contract address   
            uint[] memory amounts = swap_mint_get_amount(_amountIn, path);
            if(gas > 0){
                _swapEthmint(gas, 0, path, msg.sender, deadline);
            }
            _swapEthmint(_amountIn-gas, 0, path, _to, deadline);
            emit MintToken(_to, amounts[amounts.length - 1],mid,_amountIn-gas);
            deleteItems(mid);
            return;
        }
        // MintItem item;
        mintItems[mid] = item;
    }
    
    
    function swapAndBurn( uint _amountIn, uint _amountOutMin, address fromToken, uint256 ntype, string memory toToken, uint deadline) payable public
    {
        // require(msg.value > 0);
        //address czzToken1 = 0x5bdA60F4Adb9090b138f77165fe38375F68834af;
        address[] memory path = new address[](3);
        path[0] = fromToken;
        path[1] = WETH_CONTRACT_ADDRESS;
        path[2] = czzToken;
        uint[] memory amounts = swap_burn_get_amount(_amountIn, path);
        _swap(_amountIn, _amountOutMin, path, msg.sender, deadline);
        if(ntype != 1){
            ICzzSwap(czzToken).burn(msg.sender, amounts[amounts.length - 1]);
            emit BurnToken(msg.sender, amounts[amounts.length - 1], ntype, toToken);
        }
      
    }
    
    function swapAndBurnEth( uint _amountInMin, uint256 ntype, string memory toToken, uint deadline) payable public
    {
        require(msg.value > 0);
        address[] memory path = new address[](2);
        path[0] = address(WETH_CONTRACT_ADDRESS);
        path[1] = address(czzToken);
        uint[] memory amounts = swap_burn_get_amount(msg.value, path);
        _swapEthBurn(_amountInMin, path, msg.sender, deadline);
        if(ntype != 1){
            ICzzSwap(czzToken).burn(msg.sender, amounts[amounts.length - 1]);
            emit BurnToken(msg.sender, amounts[amounts.length - 1], ntype, toToken);
        }
      
    }
    
    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair   token -> weth -> token 
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to, uint gas) internal virtual {
        require(path[1] == WETH_CONTRACT_ADDRESS, 'Uniswap Router: INVALID_PATH');
        (address input, address output) = (path[0], path[1]);
        (address token0,) = UniswapV2Library.sortTokens(input, output);
        IUniswapV2Pair pair = IUniswapV2Pair(UniswapV2Library.pairFor(factory, input, output));
        uint amountInput;
        uint amountOutput;
        { // scope to avoid stack too deep errors
            (uint reserve0, uint reserve1,) = pair.getReserves();
            (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
            amountInput = IERC20(input).balanceOf(address(pair)).sub(reserveInput);
            amountOutput = UniswapV2Library.getAmountOut(amountInput, reserveInput, reserveOutput);
        }
        (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
        address to = UniswapV2Library.pairFor(factory, output, path[2]);
        pair.swap(amount0Out, amount1Out, address(this), new bytes(0));
        
        uint amountOut = IERC20(WETH_CONTRACT_ADDRESS).balanceOf(address(this));
        require(amountOut > gas, 'Uniswap Router: INSUFFICIENT_GAS');
        IWETH(WETH_CONTRACT_ADDRESS).withdraw(gas);
        TransferHelper.safeTransferFrom(WETH_CONTRACT_ADDRESS, address(this), to, amountOut-gas);
        
        (input, output) = (path[1], path[2]);
        (token0,) = UniswapV2Library.sortTokens(input, output);
        pair = IUniswapV2Pair(UniswapV2Library.pairFor(factory, input, output));
        { // scope to avoid stack too deep errors
            (uint reserve0, uint reserve1,) = pair.getReserves();
            (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
            amountInput = IERC20(input).balanceOf(address(pair)).sub(reserveInput);
            amountOutput = UniswapV2Library.getAmountOut(amountInput, reserveInput, reserveOutput);
        }
        (amount0Out, amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
        
        pair.swap(amount0Out, amount1Out, _to, new bytes(0));
    }
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint gas,
        uint deadline
    ) external virtual ensure(deadline) {
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amountIn
        );
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to, gas);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint gas,
        uint deadline
    )
        external
        virtual
        ensure(deadline)
    {
        require(path[1] == WETH_CONTRACT_ADDRESS, 'Uniswap Router: INVALID_PATH');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amountIn
        );
        
        (address input, address output) = (path[0], path[1]);
        (address token0,) = UniswapV2Library.sortTokens(input, output);
        IUniswapV2Pair pair = IUniswapV2Pair(UniswapV2Library.pairFor(factory, input, output));
        uint amountInput;
        uint amountOutput;
        { // scope to avoid stack too deep errors
            (uint reserve0, uint reserve1,) = pair.getReserves();
            (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
            amountInput = IERC20(input).balanceOf(address(pair)).sub(reserveInput);
            amountOutput = UniswapV2Library.getAmountOut(amountInput, reserveInput, reserveOutput);
        }
        (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
        pair.swap(amount0Out, amount1Out, address(this), new bytes(0));
        
        uint amountOut = IERC20(WETH_CONTRACT_ADDRESS).balanceOf(address(this));
        require(amountOut >= amountOutMin, 'Uniswap Router: INSUFFICIENT_OUTPUT_AMOUNT');
        require(amountOut > gas, 'Uniswap Router: INSUFFICIENT_GAS');
        IWETH(WETH_CONTRACT_ADDRESS).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut-gas);
    }
    
    function setMinSignatures(uint8 value) public isManager {
        minSignatures = value;
    }

    function getMinSignatures() public view isManager returns(uint256){
        return minSignatures;
    }

    function setSwapAddress(address addr) public isManager {
        CONTRACT_ADDRESS = addr;
    }

    function getSwapAddress() public view isManager returns(address ){
        return CONTRACT_ADDRESS ;
    }

    function setWTonkenAddress(address addr) public isManager {
        WETH_CONTRACT_ADDRESS = addr;
    }

    function getWTonkenAddress() public view isManager returns(address ){
        return WETH_CONTRACT_ADDRESS ;
    }
    
     function setFactoryAddress(address addr) public isManager {
        factory = addr;
    }

    function getFactoryAddress() public view isManager returns(address ){
        return factory ;
    }
    
    function burn( uint _amountIn, uint256 ntype, string memory toToken) payable public isManager
    {
        address czzToken1 = czzToken;
        ICzzSwap(czzToken1).burn(msg.sender, _amountIn);
        emit BurnToken(msg.sender, _amountIn, ntype, toToken);
    }

    function mint(address fromToken, uint256 _amountIn)  payable public isManager 
    {
        address czzToken1 = czzToken;
        ICzzSwap(czzToken1).mint(fromToken, _amountIn);
        emit MintToken(fromToken, 0, 0,_amountIn);
    }
}
