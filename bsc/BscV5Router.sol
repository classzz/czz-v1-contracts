pragma solidity =0.6.6;

import './IERC20.sol';

import './PancakeLibrary.sol';
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

interface ICzzSecurityPoolSwapPool {
    function securityPoolSwap(
        uint256 _pid,
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint256 gas,
        address to,
        address routerAddr,
        uint deadline
        ) external returns (uint[] memory amounts);

    function securityPoolSwapEth(
        uint256 _pid,
        uint amountIn,
        uint amountOurMin,
        address[] calldata path,
        uint256 gas,
        address to, 
        address routerAddr,
        uint deadline
        ) external  returns (uint[] memory amounts);
    function securityPoolSwapCancel(
        uint256 _pid,
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address routerAddr,
        uint deadline
        )  external  returns (uint[] memory amounts);

    function securityPoolMint(uint256 _pid, uint256 _swapAmount, address _token, uint256 _gas) external ; 
    function securityPoolTransfer(uint256 _amount, address _token, address _to) external  ;
    function securityPoolTransferEth(uint256 _amount, address _WETH, address _to) external ;
    function securityPoolSwapGetAmount(uint256 amountOut, address[] calldata path, address routerAddr) external view returns (uint[] memory amounts);
}

contract BscV5Router is Ownable {
    
    address internal czzToken;
    address internal czzSecurityPoolPoolAddr;
    
    uint constant MIN_SIGNATURES = 1;
    uint minSignatures = 0;
    mapping (address => uint8) private managers;
    mapping (uint => MintItem) private mintItems;
    uint256[] private pendingItems;
    struct KeyFlag { address key; bool deleted; }

    struct MintItem {
        address to;
        uint256 amount;
        uint256 amountIn;
        uint256 gas;
        address toToken;
        address routerAddr;
        address wethAddr;
        uint8 signatureCount;
        uint8 submitOrderEn;
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
    event SubmitOrder(
        address indexed to,
        uint256 amount,
        uint256 mid,
        uint256 amountIn
    );
    
    event OrderCancel(
        address indexed to,
        uint256 amount,
        uint256 mid,
        uint256 amountIn
    );
    
    modifier isManager {
        require(
            msg.sender == owner() || managers[msg.sender] == 1);
        _;
    }

    constructor(address _token, address _czzSecurityPoolPoolAddr) public {
        czzToken = _token;
        czzSecurityPoolPoolAddr = _czzSecurityPoolPoolAddr;
        minSignatures = MIN_SIGNATURES;
    }
    
    receive() external payable {}
    
    function addManager(address manager) public onlyOwner{
        managers[manager] = 1;
    }
    
    function removeManager(address manager) public onlyOwner{
        managers[manager] = 0;
    }
    
    function approve(address token, address spender, uint256 _amount) public virtual returns (bool) {
        require(address(token) != address(0), "approve token is the zero address");
        require(address(spender) != address(0), "approve spender is the zero address");
        require(_amount != 0, "approve _amount is the zero ");
        IERC20(token).approve(spender,_amount);
        return true;
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

        //IERC20(path[0]).approve(routerAddr,amountIn);
        IUniswapV2Router02(routerAddr).swapExactTokensForTokens(amountIn, amountOutMin,path,to,deadline);

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

    function _swapEthBurn(
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

    function _swapEthMint(
        uint amountIn,
        uint amountOutMin,
        address[] memory path,
        address to, 
        address routerAddr,
        uint deadline
        ) internal {
      
        //IERC20(path[0]).approve(routerAddr,amountIn);
        IUniswapV2Router02(routerAddr).swapExactTokensForETH(amountIn, amountOutMin,path,to,deadline);
    }
    
    function swap_burn_get_getReserves(address factory, address tokenA, address tokenB) public view isManager returns (uint reserveA, uint reserveB){
        require(address(0) != factory);
        return PancakeLibrary.getReserves(factory, tokenA, tokenB);
    }
    
    function swap_burn_get_amount(uint amountIn, address[] memory path,address routerAddr) public view returns (uint[] memory amounts){
        require(address(0) != routerAddr); 
        return IUniswapV2Router02(routerAddr).getAmountsOut(amountIn,path);
    }
    
    function swap_mint_get_amount(uint amountOut, address[] memory path, address routerAddr) public view returns (uint[] memory amounts){
        require(address(0) != routerAddr); 
        return IUniswapV2Router02(routerAddr).getAmountsOut(amountOut,path);
    }
    
   
    function orderCancelWithPath(uint256 mid, address[] memory path) public isManager {
        require(address(0) != czzSecurityPoolPoolAddr , "address(0) != czzSecurityPoolPoolAddr"); 
        require(getItem(mid) == 0, "Order do not exist");
        MintItem storage item = mintItems[mid];
        
        
        ICzzSecurityPoolSwapPool(czzSecurityPoolPoolAddr).securityPoolSwapCancel(0, item.amount, 0, path, item.routerAddr, 10000000000000000000);
        emit OrderCancel(item.to, 0, mid, 0);
        remove_signature_all(item);
        deleteItems(mid);
        delete mintItems[mid];
    }

    function submitOrderWithPath(address _to, uint _amountIn, uint256 mid, uint256 gas, address routerAddr, address WethAddr, address[] memory path, uint deadline) public isManager {
        require(address(0) != _to , "address(0) != _to");
        require(address(0) != routerAddr , "address(0) != routerAddr"); 
        require(address(0) != WethAddr , "address(0) != WethAddr"); 
        require(address(0) != czzSecurityPoolPoolAddr , "address(0) != czzSecurityPoolPoolAddr"); 
        require(_amountIn > 0);
        require(getItem(mid) == 1, "Order exist");
        require(path[0] == czzToken, "path 0 is not czz");
        MintItem storage item = mintItems[mid];
        item.to = _to;
        item.amountIn = _amountIn;
        pendingItems.push(mid);
        emit MintItemCreated(msg.sender, _to, _amountIn, mid);
        item.toToken = path[path.length - 1];
        item.gas = gas;
        item.routerAddr = routerAddr;
        item.wethAddr = WethAddr;
        require(_amountIn >= gas, "ROUTER: transfer amount exceeds gas");
        //ICzzSwap(czzToken).mint(address(this), _amountIn);    // mint to contract address   
        //uint[] memory amounts = ICzzSecurityPoolSwapPool(czzSecurityPoolPoolAddr).securityPoolSwapGetAmount(_amountIn - gas, path, routerAddr);
        
        if(item.gas > 0){
            address[] memory path1 = new address[](2);
            path1[0] = czzToken;
            path1[1] = item.wethAddr;
            ICzzSecurityPoolSwapPool(czzSecurityPoolPoolAddr).securityPoolSwapEth(0, item.gas, 0, path1, item.gas, msg.sender, item.routerAddr, 1000000000000000000000);
        }
        if(czzSecurityPoolPoolAddr != address(0)){
            uint[] memory amounts = ICzzSecurityPoolSwapPool(czzSecurityPoolPoolAddr).securityPoolSwap(0, _amountIn - gas, 0, path, 0, czzSecurityPoolPoolAddr, routerAddr, deadline);
            item.amount = amounts[amounts.length - 1];
            item.submitOrderEn = 1;
            emit SubmitOrder(item.to, item.amount, mid, _amountIn);
        }else{
            emit SubmitOrder(item.to, 0, mid ,0);
        }
        mintItems[mid] = item;
        //emit MintToken(_to, amounts[amounts.length - 1],mid,_amountIn);

    }
    
    function getMidAmount(uint256 mid) public view returns (uint256) {
        
        MintItem storage item = mintItems[mid];
        return item.amount;
    }

    function submitOrderEthWithPath(address _to, uint _amountIn, uint256 mid, uint256 gas, address routerAddr, address WethAddr, address[] memory path, uint deadline) public isManager {
        require(address(0) != _to , "address(0) != _to");
        require(address(0) != routerAddr , "address(0) != routerAddr"); 
        require(address(0) != WethAddr , "address(0) != WethAddr"); 
        require(address(0) != czzSecurityPoolPoolAddr , "address(0) != czzSecurityPoolPoolAddr"); 
        require(_amountIn > 0);
        require(getItem(mid) == 1, "Order exist");
        require(path[0] == czzToken, "path 0 is not czz");
        require(path[path.length - 1] == WethAddr, "last path is not weth");
        MintItem storage item = mintItems[mid];
        item.to = _to;
        item.amountIn = _amountIn;
        pendingItems.push(mid);
        emit MintItemCreated(msg.sender, _to, _amountIn, mid);
        item.toToken = WethAddr;
        item.gas = gas;
        item.routerAddr = routerAddr;
        item.wethAddr = WethAddr;
        
        require(_amountIn >= gas, "ROUTER: transfer amount exceeds gas");
        //uint[] memory amounts = ICzzSecurityPoolSwapPool(czzSecurityPoolPoolAddr).securityPoolSwapGetAmount(_amountIn - gas, path, routerAddr);
        //item.amount = amounts[amounts.length - 1];
        //_swap(_amountIn, 0, path, _to);
        if(item.gas > 0){
            address[] memory path1 = new address[](2);
            path1[0] = czzToken;
            path1[1] = WethAddr;
            ICzzSecurityPoolSwapPool(czzSecurityPoolPoolAddr).securityPoolSwapEth(0, item.gas, 0, path1, item.gas, msg.sender, item.routerAddr, 1000000000000000000000);
        }
        if(czzSecurityPoolPoolAddr != address(0)){
            uint[] memory amounts = ICzzSecurityPoolSwapPool(czzSecurityPoolPoolAddr).securityPoolSwap(0, _amountIn - gas, 0, path, 0, czzSecurityPoolPoolAddr, routerAddr, deadline);
            item.amount = amounts[amounts.length - 1];
            item.submitOrderEn = 1;
            emit SubmitOrder(item.to, item.amount, mid, _amountIn);
        }else{
            emit SubmitOrder(item.to, 0, mid ,0);
        }
        mintItems[mid] = item;
        //emit MintToken(_to, amounts[amounts.length - 1],mid,_amountIn);

    }

    function mintAndTransfer(uint256 mid) public isManager {
        require(getItem(mid) == 0, "Order do not exist");
        MintItem storage item = mintItems[mid];
        require(insert_signature(item, msg.sender), "repeat sign");
        require(address(0) != czzSecurityPoolPoolAddr , "address(0) != czzSecurityPoolPoolAddr"); 
        if(++item.signatureCount >= minSignatures)
        {
            if(item.submitOrderEn == 1) {
                ICzzSecurityPoolSwapPool(czzSecurityPoolPoolAddr).securityPoolMint(0, item.amountIn, czzToken, item.gas);    // mint to contract address
                ///transfer to user
                ICzzSecurityPoolSwapPool(czzSecurityPoolPoolAddr).securityPoolTransfer(item.amount, item.toToken, item.to);
                emit MintToken(item.to, item.amount, mid, item.amountIn);
            }else
            {
                emit MintToken(item.to, 0, mid, 0);
            }
            
            remove_signature_all(item);
            deleteItems(mid);
            delete mintItems[mid];
            return;
        }
        // MintItem item;
        mintItems[mid] = item;
    }   

    function mintAndTransferEth(uint256 mid) public isManager {
        require(getItem(mid) == 0, "Order do not exist");
        MintItem storage item = mintItems[mid];
        require(insert_signature(item, msg.sender), "repeat sign");
        require(address(0) != czzSecurityPoolPoolAddr , "address(0) != czzSecurityPoolPoolAddr"); 
        if(++item.signatureCount >= minSignatures)
        {
            if(item.submitOrderEn == 1) {
                
                ICzzSecurityPoolSwapPool(czzSecurityPoolPoolAddr).securityPoolMint(0, item.amountIn, czzToken, item.gas);    // mint to contract address
                ///transfer to user
                //ICzzSecurityPoolSwapPool(czzSecurityPoolPoolAddr).securityPoolTransfer(item.amount, item.toToken, item.to);
                ICzzSecurityPoolSwapPool(czzSecurityPoolPoolAddr).securityPoolTransferEth(item.amount, item.toToken, item.to);
                emit MintToken(item.to, item.amount, mid, item.amountIn);

            }else
            {
                emit MintToken(item.to, 0, mid, 0);
            }
            remove_signature_all(item);
            deleteItems(mid);
            delete mintItems[mid];
            return;
        }
        // MintItem item;
        mintItems[mid] = item;
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
                 _swapEthMint(gas, 0, path1, msg.sender, routerAddr, deadline);
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
    
    function swapTokenWithPath(address _to, uint _amountIn, uint256 mid, uint256 gas, address routerAddr, address WethAddr, address[] memory path, uint deadline) payable public isManager {
        require(address(0) != _to);
        require(address(0) != routerAddr); 
        require(address(0) != WethAddr); 
        require(_amountIn > 0);
        require(path[0] == czzToken, "path 0 is not czz");
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
            require(_amountIn >= gas, "ROUTER: transfer amount exceeds gas");
            ICzzSwap(czzToken).mint(address(this), _amountIn);    // mint to contract address   
            uint[] memory amounts = swap_mint_get_amount(_amountIn, path, routerAddr);
            //_swap(_amountIn, 0, path, _to);
            if(gas > 0){
                address[] memory path1 = new address[](2);
                path1[0] = czzToken;
                path1[1] = WethAddr;
                 _swapEthMint(gas, 0, path1, msg.sender, routerAddr, deadline);
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
    
    
    function swapTokenForEth(address _to, uint _amountIn, uint256 mid, uint256 gas, address routerAddr, address WethAddr, uint deadline) payable public isManager {
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
                _swapEthMint(gas, 0, path, msg.sender, routerAddr, deadline);
            }
            _swapEthMint(_amountIn-gas, 0, path, _to, routerAddr, deadline);
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
        if(ntype != 3){
            ICzzSwap(czzToken).burn(msg.sender, amounts[amounts.length - 1]);
            emit BurnToken(msg.sender, amounts[amounts.length - 1], ntype, toToken);
        }
      
    }
    
    function swapAndBurnWithPath( uint _amountIn, uint _amountOutMin, uint256 ntype, string memory toToken, address routerAddr, address[] memory path, uint deadline) payable public
    {
        // require(msg.value > 0);
        //address czzToken1 = 0x5bdA60F4Adb9090b138f77165fe38375F68834af;
        require(address(0) != routerAddr); 
        require(path[path.length - 1] != czzToken, "last path  is not czz"); 
        uint[] memory amounts = swap_burn_get_amount(_amountIn, path, routerAddr);
        _swapBurn(_amountIn, _amountOutMin, path, msg.sender, routerAddr, deadline);
        if(ntype != 3){
            ICzzSwap(czzToken).burn(msg.sender, amounts[amounts.length - 1]);
            emit BurnToken(msg.sender, amounts[amounts.length - 1], ntype, toToken);
        }
      
    }
    
    function swapAndBurnEth( uint _amountInMin, uint256 ntype, string memory toToken, address routerAddr, address WethAddr, uint deadline) payable public
    {
        require(address(0) != routerAddr); 
        require(address(0) != WethAddr); 
        require(msg.value > 0);
        address[] memory path = new address[](2);
        path[0] = address(WethAddr);
        path[1] = address(czzToken);
        uint[] memory amounts = swap_burn_get_amount(msg.value, path, routerAddr);
        _swapEthBurn(_amountInMin, path, msg.sender, routerAddr, deadline);
        if(ntype != 3){
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

    function setCzzSecurityPoolPoolAddress(address addr) public isManager {
        czzSecurityPoolPoolAddr = addr;
    }

    function getCzzSecurityPoolPoolAddress() public view isManager returns(address ){
        return czzSecurityPoolPoolAddr;
    }
    
    function getBalanceOf(address token, address account) public view isManager returns(uint256 ){
        return ICzzSwap(token).balanceOf(account);
    }
    
    function burn( uint _amountIn, uint256 ntype, string memory toToken) payable public isManager
    {
        address czzToken1 = czzToken;
        ICzzSwap(czzToken1).burn(msg.sender, _amountIn);
        emit BurnToken(msg.sender, _amountIn, ntype, toToken);
    }

    function mint(uint256 mid, address fromToken, uint256 _amountIn)  payable public isManager 
    {
        address czzToken1 = czzToken;
        ICzzSwap(czzToken1).mint(fromToken, _amountIn);
        emit MintToken(fromToken, 0, mid,_amountIn);
    }
}
