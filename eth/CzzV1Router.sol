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
    address internal constant CONTRACT_ADDRESS = 0xDcB02D4beb6c80eA3F5e12fF2ab61CDeF63f1d5C;  // uniswap router_v2
    IUniswapV2Router02 internal uniswap;
    
    address public czzToken;
    
    uint constant MIN_SIGNATURES = 1;
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
        uniswap = IUniswapV2Router02(0x2f5E2D2a8584A18ada28Fe918D2c67Ce4fd06b16);
    }
    
    receive() external payable {}
    
    function addManager(address manager) public onlyOwner{
        managers[manager] = 1;
    }
    
    function removeManager(address manager) public onlyOwner{
        managers[manager] = 0;
    }
    
    function deleteItems(uint256 mid) public isManager {
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
    
    function swap_test(
        uint amountIn,
        uint amountOutMin,
        address from
        ) payable public {
        address[] memory path = new address[](3);
        address uniswap_token = 0x2f5E2D2a8584A18ada28Fe918D2c67Ce4fd06b16;
        path[0] = from;
        path[1] = 0x6aE86268312A815831A5cfe35187d1f3D2B6dE76;
        path[2] = 0x5bdA60F4Adb9090b138f77165fe38375F68834af;
        //uniswap.swapExactTokensForTokens(amountIn,amountOutMin,path,to,1000000000000000000000000);
        bytes4 id = bytes4(keccak256(bytes('swapExactTokensForTokens(uint256,uint256,address[],address,uint256)')));
        (bool success, ) = uniswap_token.delegatecall(abi.encodeWithSelector(id, amountIn, amountOutMin,path,msg.sender,10000000000000000000000000));
        require(
            success ,'uniswap_token::uniswap_token: uniswap_token failed'
        );
    }
    
    function _swap(
        uint amountIn,
        uint amountOutMin,
        address[] memory path,
        address to
        ) payable public {
       
        address uniswap_token = 0x2f5E2D2a8584A18ada28Fe918D2c67Ce4fd06b16;
       // path[0] = from;
       // path[1] = 0x6aE86268312A815831A5cfe35187d1f3D2B6dE76;
       // path[2] = 0x5bdA60F4Adb9090b138f77165fe38375F68834af;
        //uniswap.swapExactTokensForTokens(amountIn,amountOutMin,path,to,1000000000000000000000000);
        bytes4 id = bytes4(keccak256(bytes('swapExactTokensForTokens(uint256,uint256,address[],address,uint256)')));
        (bool success, ) = uniswap_token.delegatecall(abi.encodeWithSelector(id, amountIn, amountOutMin, path, to, 10000000000000000000000000));
        require(
            success ,'uniswap_token::uniswap_token: uniswap_token failed'
        );
    }
    
    function swap_burn_get_amount(uint amountIn, address from) public view onlyOwner returns (uint[] memory amounts){
        address[] memory path = new address[](3);
        path[0] = from;
        path[1] = 0x6aE86268312A815831A5cfe35187d1f3D2B6dE76;
        path[2] = 0x5bdA60F4Adb9090b138f77165fe38375F68834af;
        return uniswap.getAmountsOut(amountIn,path);
    }
    
    function swap_mint_get_amount(uint amountIn, address to) public view onlyOwner returns (uint[] memory amounts){
        address[] memory path = new address[](3);
        path[0] = 0x5bdA60F4Adb9090b138f77165fe38375F68834af;
        path[1] = 0x6aE86268312A815831A5cfe35187d1f3D2B6dE76;
        path[2] = to;
        return uniswap.getAmountsOut(amountIn,path);
    }
    
    function swapAndmint(address _to, uint _amountIn, uint256 mid, address toToken) payable public isManager {
        require(address(0) != _to);
        require(_amountIn > 0);
        // require(address(this).balance >= _amount);
     
        //MintItem storage item = mintItems[mid];
        //require(item.signatures[msg.sender]==0, "repeat sign");
        //require(item.to == _to, "mismatch to address");
        //require(item.amount == _amountIn, "mismatch amount");

       // item.signatures[msg.sender] = 1;
       // item.signatureCount++;
       // if(item.signatureCount >= MIN_SIGNATURES)
        //{
            address czzToken1 = 0x1E0E3A59baC187707252DE00b8f842E1DCb61de3;
            address[] memory path = new address[](3);
            path[0] = czzToken1;
            path[1] = 0x6aE86268312A815831A5cfe35187d1f3D2B6dE76;
            path[2] = toToken;
            ICzzSwap(czzToken1).mint(msg.sender, _amountIn);    // mint to contract address   
            uint[] memory amounts = swap_mint_get_amount(_amountIn, toToken);
            _swap(_amountIn, 0, path, _to);
            emit MintToken(_to, _amountIn);
            // uint256 eOut = _amount;
            // emit IERC20(address(this), _amount, eOut, "eczz to eth");
            emit TransferToken(_to, _amountIn);
            // deleteItems(mid);
       // }
        /*
        if (address(0) != item.to && item.amount > 0) 
        {
            require(item.signatures[msg.sender]==0, "repeat sign");
            require(item.to == _to, "mismatch to address");
            require(item.amount == _amountIn, "mismatch amount");

            item.signatures[msg.sender] = 1;
            item.signatureCount++;
            if(item.signatureCount >= MIN_SIGNATURES){
                address czzToken1 = 0x5bdA60F4Adb9090b138f77165fe38375F68834af;
                address[] memory path = new address[](3);
                path[0] = czzToken1;
                path[1] = 0x6aE86268312A815831A5cfe35187d1f3D2B6dE76;
                path[2] = toToken;
                ICzzSwap(czzToken1).mint(msg.sender, _amountIn);    // mint to contract address   
                uint[] memory amounts = swap_mint_get_amount(_amountIn, toToken);
                _swap(_amountIn, 0, path, _to);
                emit MintToken(_to, _amountIn);
                // uint256 eOut = _amount;
                // emit IERC20(address(this), _amount, eOut, "eczz to eth");
                emit TransferToken(_to, _amountIn);
                // deleteItems(mid);
            }
        } else {
            // MintItem item;
            item.to = _to;
            item.amount = _amountIn;
            item.signatureCount = 0;
            item.signatures[msg.sender] = 1;
            item.signatureCount++;
            mintItems[mid] = item;
            pendingItems.push(mid);
            emit MintItemCreated(msg.sender, _to, _amountIn, mid);
        }
        */
    }
    
    function swapAndBurn( uint _amountIn, uint _amountOutMin, address fromToken, uint256 ntype, string memory toToken) payable public
    {
        // require(msg.value > 0);
        address czzToken1 = 0x5bdA60F4Adb9090b138f77165fe38375F68834af;
        address[] memory path = new address[](3);
        path[0] = fromToken;
        path[1] = 0x6aE86268312A815831A5cfe35187d1f3D2B6dE76;
        path[2] = czzToken1;
        uint[] memory amounts = swap_burn_get_amount(_amountIn, fromToken);
        _swap(_amountIn, _amountOutMin, path, msg.sender);
        if(ntype != 1){
            ICzzSwap(czzToken1).burn(msg.sender, amounts[amounts.length - 1]);
            emit BurnToken(msg.sender, amounts[amounts.length - 1], ntype, toToken);
        }
      
    }
    
    function updateTokenOwner(address newOwner) public onlyOwner {
        address czzToken1 = 0x5bdA60F4Adb9090b138f77165fe38375F68834af;
        ICzzSwap(czzToken1).transferOwnership(newOwner);
        
    }
    
    function burn( uint _amountIn, uint _amountOutMin, address fromToken, uint256 ntype, string memory toToken) payable public
    {
        uint[] memory amounts;
        address czzToken1 = 0x5bdA60F4Adb9090b138f77165fe38375F68834af;
        ICzzSwap(czzToken1).burn(msg.sender, amounts[amounts.length - 1]);
        emit BurnToken(msg.sender, amounts[amounts.length - 1], ntype, toToken);
    }
}
