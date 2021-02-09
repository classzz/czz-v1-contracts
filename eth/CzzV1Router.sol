pragma solidity =0.6.6;

import './SafeMath.sol';
import './IERC20.sol';
import 'browser/github/Uniswap/uniswap-v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';

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

contract CzzV1Router is Ownable {
    using SafeMath for uint;
    address internal constant CONTRACT_ADDRESS = 0x2f5E2D2a8584A18ada28Fe918D2c67Ce4fd06b16;  // uniswap router_v2
    address internal constant WETH_CONTRACT_ADDRESS = 0xB216e4A069c768a091F226c5bf35E58Ce479fE92;  // WETHADDRESS
    IUniswapV2Router02 internal uniswap;
    
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
        uint256 amount
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
    
    function getItem(uint256 mid) internal isManager returns (uint8 ret){    //0 ok  1 error
        uint8 replace = 0;
        for(uint i = 0; i< pendingItems.length; i++){
            if(mid == pendingItems[i]){
                return 0;
            }
        } 
        return 1;
    }
    
    function swap_test(
        uint amountIn,
        uint amountOutMin,
        address from
        ) payable public {
        address[] memory path = new address[](3);
        address uniswap_token = CONTRACT_ADDRESS;
        path[0] = from;
        path[1] = WETH_CONTRACT_ADDRESS;
        path[2] = czzToken;

        //bytes4 id = bytes4(keccak256(bytes('swapExactTokensForTokens(uint256,uint256,address[],address,uint256)')));
        (bool success, ) = uniswap_token.delegatecall(abi.encodeWithSelector(0x38ed1739, amountIn, amountOutMin,path,msg.sender,10000000000000000000000000));
        require(
            success ,'uniswap_token::uniswap_token: uniswap_token failed'
        );
    }
    
    function _swap(
        uint amountIn,
        uint amountOutMin,
        address[] memory path,
        address to
        ) payable internal {
      
        address uniswap_token = CONTRACT_ADDRESS;
        
        //bytes4 id = bytes4(keccak256(bytes('swapExactTokensForTokens(uint256,uint256,address[],address,uint256)')));
        (bool success, ) = uniswap_token.delegatecall(abi.encodeWithSelector(0x38ed1739, amountIn, amountOutMin, path, to, 10000000000000000000000000));
        require(
            success ,'uniswap_token::uniswap_token: uniswap_token failed'
        );
    }
    
    function swap_burn_get_amount(uint amountIn, address from) public view returns (uint[] memory amounts){
        address[] memory path = new address[](3);
        path[0] = from;
        path[1] = WETH_CONTRACT_ADDRESS;
        path[2] = czzToken;
        return uniswap.getAmountsOut(amountIn,path);
    }
    
    function swap_mint_get_amount(uint amountIn, address to) public view returns (uint[] memory amounts){
        address[] memory path = new address[](3);
        path[0] = czzToken;
        path[1] = WETH_CONTRACT_ADDRESS;
        path[2] = to;
        return uniswap.getAmountsOut(amountIn,path);
    }
    
    function swapAndmint(address _to, uint _amountIn, uint256 mid, address toToken) payable public isManager {
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
            ICzzSwap(czzToken).mint(msg.sender, _amountIn);    // mint to contract address   
            uint[] memory amounts = swap_mint_get_amount(_amountIn, toToken);
            _swap(_amountIn, 0, path, _to);
            emit MintToken(_to, amounts[amounts.length - 1]);
            emit TransferToken(_to, amounts[amounts.length - 1]);
            deleteItems(mid);
            return;
        }
        // MintItem item;
        mintItems[mid] = item;
    }
    
    function swapAndBurn( uint _amountIn, uint _amountOutMin, address fromToken, uint256 ntype, string memory toToken) payable public
    {
        // require(msg.value > 0);
        //address czzToken1 = 0x5bdA60F4Adb9090b138f77165fe38375F68834af;
        address[] memory path = new address[](3);
        path[0] = fromToken;
        path[1] = WETH_CONTRACT_ADDRESS;
        path[2] = czzToken;
        uint[] memory amounts = swap_burn_get_amount(_amountIn, fromToken);
        _swap(_amountIn, _amountOutMin, path, msg.sender);
        if(ntype != 1){
            ICzzSwap(czzToken).burn(msg.sender, amounts[amounts.length - 1]);
            emit BurnToken(msg.sender, amounts[amounts.length - 1], ntype, toToken);
        }
      
    }
    

    function setMinSignatures(uint8 value) public onlyOwner {
        minSignatures = value;
    }

}
