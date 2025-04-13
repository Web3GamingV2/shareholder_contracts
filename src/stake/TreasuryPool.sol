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
    
    modifier onlyAuthorizedPool() {
        require(authorizedPools[msg.sender], "Not authorized pool");
        _;
    }
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _owner,
        address _patToken,
        address _usdtToken,
        address _multiSigWallet,
        address _vestingFactory,
        address _polygonConnector
    ) public initializer {
        __Ownable_init(_owner);
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        __TreasuryPoolStorage_init(
            _patToken,
            _usdtToken,
            _vestingFactory,
            _polygonConnector,
            _multiSigWallet
        );
    }

    /**
     * @dev 存入USDT 子合约池调用
     * @param _user 用户地址
     * @param _usdtAmount USDT金额
     * @param _patAmount PAT金额 
     */
    function depositUSDT(
        PATStorage.PoolType _userType,
        address _user,
        uint256 _usdtAmount,
        uint256 _patAmount
    ) external override whenNotPaused nonReentrant onlyAuthorizedPool {
        require(_user != address(0), "Invalid user address");
        require(_usdtAmount > 0, "Invalid USDT amount");
        require(_patAmount > 0, "Invalid PAT amount");
        require(poolTypes[msg.sender] == _userType, "Invalid pool type");

        // 存入USDT
        IERC20(usdtCoin).safeTransferFrom(msg.sender, address(this), _usdtAmount);

        // 如果用户已有余额，先计算之前的利息
        if (userBalances[_user].patAmount > 0 && userBalances[_user].lastInterestTime > 0) {
            uint256 newInterest = calculateInterest(_user);
            userBalances[_user].interest = userBalances[_user].interest + newInterest;
            totalInterests[_userType] = totalInterests[_userType] + newInterest;
        }
        
        // 创建新的存款记录
        // TODO 这个地方意义不大 考虑离链处理 记录必要信息即可
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
        // 更新总利息
        totalInterests[_userType] = totalInterests[_userType] + calculateInterest(_user);

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
     */
    function calculateInterest(address _user) public view override returns (uint256) {
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

    function updateInterest (address _user) public override nonReentrant whenNotPaused returns (uint256) {
        uint256 interestAmount = calculateInterest(_user);
        
        if (interestAmount == 0) {
            return 0;
        }

        // 确定用户类型（使用第一笔存款的类型）
        PATStorage.PoolType userType;
        if (userBalances[_user].deposits.length > 0) {
            userType = userBalances[_user].deposits[0].userType;
        } else {
            return 0; // 没有存款记录，不更新利息
        }

         // 更新上次计息时间
        userBalances[_user].lastInterestTime = block.timestamp;

         // 更新用户利息
        userBalances[_user].interest = userBalances[_user].interest + interestAmount;
        // 更新总利息
        totalInterests[userType] = totalInterests[userType] + interestAmount;

        // 触发事件
        emit InterestCalculated(_user, userBalances[_user].patAmount, interestAmount, block.timestamp);

        return interestAmount;

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
     * @dev 获取用户累积利息
     * @param _user 用户地址
     * @return interest 累积利息
     */
    function getUserInterest(address _user) external view override returns (uint256) {
        return userBalances[_user].interest + calculateInterest(_user);
    }

    /**
     * @dev 获取用户的存款记录
     * @param _user 用户地址
     */
    function calculateRedemptionAmount (address _user, uint256 _patAmount) public view override returns (uint256) {
        require(_patAmount > 0, "PAT amount must be > 0");
        require(userBalances[_user].patAmount >= _patAmount, "Insufficient PAT balance");
        
        uint256 interestAmount = calculateInterest(_user);
         // 计算当前累积的利息
        uint256 currentInterest = userBalances[_user].interest + interestAmount;
        // 计算可赎回的利息比例
        uint256 interestPortion = 0;
        if (userBalances[_user].patAmount > 0) {
            interestPortion = currentInterest * _patAmount / userBalances[_user].patAmount;
        }
         // 总赎回金额 = PAT金额 + 利息部分
        return _patAmount + interestPortion;
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
    function redeemPAT (address _user, uint256 _patAmount, uint256 _usdtAmount) public override nonReentrant whenNotPaused returns (uint256) {
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
            if (userBalances[_user].deposits[i].sourcePool == msg.sender) {
                isValidSource = true;
                userType = userBalances[_user].deposits[i].userType;
                break;
            }
        }
        
        require(isValidSource, "Not the source pool");

         // 先更新利息
        updateInterest(_user);
        
         // 计算可赎回的利息比例
        uint256 interestPortion = 0;
        if (userBalances[_user].patAmount > 0) {
            interestPortion = userBalances[_user].interest * _patAmount / userBalances[_user].patAmount;
        }

        // 更新用户PAT余额
        userBalances[_user].patAmount = userBalances[_user].patAmount - _patAmount;
        totalPatBalances[userType] = totalPatBalances[userType] - _patAmount;
        
        // 更新用户利息
        userBalances[_user].interest = userBalances[_user].interest - interestPortion;
        totalInterests[userType] = totalInterests[userType] - interestPortion;
        
        // 更新总USDT余额
        totalUsdtBalance = totalUsdtBalance - _usdtAmount;

         // 转移USDT给调用合约
        usdtCoin.safeTransfer(msg.sender, _usdtAmount);
        // 触发事件
         emit PATRedeemed(
            _user,
            msg.sender,
            userType,
            _patAmount,
            _usdtAmount,
            interestPortion
        );

        return _usdtAmount;
        
    }
    
    /**
     * @dev 授权子合约池
     * @param _pool 池地址
     * @param _userType 用户类型
     * @param _isAuthorized 是否授权
     */
    function authorizePool(
        address _pool,
        PATStorage.PoolType _userType,
        bool _isAuthorized
    ) external override onlyMultiSigOrOwner {
        require(_pool != address(0), "Invalid pool address");
        
        authorizedPools[_pool] = _isAuthorized;
        
        if (_isAuthorized) {
            poolTypes[_pool] = _userType;
        }
        
        emit PoolAuthorized(_pool, _userType, _isAuthorized);
    }
    
    /**
     * @dev 更新Polygon连接器
     * @param _newConnector 新连接器地址
     */
    function updatePolygonConnector(address _newConnector) external override onlyMultiSigOrOwner {
        require(_newConnector != address(0), "Invalid connector address");
        
        address oldConnector = address(polygonConnector);
        polygonConnector = IPATLayerZeroBridge(_newConnector);
        
        emit PolygonConnectorUpdated(oldConnector, _newConnector);
    }

    /**
     * @dev 将USDT转移到L2
     * @param _amount USDT金额
     */
    function transferUSDTToL2(uint256 _amount) external override onlyMultiSigOrOwner nonReentrant whenNotPaused {
        require(_amount > 0, "Amount must be > 0");
        require(totalUsdtBalance >= _amount, "Insufficient USDT balance");
        // 更新总USDT余额
        totalUsdtBalance = totalUsdtBalance - _amount;
        
        // 授权Polygon连接器使用USDT
        usdtCoin.approve(address(polygonConnector), _amount);
        
        // 调用Polygon连接器转移USDT到L2
        polygonConnector.bridgeTokensToL2(address(usdtCoin), _amount);
        
        // 重置授权
        usdtCoin.approve(address(polygonConnector), 0);
        
        emit USDTTransferredToL2(msg.sender, _amount, block.timestamp);
    }

    /**
     * @dev 接收从L2转移的USDT
     * @param _from 发送方地址
     * @param _amount USDT金额
     */
    function receiveUSDTFromL2(address _from, uint256 _amount) external override nonReentrant whenNotPaused {
        require(msg.sender == address(polygonConnector), "Only polygon connector can call");
        require(_amount > 0, "Amount must be > 0");
        
        // 更新总USDT余额
        totalUsdtBalance = totalUsdtBalance + _amount;
        
        emit USDTReceivedFromL2(_from, _amount, block.timestamp);
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
    
    /**
     * @dev 获取特定类型的总利息
     * @param _userType 用户类型
     * @return 总利息
     */
    function getTotalInterest(PATStorage.PoolType _userType) external view override returns (uint256) {
        return totalInterests[_userType];
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