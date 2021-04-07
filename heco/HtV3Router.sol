pragma solidity =0.6.6;

import './SafeMath.sol';
import './IERC20.sol';
import './IMdexFactory.sol';


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
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    
}

contract HtV1Router is Ownable {
    using SafeMath for uint;
    //address internal CONTRACT_ADDRESS = 0xb8AbD85C2a6D47CF78491819FfAeFCFD8aC3bFA9;  // uniswap router_v2  ht
    //address internal factory = 0x9416ACA496e63594a0a53c1fFd5c15fef64887a9;    //factory
    //address internal WETH_CONTRACT_ADDRESS = 0x11D89c7966db767F2c933E7F1E009CD740b03677;  // WETHADDRESS
    //IUniswapV2Router02 internal uniswap;
    
    address internal czzToken;
    
    uint constant MIN_SIGNATURES = 1;
    uint minSignatures = 0;
    mapping (address => uint8) private managers;
    mapping (uint => MintItem) private mintItems;
    uint256[] private pendingItems;
    struct KeyFlag { address key; bool deleted; }

    struct MintItem {
        address to;
        uint256 amount;
        uint8 signatureCount;
        mapping (address => uint8) signatures;
        KeyFlag[] keys;
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

    constructor(address _token) public {
        czzToken = _token;
        minSignatures = MIN_SIGNATURES;
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
    
    function insert_signature(MintItem storage item, address key) internal returns (bool replaced)
    {
        if (item.signatures[key] == 1)
            return false;
        else
        {
            KeyFlag memory key1;
            item.signatures[key] = 1;
            key1.key = key;
            item.keys.push(key1);
            return true;
        }
    }
    
    function remove_signature_all(MintItem storage self) internal
    {
        for(uint256 i = 0; i < self.keys.length; i++){
            address key = self.keys[i].key;
            delete self.signatures[key];
        }
    }

    function _swapMint(
        uint amountIn,
        uint amountOutMin,
        address[] memory path,
        address to,
        address routerAddr,
        uint deadline
        ) internal {

        IERC20(path[0]).approve(routerAddr,amountIn);
        IUniswapV2Router02(routerAddr).swapExactTokensForTokens(amountIn, amountOutMin,path,to,deadline);

    }
    
    function _swap(
        uint amountIn,
        uint amountOutMin,
        address[] memory path,
        address to,
        address routerAddr,
        uint deadline
        ) internal {
      
        address uniswap_token = routerAddr;  //CONTRACT_ADDRESS
        
        //bytes4 id = bytes4(keccak256(bytes('swapExactTokensForTokens(uint256,uint256,address[],address,uint256)')));
        (bool success, ) = uniswap_token.delegatecall(abi.encodeWithSelector(0x38ed1739, amountIn, amountOutMin,path,to,deadline));
        require(
            success ,'uniswap_token::uniswap_token: uniswap_token failed'
        );
    }
    
    function _swapBurn(
        uint amountIn,
        uint amountOutMin,
        address[] memory path,
        address to,
        address routerAddr,
        uint deadline
        ) internal {
      
        address uniswap_token = routerAddr;  //CONTRACT_ADDRESS
        
        //bytes4 id = bytes4(keccak256(bytes('swapExactTokensForTokens(uint256,uint256,address[],address,uint256)')));
        (bool success, ) = uniswap_token.delegatecall(abi.encodeWithSelector(0x38ed1739, amountIn, amountOutMin,path,to,deadline));
        require(
            success ,'uniswap_token::_swapBurn: uniswap_token failed'
        );
    }
    
    function _swapHtBurn(
        uint amountInMin,
        address[] memory path,
        address to, 
        address routerAddr,
        uint deadline
        ) internal {
      
        address uniswap_token = routerAddr;  //CONTRACT_ADDRESS
        //bytes4 id = bytes4(keccak256(bytes('swapExactETHForTokens(uint256,address[],address,uint256)')));
        (bool success, ) = uniswap_token.delegatecall(abi.encodeWithSelector(0x7ff36ab5, amountInMin, path,to,deadline));
        require(
            success ,'uniswap_token::uniswap_token: uniswap_token_eth failed'
        );
    }
    
    function _swapHtMint(
        uint amountIn,
        uint amountOutMin,
        address[] memory path,
        address to, 
        address routerAddr,
        uint deadline
        ) internal {
      
        IERC20(path[0]).approve(routerAddr,amountIn);
        IUniswapV2Router02(routerAddr).swapExactTokensForETH(amountIn, amountOutMin,path,to,deadline);
    }
    
    function swap_burn_get_getReserves(address factory, address tokenA, address tokenB) public view isManager returns (uint reserveA, uint reserveB){
        require(address(0) != factory);
        return  IMdexFactory(factory).getReserves(tokenA, tokenB);
    }
    
    function swap_burn_get_amount(uint amountIn, address[] memory path,address routerAddr) public view returns (uint[] memory amounts){
        require(address(0) != routerAddr); 
        return IUniswapV2Router02(routerAddr).getAmountsOut(amountIn,path);
    }
    
    function swap_mint_get_amount(uint amountOut, address[] memory path, address routerAddr) public view returns (uint[] memory amounts){
        require(address(0) != routerAddr); 
        return IUniswapV2Router02(routerAddr).getAmountsOut(amountOut,path);
    }
    
    function swapToken(address _to, uint _amountIn, uint256 mid, address toToken, uint256 gas, address routerAddr, address WethAddr, uint deadline) payable public isManager {
        require(address(0) != _to);
        require(address(0) != routerAddr); 
        require(address(0) != WethAddr); 
        require(_amountIn > 0);
        //require(address(this).balance >= _amountIn);
     
        MintItem storage item = mintItems[mid];
        require(insert_signature(item, msg.sender), "repeat sign");
        item.to = _to;
        item.amount = _amountIn;
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
            path[1] = WethAddr;
            path[2] = toToken;
            require(_amountIn >= gas, "ROUTER: transfer amount exceeds gas");
            ICzzSwap(czzToken).mint(address(this), _amountIn);    // mint to contract address   
            uint[] memory amounts = swap_mint_get_amount(_amountIn, path, routerAddr);
            //_swap(_amountIn, 0, path, _to);
            if(gas > 0){
                address[] memory path1 = new address[](2);
                path1[0] = czzToken;
                path1[1] = WethAddr;
                 _swapHtMint(gas, 0, path1, msg.sender, routerAddr, deadline);
            }
            _swapMint(_amountIn-gas, 0, path, _to, routerAddr, deadline);
            emit MintToken(_to, amounts[amounts.length - 1],mid,_amountIn);
            remove_signature_all(item);
            deleteItems(mid);
            delete mintItems[mid];
            return;
        }
        // MintItem item;
        mintItems[mid] = item;
    }
    
    
    function swapTokenForHt(address _to, uint _amountIn, uint256 mid, uint256 gas, address routerAddr, address WethAddr, uint deadline) payable public isManager {
        require(address(0) != _to);
        require(address(0) != routerAddr); 
        require(address(0) != WethAddr); 
        require(_amountIn > 0);
        //require(address(this).balance >= _amountIn);
     
        MintItem storage item = mintItems[mid];
        require(insert_signature(item, msg.sender), "repeat sign");
        item.to = _to;
        item.amount = _amountIn;
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
            path[1] = WethAddr;
            require(_amountIn >= gas, "ROUTER: transfer amount exceeds gas");
            ICzzSwap(czzToken).mint(address(this), _amountIn);    // mint to contract address   
            uint[] memory amounts = swap_mint_get_amount(_amountIn, path, routerAddr);
            if(gas > 0){
                _swapHtMint(gas, 0, path, msg.sender, routerAddr, deadline);
            }
            _swapHtMint(_amountIn-gas, 0, path, _to, routerAddr, deadline);
            emit MintToken(_to, amounts[amounts.length - 1],mid,_amountIn);
            remove_signature_all(item);
            deleteItems(mid);
            delete mintItems[mid];
            return;
        }
        // MintItem item;
        mintItems[mid] = item;
    }
    
    
    function swapAndBurn( uint _amountIn, uint _amountOutMin, address fromToken, uint256 ntype, string memory toToken, address routerAddr, address WethAddr, uint deadline) payable public
    {
        // require(msg.value > 0);
        //address czzToken1 = 0x5bdA60F4Adb9090b138f77165fe38375F68834af;
        require(address(0) != routerAddr); 
        require(address(0) != WethAddr); 
        address[] memory path = new address[](3);
        path[0] = fromToken;
        path[1] = WethAddr;
        path[2] = czzToken;
        uint[] memory amounts = swap_burn_get_amount(_amountIn, path, routerAddr);
        _swapBurn(_amountIn, _amountOutMin, path, msg.sender, routerAddr, deadline);
        //_swap(_amountIn, _amountOutMin, path, msg.sender, routerAddr, deadline);
        if(ntype != 2){
            ICzzSwap(czzToken).burn(msg.sender, amounts[amounts.length - 1]);
            emit BurnToken(msg.sender, amounts[amounts.length - 1], ntype, toToken);
        }
      
    }
    
    function swapAndBurn_t( uint _amountIn, uint _amountOutMin, address fromToken, address toToken, address routerAddr, address WethAddr, uint deadline) payable public
    {
        // require(msg.value > 0);
        //address czzToken1 = 0x5bdA60F4Adb9090b138f77165fe38375F68834af;
        require(address(0) != routerAddr); 
        require(address(0) != WethAddr); 
        address[] memory path = new address[](3);
        path[0] = fromToken;
        path[1] = WethAddr;
        path[2] = toToken;
        _swapMint(_amountIn, _amountOutMin, path, msg.sender, routerAddr, deadline);

      
    }
    
    function swapAndBurn_t1( uint _amountIn, uint _amountOutMin, address fromToken, address toToken, address routerAddr, address WethAddr, uint deadline) payable public
    {
        // require(msg.value > 0);
        //address czzToken1 = 0x5bdA60F4Adb9090b138f77165fe38375F68834af;
        require(address(0) != routerAddr); 
        require(address(0) != WethAddr); 
        address[] memory path = new address[](3);
        path[0] = fromToken;
        path[1] = WethAddr;
        path[2] = toToken;
        _swap(_amountIn, _amountOutMin, path, msg.sender, routerAddr, deadline);

      
    }
    
    function swapAndBurnHt( uint _amountInMin, uint256 ntype, string memory toToken, address routerAddr, address WethAddr, uint deadline) payable public
    {
        require(address(0) != routerAddr); 
        require(address(0) != WethAddr); 
        require(msg.value > 0);
        address[] memory path = new address[](2);
        path[0] = address(WethAddr);
        path[1] = address(czzToken);
        uint[] memory amounts = swap_burn_get_amount(msg.value, path, routerAddr);
        _swapHtBurn(_amountInMin, path, msg.sender, routerAddr, deadline);
        if(ntype != 2){
            ICzzSwap(czzToken).burn(msg.sender, amounts[amounts.length - 1]);
            emit BurnToken(msg.sender, amounts[amounts.length - 1], ntype, toToken);
        }
      
    }
    
    function setMinSignatures(uint8 value) public isManager {
        minSignatures = value;
    }

    function getMinSignatures() public view isManager returns(uint256){
        return minSignatures;
    }

    function setCzzTonkenAddress(address addr) public isManager {
        czzToken = addr;
    }

    function getCzzTonkenAddress() public view isManager returns(address ){
        return czzToken;
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
