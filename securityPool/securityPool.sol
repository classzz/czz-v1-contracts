// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}

interface IMdx is IERC20 {
    function mint(address to, uint256 amount) external returns (bool);
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

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
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

contract securityPool is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    mapping (address => uint8) private managers;
    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt.
        uint256 pendingAmount; // 
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. MDXs to distribute per block.
        uint256 allocPointDecimals;
        uint256 accMdxPerShare; // Accumulated MDXs per share, times 1e12.
        uint256 totalAmount;    // Total amount of current pool deposit.
        uint256 totalPendingReward ;
        uint256 totalReward;
        uint256 usingAmount;
        uint256 lossAmount;
    }

    // The MDX Token!
    IMdx public mdx;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Corresponding to the pid of the multLP pool
    mapping(uint256 => uint256) public poolCorrespond;
    // pid corresponding address
    mapping(address => uint256) public LpOfPid;
    // Control mining
    bool public paused = false;
    
    uint256 public allocPointDecimals;
    
    uint256 public allocPoint;

    uint256 depositMinValue;
    
    /////test
    uint256 internal test  = 0;

    address internal WETH;
    
 
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    modifier isManager {
        require(
            msg.sender == owner() || managers[msg.sender] == 1);
        _;
    }
    constructor (
        IMdx _mdx
    ) public {
        mdx = _mdx;
        depositMinValue = 10 ** 13;
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }
    
    function addManager(address manager) public onlyOwner{
        managers[manager] = 1;
    }
    
    function removeManager(address manager) public onlyOwner{
        managers[manager] = 0;
    }


    function poolLength() public view returns (uint256) {
        return poolInfo.length;
    }
    
    function approve(address token, address spender, uint256 _amount) public virtual returns (bool) {
        require(address(token) != address(0), "approve token is the zero address");
        require(address(spender) != address(0), "approve spender is the zero address");
        require(_amount != 0, "approve _amount is the zero ");
        IERC20(token).approve(spender,_amount);
        return true;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, uint256 _allocPointDecimals, IERC20 _lpToken) public onlyOwner {
        require(address(_lpToken) != address(0), "_lpToken is the zero address");
        poolInfo.push(PoolInfo({
        lpToken : _lpToken,
        allocPoint : _allocPoint,
        allocPointDecimals : _allocPointDecimals,
        accMdxPerShare : 0,
        totalAmount : 0,
        totalPendingReward : 0,
        totalReward : 0,
        usingAmount : 0,
        lossAmount : 0
        }));
        allocPoint = _allocPoint;
        allocPointDecimals = _allocPointDecimals;
        LpOfPid[address(_lpToken)] = poolLength() - 1;
    }

    // Update the given pool's MDX allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, uint256 _allocPointDecimals) public onlyOwner {
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].allocPointDecimals = _allocPointDecimals;
        allocPoint = _allocPoint;
        allocPointDecimals = _allocPointDecimals;
    }

    // The current pool corresponds to the pid of the multLP pool
    function setPoolCorr(uint256 _pid, uint256 _sid) public onlyOwner {
        require(_pid <= poolLength() - 1, "not find this pool");
        poolCorrespond[_pid] = _sid;
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        uint256 lpSupply;
        lpSupply = pool.totalAmount;
        if (lpSupply == 0) {
            return;
        }
        uint256 mdxReward = pool.totalPendingReward;
        if (mdxReward != 0) {
            pool.accMdxPerShare = pool.accMdxPerShare.add(mdxReward.mul(1e12).div(lpSupply));
        }
        pool.totalReward = pool.totalReward.add(pool.totalPendingReward);
        pool.totalPendingReward = 0;
    }

    // View function to see pending MDXs on frontend.
    function pending(uint256 _pid, address _user) external view returns (uint256, uint256){
        uint256 mdxAmount = pendingMdx(_pid, _user);
        return (mdxAmount, 0);

    }

    function pendingMdx(uint256 _pid, address _user) private view returns (uint256){
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accMdxPerShare = pool.accMdxPerShare;
        uint256 lpSupply= pool.totalAmount;
        if (lpSupply == 0) {
            return 0;
        }
        if (user.amount > 0) {
            uint256 mdxReward = pool.totalPendingReward;
            if (mdxReward != 0) {
                accMdxPerShare = accMdxPerShare.add(mdxReward.mul(1e12).div(lpSupply));
                return user.amount.mul(accMdxPerShare).div(1e12).sub(user.rewardDebt);
            }
        }
        return 0;
    }

    // Deposit LP tokens to HecoPool for MDX allocation.
    function deposit(uint256 _pid, uint256 _amount) public notPause {
        require(_pid <= poolLength() - 1, "not find this pool");
        depositMdx(_pid, _amount, msg.sender);

    }

    function depositMdx(uint256 _pid, uint256 _amount, address _user) private {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pendingAmount = user.amount.mul(pool.accMdxPerShare).div(1e12).sub(user.rewardDebt);
            if (pendingAmount > 0) {
                safeMdxTransfer(_pid, _user, pendingAmount);
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(_user, address(this), _amount);
            user.amount = user.amount.add(_amount);
            pool.totalAmount = pool.totalAmount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accMdxPerShare).div(1e12);
        emit Deposit(_user, _pid, _amount);
    }

    // Withdraw LP tokens from HecoPool.
    function withdraw(uint256 _pid, uint256 _amount) public notPause {
        withdrawMdx(_pid, _amount, msg.sender);
    }

    function withdrawMdx(uint256 _pid, uint256 _amount, address _user) private {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        require(user.amount >= _amount, "withdrawMdx: not good");
        updatePool(_pid);
        uint256 pendingAmount = user.amount.mul(pool.accMdxPerShare).div(1e12).sub(user.rewardDebt);
        if (pendingAmount > 0) {
            safeMdxTransfer(_pid, _user, pendingAmount);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.totalAmount = pool.totalAmount.sub(_amount);
            pool.lpToken.safeTransfer(_user, _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accMdxPerShare).div(1e12);
        emit Withdraw(_user, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public notPause {
        emergencyWithdrawMdx(_pid, msg.sender);
    }

    function emergencyWithdrawMdx(uint256 _pid, address _user) private {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(_user, amount);
        pool.totalAmount = pool.totalAmount.sub(amount);
        emit EmergencyWithdraw(_user, _pid, amount);
    }

    // Safe MDX transfer function, just in case if rounding error causes pool to not have enough MDXs.
    function safeMdxTransfer(uint256 _pid, address _to, uint256 _amount) internal {
        PoolInfo storage pool = poolInfo[_pid];
        uint256 mdxBal = pool.totalReward;
        if (_amount > mdxBal) {
            mdx.transfer(_to, mdxBal);
            pool.totalReward = pool.totalReward.sub(mdxBal);
        } else {
            mdx.transfer(_to, _amount);
            pool.totalReward = pool.totalReward.sub(_amount);
        }
    }

    function getMdxBalance() public view returns ( uint256 ) {
        return mdx.balanceOf(address(this));

    }

    function getPidForAddr( address addr) public view returns ( uint256 ) {
        return LpOfPid[addr];

    }

    modifier notPause() {
        require(paused == false, "Mining has been suspended");
        _;
    }

    function addReward(uint256 _pid, uint256 _Reward) internal isManager{
        PoolInfo storage pool = poolInfo[_pid];
        pool.totalPendingReward = pool.totalPendingReward.add(_Reward);

    }


    function securityPoolSwap(
        uint256 _pid,
        uint amountIn,
        uint amountOutMin,
        address[] memory path,
        uint256 gas,
        address to,
        address routerAddr,
        uint deadline
        ) public isManager returns (uint[] memory amounts) {
      
        PoolInfo storage pool = poolInfo[_pid];
        //Calculation of reward !!!
        uint _amountIn = 0;
        if(gas == 0) {
            require(amountIn.mul(allocPoint).div(allocPointDecimals) > 0, "amountIn: volumes are too small");
            _amountIn = amountIn.sub(amountIn.mul(allocPoint).div(allocPointDecimals));
        }else{
             _amountIn = amountIn;
        }
        uint256 _amount = IERC20(path[0]).allowance(address(this),routerAddr);
        if(_amount < amountIn) {
            IERC20(path[0]).approve(routerAddr,uint256(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff));
        }
        amounts = IUniswapV2Router02(routerAddr).swapExactTokensForTokens(_amountIn, amountOutMin,path,to,deadline);
        pool.usingAmount = pool.usingAmount.add(_amountIn);
        return amounts;
    }

    function securityPoolSwapCancel(
        uint256 _pid,
        uint amountIn,
        uint amountOutMin,
        uint AmountInOfOrder,
        address[] memory path,
        address routerAddr,
        uint deadline
        ) public isManager returns (uint[] memory amounts) {
        require(address(mdx) == path[path.length - 1], "last path is not pool token address");
        PoolInfo storage pool = poolInfo[_pid];
        uint256 _amount = IERC20(path[0]).allowance(address(this),routerAddr);
        if(_amount < amountIn) {
            IERC20(path[0]).approve(routerAddr,uint256(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff));
        }
        amounts = IUniswapV2Router02(routerAddr).swapExactTokensForTokens(amountIn, amountOutMin,path,address(this),deadline);
        uint256 amount = amounts[amounts.length - 1];
        if(AmountInOfOrder > amount){
            pool.usingAmount = pool.usingAmount.sub(amount);
            pool.lossAmount = AmountInOfOrder - amount;
        }else{
            pool.usingAmount = pool.usingAmount.sub(AmountInOfOrder);
        }
        return amounts;
    }

    function securityPoolSwapEthCancel(
        uint256 _pid,
        uint amountIn,
        uint amountOutMin,
        uint AmountInOfOrder,
        address[] memory path,
        address routerAddr,
        uint deadline
        ) public isManager returns (uint[] memory amounts) {
        require(address(mdx) == path[path.length - 1], "last path is not pool token address");
        PoolInfo storage pool = poolInfo[_pid];
        uint256 _amount = IERC20(path[0]).allowance(address(this),routerAddr);
        if(_amount < amountIn) {
            IERC20(path[0]).approve(routerAddr,uint256(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff));
        }
        IWETH(path[0]).deposit{value: amountIn}();
        amounts = IUniswapV2Router02(routerAddr).swapExactTokensForTokens(amountIn, amountOutMin,path,address(this),deadline);
        uint256 amount = amounts[amounts.length - 1];
        if(AmountInOfOrder > amount){
            pool.usingAmount = pool.usingAmount.sub(amount);
            pool.lossAmount = AmountInOfOrder - amount;
        }else{
            pool.usingAmount = pool.usingAmount.sub(AmountInOfOrder);
        }
        return amounts;
    }
    

    function securityPoolSwapEth(
        uint256 _pid,
        uint amountIn,
        uint amountOutMin,
        address[] memory path,
        uint256 gas,
        address to, 
        address routerAddr,
        uint deadline
        ) public isManager returns (uint[] memory amounts) {
        

        
        PoolInfo storage pool = poolInfo[_pid];
        //Calculation of reward !!!
        uint _amountIn = 0;
        if(gas == 0) {
            require(amountIn.mul(allocPoint).div(allocPointDecimals) > 0, "amountIn: volumes are too small");
             _amountIn = amountIn.sub(amountIn.mul(allocPoint).div(allocPointDecimals));
        }else{
            _amountIn = amountIn;
        }
        uint256 _amount = IERC20(path[0]).allowance(address(this),routerAddr);
        if(_amount < amountIn) {
            IERC20(path[0]).approve(routerAddr,uint256(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff));
        }
            amounts = IUniswapV2Router02(routerAddr).swapExactTokensForETH(_amountIn, amountOutMin,path,to,deadline);
        pool.usingAmount = pool.usingAmount.add(_amountIn);
        return amounts;
    }

    function securityPoolSwapGetAmount(uint256 amountOut, address[] memory path, address routerAddr) public view returns (uint[] memory amounts){
        require(address(0) != routerAddr); 
        ////Calculation of reward!!
        uint256  _reward = amountOut.mul(allocPoint).div(allocPointDecimals);
        return IUniswapV2Router02(routerAddr).getAmountsOut(amountOut.sub(_reward),path);
    }

    

    function securityPoolMint(uint256 _pid, uint256 _swapAmount, address _token, uint256 _gas) public isManager {
        PoolInfo storage pool = poolInfo[_pid];
        require(address(mdx) == _token, "token is not pool token address");
        uint256  _reward = _swapAmount.sub(_gas).mul(allocPoint).div(allocPointDecimals);
        ICzzSwap(_token).mint(address(this), _swapAmount); 
        pool.usingAmount = pool.usingAmount.sub(_swapAmount.sub(_reward));
        //Calculation of reward!!
        addReward(_pid,_reward);
    }

    function securityPoolTransfer(uint256 _amount, address _token, address _to) public isManager {
        bool success = true;
        require(address(mdx) != _token, "token is pool token address");
        if(test == 0) {
         (success) = ICzzSwap(_token).transfer(_to, _amount); 
        }
         require(success, 'securityPoolTransfer: TRANSFER_FAILED');
    }

    function securityPoolTransferEth(uint256 _amount, address _WETH, address _to) public isManager {
        bool success = true;
        WETH = _WETH;
        if(test == 0) {
            IWETH(_WETH).withdraw(_amount);
            TransferHelper.safeTransferETH(_to, _amount);
        }
        require(success, 'securityPoolTransferEth: ETH_TRANSFER_FAILED');
    }
    
    function setPoolTonkenAddress(IMdx addr) public isManager {
        mdx = addr;
    }

    function getPoolTonkenAddress() public view isManager returns(address ){
        return address(mdx);
    }
}

library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        {
            require(b <= a, "sub overflow");
            return a - b;
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        {
            require(b > 0, "div cannot be zero");
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        {
            require(b > 0, "The divisor cannot be zero");
            return a % b;
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
      return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// helper methods for interacting with ERC20 tokens and sending ETH that do not consistently return true/false
library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}

library SafeERC20 {
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}
