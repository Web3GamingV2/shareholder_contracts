// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interface/IPAT.sol";
import "../interface/ITreasuryPool.sol";
import "../interface/IRedeemManager.sol";
import "../interface/IPATLayerZeroBridge.sol";
import "./TreasuryPoolStorage.sol";
import "../core/PATStorage.sol";

/**
 * @title TreasuryPool
 * @dev 资金池合约，负责管理USDT和PAT代币，以及计算利息 通过这个池子把 USDT 转入 polygon 网络 但是赎回逻辑需要从 tron 那边做
 */
contract TreasuryPool is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    TreasuryPoolStorage,
    ITreasuryPool {
    
    using SafeERC20 for IERC20;
    using SafeERC20 for IPATInterface;

        // 修饰符
    modifier onlyMultiSigOrOwner() {
        require(msg.sender == multiSigWallet || msg.sender == owner(), "Not multisig or owner");
        _;
    }
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _owner,
        address _patToken,
        address _paxToken,
        address _usdtToken,
        address _multiSigWallet,
        address _vestingFactory,
        address _redeemManager
    ) public initializer {
        __Ownable_init(_owner);
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        __TreasuryPoolStorage_init(
            _patToken,
            _paxToken,
            _usdtToken,
            _vestingFactory,
            _multiSigWallet,
            _redeemManager
        );
    }

    /**
     * @dev 存入 USDT 子合约池调用
     * @param _user 用户地址
     * @param _usdtAmount USDT金额
     * @param _patAmount PAT金额 
     */
    function depositUSDT(
        PATStorage.PoolType _userType,
        address _user,
        uint256 _usdtAmount,
        uint256 _patAmount
    ) external override whenNotPaused nonReentrant {
        require(_user != address(0), "Invalid user address");
        require(_usdtAmount > 0, "Invalid USDT amount");
        require(_patAmount > 0, "Invalid PAT amount");
        require(poolTypes[msg.sender] == _userType, "Invalid pool type");

        // 存入USDT
        IERC20(usdtCoin).safeTransferFrom(msg.sender, address(this), _usdtAmount);

        // 创建新的存款记录
        Deposit memory newDeposit = Deposit({
            usdtAmount: _usdtAmount,
            patAmount: _patAmount,
            timestamp: uint64(block.timestamp),
            sourcePool: msg.sender,
            userType: _userType
        });

        // 更新用户余额
        userBalances[_user].deposits.push(newDeposit);
        userBalances[_user].patAmount = userBalances[_user].patAmount + _patAmount;
        userBalances[_user].lastInterestTime = uint64(block.timestamp);

        // 更新总余额
        totalUsdtBalance = totalUsdtBalance + _usdtAmount;
        totalPatBalances[_userType] = totalPatBalances[_userType] + _patAmount;

        // 触发事件
        emit USDTDeposited(
            _user,
            msg.sender,
            _userType,
            _usdtAmount,
            _patAmount,
            userBalances[_user].deposits.length - 1
        );

    }

    /**
     * @dev 获取用户PAT余额
     * @param _user 用户地址
     * @return balance PAT余额
     * 计算分红
     */
    function calculateDividend(address _user) public view override returns (uint256) {
        if (userBalances[_user].patAmount == 0 || userBalances[_user].lastInterestTime == 0) {
            return 0;
        }
         // 计算自上次计息以来的天数(秒)
        uint256 timeElapsed = block.timestamp - userBalances[_user].lastInterestTime;
        // 将时间转换为天数
        uint256 daysElapsed = timeElapsed / SECONDS_PER_DAY;
        
        if (daysElapsed == 0) {
            return 0;
        }

        // 计算利息
        // 假如用户有 100 PAT , 利息 = 100 *  3 * daysElapsed / 1000
        // 按照 0.003 给利息
        uint256 interestAmount = userBalances[_user].patAmount
        * DAILY_INTEREST_RATE
        * daysElapsed
        / INTEREST_RATE_DENOMINATOR;

        return interestAmount;
    }

    /**
    * @dev 用户将PAX兑换为PAT
    * @param _amount 要兑换的PAX数量
    * @return 兑换成功的PAT数量
    */
    function exchangePaxForPat(address _user, uint256 _amount) external nonReentrant whenNotPaused returns (uint256) {
        require(_amount > 0, "Amount must be > 0");
        
        // 检查用户PAX余额
        uint256 paxBalance = paxCoin.balanceOf(_user);
        require(paxBalance >= _amount, "Insufficient PAX balance");
        
        // 销毁用户的PAX
        paxCoin.burn(_user, _amount);
        
        // 转移相应数量的PAT给用户
        patCoin.safeTransfer(_user, _amount);
        
        emit PaxExchangedForPat(msg.sender, _amount);
        
        return _amount;
    }

     /**
     * @dev 用户领取 PAX 分红
     * @return 领取的分红金额
     */
    function claimDividend(address _user) external nonReentrant whenNotPaused returns (uint256) {
        uint256 dividendAmount = calculateDividend(_user);
        require(dividendAmount > 0, "No dividend to claim");
        
        // 更新上次计息时间
        userBalances[_user].lastInterestTime = block.timestamp;
        
        // 铸造 PAX 给用户
        paxCoin.mint(_user, dividendAmount);
        
        emit DividendClaimed(msg.sender, dividendAmount);
        
        return dividendAmount;
    }

    /**
     * @dev 获取用户可领取的分红
     * @param _user 用户地址
     * @return dividend 可领取的分红
     */
    function getUserDividend(address _user) external view returns (uint256) {
        return calculateDividend(_user);
    }

    /**
     * @dev 获取用户PAT余额
     * @param _user 用户地址
     * @return balance PAT余额
     */
    function getUserPatBalance(address _user) external view override returns (uint256) {
        return userBalances[_user].patAmount;
    }
    
    /**
     * @dev 获取用户的存款记录
     * @param _user 用户地址
     */
    function calculateRedemptionAmount (address _user, uint256 _patAmount) public view override returns (uint256) {
       require(_patAmount > 0, "PAT amount must be > 0");
       require(userBalances[_user].patAmount >= _patAmount, "Insufficient PAT balance");
        
        // 总赎回金额 = PAT金额（不再包含利息部分）
        return _patAmount;
    }

      /**
     * @dev 赎回PAT为USDT
     * @param _user 用户地址
     * @param _patAmount PAT金额
     * @param _usdtAmount USDT金额
     * PAT --> USDT
     * TODO 要考虑用户从哪个合约池赎回哪一笔充值
     * TODO 前置合约调用要区分锁仓合约信息
     */
    function redeemPAT (
        address _user, 
        uint256 _patAmount, 
        uint256 _usdtAmount) public override nonReentrant whenNotPaused returns (uint256, bytes32) {
        require(_user != address(0), "Invalid user address");
        require(_patAmount > 0, "PAT amount must be > 0");
        require(_usdtAmount > 0, "USDT amount must be > 0");
        require(userBalances[_user].patAmount >= _patAmount, "Insufficient PAT balance");
        require(totalUsdtBalance >= _usdtAmount, "Insufficient USDT in pool");

         // 验证调用者是否是用户的存款来源
        bool isValidSource = false;
        PATStorage.PoolType userType;

        // 遍历用户的存款记录
        for (uint256 i = 0; i < userBalances[_user].deposits.length; i++) {
            // 当前的user可以从多个子合约池注入资金
            // 但是赎回逻辑只能由一个子合约池调用
            // 从当前的 user 的充值记录中找到这个 子合约池
            // 这里要求他从哪个池子进来再从哪个池子赎回
            if (userBalances[_user].deposits[i].sourcePool == msg.sender) {
                isValidSource = true;
                userType = userBalances[_user].deposits[i].userType;
                break;
            }
        }
        
        require(isValidSource, "Not the source pool");

        // 更新用户PAT余额
        userBalances[_user].patAmount = userBalances[_user].patAmount - _patAmount;
        totalPatBalances[userType] = totalPatBalances[userType] - _patAmount;
        
        // 更新总USDT余额
        totalUsdtBalance = totalUsdtBalance - _usdtAmount;

        // 创建赎回请求
        bytes32 requestId = IRedeemManager(redeemManager).createRedemptionRequest(
            _user,
            _patAmount,
            _usdtAmount,
            0,
            userType,
            msg.sender
        );

        return (_usdtAmount, requestId);
        
    }

    // 添加恢复用户余额的函数
    function restoreUserBalance(
        address _user,
        uint256 _patAmount,
        uint256 _usdtAmount,
        PATStorage.PoolType _userType
    ) external override {
        require(msg.sender == redeemManager, "Only RedeemManager can call");
        
        // 恢复用户PAT余额
        userBalances[_user].patAmount = userBalances[_user].patAmount + _patAmount;
        totalPatBalances[_userType] = totalPatBalances[_userType] + _patAmount;
        
        // 恢复总USDT余额
        totalUsdtBalance = totalUsdtBalance + _usdtAmount;
    }


     /**
     * @dev 提取剩余USDT（仅限多签钱包）
     * @param _to 接收地址
     * @param _amount USDT金额
     */
    function withdrawUSDT(address _to, uint256 _amount) external override onlyMultiSigOrOwner nonReentrant {
        require(_to != address(0), "Invalid address");
        require(_amount > 0, "Amount must be > 0");
        require(totalUsdtBalance >= _amount, "Insufficient balance");
        
        totalUsdtBalance = totalUsdtBalance - _amount;
        // 从当前合约中提取USDT
        usdtCoin.safeTransfer(_to, _amount);
        
        emit USDTWithdrawn(_to, _amount, msg.sender, block.timestamp);
    }

       /**
     * @dev 获取用户存款数量
     * @param _user 用户地址
     * @return 存款数量
     */
    function getUserDepositCount(address _user) external view override returns (uint256) {
        return userBalances[_user].deposits.length;
    }
    
    /**
     * @dev 获取用户存款信息
     * @param _user 用户地址
     * @param _index 存款索引
     * @return patAmount PAT金额
     * @return usdtAmount USDT金额
     * @return timestamp 存款时间
     * @return sourcePool 来源池地址
     * @return userType 用户类型
     */
    function getUserDeposit(address _user, uint256 _index) external view override returns (
        uint256 patAmount,
        uint256 usdtAmount,
        uint256 timestamp,
        address sourcePool,
        PATStorage.PoolType userType
    ) {
        require(_index < userBalances[_user].deposits.length, "Invalid deposit index");
        Deposit storage deposit = userBalances[_user].deposits[_index];
        return (
            deposit.patAmount,
            deposit.usdtAmount,
            deposit.timestamp,
            deposit.sourcePool,
            deposit.userType
        );
    }
    
    /**
     * @dev 获取特定类型的总PAT余额
     * @param _userType 用户类型
     * @return 总PAT余额
     */
    function getTotalPatBalance(PATStorage.PoolType _userType) external view override returns (uint256) {
        return totalPatBalances[_userType];
    }


    function pause() external onlyOwner {
        _pause();
    }  
    function unpause() external onlyOwner {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {
    }


}