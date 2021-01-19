pragma solidity ^0.6.6;

import './libraries/SafeMath.sol';
import './interfaces/IERC20.sol';

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
}

contract CzzV1Router is Ownable {
    using SafeMath for uint;
    
    
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
        uint256  amount
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
    
    function mint(address _to, uint256 _amount, uint256 mid) payable public isManager {
        require(address(0) != _to);
        require(_amount > 0);
        // require(address(this).balance >= _amount);
     
        MintItem storage item = mintItems[mid];
        if (address(0) != item.to && item.amount > 0) {
            require(item.signatures[msg.sender]==0, "repeat sign");
            require(item.to == _to, "mismatch to address");
            require(item.amount == _amount, "mismatch amount");

            item.signatures[msg.sender] = 1;
            item.signatureCount++;
            if(item.signatureCount >= MIN_SIGNATURES){
                ICzzSwap(czzToken).mint(_to, _amount);    // mint to contract address    
                emit MintToken(_to, _amount);
                // uint256 eOut = _amount;
                // emit IERC20(address(this), _amount, eOut, "eczz to eth");
                emit TransferToken(_to, _amount);
                // deleteItems(mid);
            }
        } else {
            // MintItem item;
            item.to = _to;
            item.amount = _amount;
            item.signatureCount = 0;
            item.signatures[msg.sender] = 1;
            item.signatureCount++;
            mintItems[mid] = item;
            pendingItems.push(mid);
            emit MintItemCreated(msg.sender, _to, _amount, mid);
        }
    }
    
    function burn(uint256 _amountOut) payable public
    returns (uint[] memory amounts)
    {
        // require(msg.value > 0);
        
        // uint256 czzOut = _amountOut
        // uint256 czzOut = IRouter(baseSwap).swapSTD2Token{value: msg.value}(msg.value,czzToken,_minAmountOut);
        // emit SwapToken(msg.sender, msg.value,czzOut,"eth to czz");
        
        ICzzSwap(czzToken).burn(msg.sender, _amountOut);
        // emit BurnToken(address(this), czzOut);
      
    }
    
}
