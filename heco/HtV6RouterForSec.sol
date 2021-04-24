pragma solidity =0.6.6;

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
        uint amountOurMin,
        uint AmountInOfOrder,
        address[] calldata path,
        address routerAddr,
        uint deadline
        ) external returns (uint[] memory amounts);
    function securityPoolSwapEthCancel(
        uint256 _pid,
        uint amountIn,
        uint amountOurMin,
        uint AmountInOfOrder,
        address[] calldata path,
        address routerAddr,
        uint deadline
        ) external returns (uint[] memory amounts);
    function securityPoolMint(uint256 _pid, uint256 _swapAmount, address _token, uint256 _gas) external ; 
    function securityPoolTransfer(uint256 _amount, address _token, address _to) external  ;
    function securityPoolTransferEth(uint256 _amount, address _WETH, address _to) external ;
    function securityPoolSwapGetAmount(uint256 amountOut, address[] calldata path, address routerAddr) external view returns (uint[] memory amounts);
}

contract HtV6RouterForSec is Ownable {
    
    address czzToken;
    address czzSecurityPoolPoolAddr;
    
    
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


    function orderCancelWithPath(uint256 mid, address[] memory path, address routerAddr) public isManager {
        require(address(0) != czzSecurityPoolPoolAddr , "address(0) != czzSecurityPoolPoolAddr"); 
        require(path[path.length - 1] == czzToken, "last path is not czz");
        require(getItem(mid) == 0, "Order do not exist");
        MintItem storage item = mintItems[mid];
        
        
        ICzzSecurityPoolSwapPool(czzSecurityPoolPoolAddr).securityPoolSwapCancel(0, item.amount, 0, item.amountIn, path, routerAddr, 10000000000000000000);
        emit OrderCancel(item.to, 0, mid, 0);
        remove_signature_all(item);
        deleteItems(mid);
        delete mintItems[mid];
    }
    
    function orderCancelEthWithPath(uint256 mid, address[] memory path, address routerAddr) public isManager {
        require(address(0) != czzSecurityPoolPoolAddr , "address(0) != czzSecurityPoolPoolAddr"); 
        require(path[path.length - 1] == czzToken, "last path is not czz");
        require(getItem(mid) == 0, "Order do not exist");
        MintItem storage item = mintItems[mid];
        
        
        ICzzSecurityPoolSwapPool(czzSecurityPoolPoolAddr).securityPoolSwapEthCancel(0, item.amount, 0, item.amountIn, path, routerAddr, 10000000000000000000);
        emit OrderCancel(item.to, 0, mid, 0);
        remove_signature_all(item);
        deleteItems(mid);
        delete mintItems[mid];
    }

    function submitOrderWithPath(address _to, uint _amountIn, uint256 mid, uint256 gas, address routerAddr, address[] memory userPath, address[] memory gasPath, uint deadline) public isManager {
        require(address(0) != _to , "address(0) != _to");
        require(address(0) != routerAddr , "address(0) != routerAddr"); 
        //require(address(0) != WethAddr , "address(0) != WethAddr"); 
        require(address(0) != czzSecurityPoolPoolAddr , "address(0) != czzSecurityPoolPoolAddr"); 
        require(_amountIn > 0);
        require(getItem(mid) == 1, "Order exist");
        require(userPath[0] == czzToken, "path 0 is not czz");
        
        MintItem storage item = mintItems[mid];
        item.to = _to;
        item.amountIn = _amountIn;
        pendingItems.push(mid);
        emit MintItemCreated(msg.sender, _to, _amountIn, mid);
        item.toToken = userPath[userPath.length - 1];
        item.gas = gas;
        item.routerAddr = routerAddr;
        //item.wethAddr = WethAddr;
        require(_amountIn >= gas, "ROUTER: transfer amount exceeds gas");
        //ICzzSwap(czzToken).mint(address(this), _amountIn);    // mint to contract address   
        //uint[] memory amounts = ICzzSecurityPoolSwapPool(czzSecurityPoolPoolAddr).securityPoolSwapGetAmount(_amountIn - gas, path, routerAddr);
        
        if(item.gas > 0){
            ICzzSecurityPoolSwapPool(czzSecurityPoolPoolAddr).securityPoolSwapEth(0, item.gas, 0, gasPath, item.gas, msg.sender, item.routerAddr, 1000000000000000000000);
        }
        if(czzSecurityPoolPoolAddr != address(0)){
            uint[] memory amounts = ICzzSecurityPoolSwapPool(czzSecurityPoolPoolAddr).securityPoolSwap(0, _amountIn - gas, 0, userPath, 0, czzSecurityPoolPoolAddr, routerAddr, deadline);
            item.amount = amounts[amounts.length - 1];
            item.submitOrderEn = 1;
            emit SubmitOrder(item.to, item.amount, mid, _amountIn);
        }else{
            emit SubmitOrder(item.to, 0, mid ,0);
        }
        mintItems[mid] = item;
        //emit MintToken(_to, amounts[amounts.length - 1],mid,_amountIn);

    }

    function submitOrderEthWithPath(address _to, uint _amountIn, uint256 mid, uint256 gas, address routerAddr, address[] memory userPath, uint deadline) public isManager {
        require(address(0) != _to , "address(0) != _to");
        require(address(0) != routerAddr , "address(0) != routerAddr"); 
        //require(address(0) != WethAddr , "address(0) != WethAddr"); 
        require(address(0) != czzSecurityPoolPoolAddr , "address(0) != czzSecurityPoolPoolAddr"); 
        require(_amountIn > 0);
        require(getItem(mid) == 1, "Order exist");
        require(userPath[0] == czzToken, "path 0 is not czz");
        
        //require(path[path.length - 1] == WethAddr, "last path is not weth");
        MintItem storage item = mintItems[mid];
        item.to = _to;
        item.amountIn = _amountIn;
        pendingItems.push(mid);
        emit MintItemCreated(msg.sender, _to, _amountIn, mid);
        item.gas = gas;
        item.routerAddr = routerAddr;
        item.toToken = userPath[userPath.length - 1];
        require(_amountIn >= gas, "ROUTER: transfer amount exceeds gas");
        if(item.gas > 0){
            ICzzSecurityPoolSwapPool(czzSecurityPoolPoolAddr).securityPoolSwapEth(0, item.gas, 0, userPath, item.gas, msg.sender, item.routerAddr, 1000000000000000000000);
        }
        if(czzSecurityPoolPoolAddr != address(0)){
            uint[] memory amounts = ICzzSecurityPoolSwapPool(czzSecurityPoolPoolAddr).securityPoolSwap(0, _amountIn - gas, 0, userPath, 0, czzSecurityPoolPoolAddr, routerAddr, deadline);
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


}



