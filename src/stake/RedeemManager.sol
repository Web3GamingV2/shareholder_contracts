// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import "../interface/ITreasuryPool.sol";
import "../core/PATStorage.sol";
import "../interface/IRedeemManager.sol";

/**
 * TODO: 暂时用不上了 直接从 polygon 的 Redeem 中赎回
 * @title RedeemManager
 * @dev 管理赎回请求的合约，负责处理跨链赎回操作
    initiateCrossChainRedemption 方法的调用场景主要在以下情况下：
    当用户在EVM链上发起PAT代币赎回请求后，系统需要在TRON链上为用户提供相应的USDT。这个方法是连接EVM链和TRON链的关键环节。
    具体调用场景如下：
    1. 用户通过前端界面或直接调用合约发起PAT赎回请求
    2. TreasuryPool合约调用RedeemManager的 createRedemptionRequest 方法创建赎回请求
    3. 后端系统监听到 RedemptionRequested 事件
    4. 后端系统（或管理员）调用 initiateCrossChainRedemption 方法，传入：
    - 赎回请求ID
    - 用户的TRON地址（如果用户之前没有设置过）
    调用此方法后，会触发 CrossChainRedemptionInitiated 事件，后端系统会监听此事件并在TRON链上执行以下操作：

    - 在TRON链上的锚定池中发起USDT提款请求
    - 多签所有者确认提款请求
    - USDT成功转账给用户后，调用 confirmRedemptionSuccess 方法确认赎回成功
    这个方法是整个跨链赎回流程中的重要一环，它将EVM链上的赎回请求与TRON链上的USDT提款请求关联起
 */
contract RedeemManager is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    IRedeemManager
{

    // 用户的TRON地址映射
    mapping(address => string) public userTronAddresses;
    
    // 锁定的赎回信息结构体
    struct LockedRedemption {
        address user;                  // 用户地址
        uint256 patAmount;             // PAT金额
        uint256 usdtAmount;            // USDT金额
        uint256 interestPortion;       // 利息部分
        PATStorage.PoolType userType;  // 用户类型
        address sourcePool;            // 来源池
        uint256 timestamp;             // 时间戳
        IRedeemManager.RedemptionStatus status;       // 状态
    }

    // 添加跨链提款相关的事件
    event CrossChainRedemptionInitiated(
        bytes32 indexed requestId,
        address indexed user,
        uint256 usdtAmount,
        string tronAddress
    );

    
    // 事件定义
    event RedemptionRequested(
        bytes32 indexed requestId,
        address indexed user,
        address indexed sourcePool,
        PATStorage.PoolType userType,
        uint256 patAmount,
        uint256 usdtAmount,
        uint256 interestPortion
    );
    
    event RedemptionConfirmed(
        bytes32 indexed requestId,
        address indexed user,
        address indexed sourcePool,
        PATStorage.PoolType userType,
        uint256 patAmount,
        uint256 usdtAmount,
        uint256 interestPortion,
        string tronTxHash
    );
    
    event RedemptionFailed(
        bytes32 indexed requestId,
        address indexed user,
        uint256 patAmount,
        uint256 usdtAmount
    );
    
    // TreasuryPool合约地址
    address public treasuryPool;
    
    // 请求ID计数器
    uint256 private requestNonce;
    
    // 锁定余额映射
    mapping(bytes32 => LockedRedemption) public lockedRedemptions;
    
    // 修饰符：只允许TreasuryPool调用
    modifier onlyTreasuryPool() {
        require(msg.sender == treasuryPool, "Only TreasuryPool can call");
        _;
    }
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(address _owner, address _treasuryPool) public initializer {
        __Ownable_init(_owner);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        __Pausable_init();
        treasuryPool = _treasuryPool;
    }
    
    /**
     * @dev 设置TreasuryPool地址
     * @param _treasuryPool TreasuryPool地址
     */
    function setTreasuryPool(address _treasuryPool) external onlyOwner {
        require(_treasuryPool != address(0), "Invalid TreasuryPool address");
        treasuryPool = _treasuryPool;
    }
    
    /**
    * @dev 初始化跨链赎回请求
    * @param _requestId 赎回请求ID
    * @param _tronAddress 用户的TRON地址
    */
    function initiateCrossChainRedemption(bytes32 _requestId, string calldata _tronAddress) external onlyOwner whenNotPaused() nonReentrant {

        LockedRedemption storage redemption = lockedRedemptions[_requestId];
        require(redemption.user != address(0), "Invalid request ID");
        require(redemption.status == RedemptionStatus.PENDING, "Request not pending");
        
        // 如果提供了TRON地址，则更新用户的TRON地址
        if (bytes(_tronAddress).length > 0) {
            userTronAddresses[redemption.user] = _tronAddress;
        }
        
        // 确保用户有TRON地址
        string memory userTronAddr = userTronAddresses[redemption.user];
        require(bytes(userTronAddr).length > 0, "User TRON address not set");
        
        // 触发跨链赎回事件，后端监听此事件并在TRON链上执行转账
        emit CrossChainRedemptionInitiated(
            _requestId,
            redemption.user,
            redemption.usdtAmount,
            userTronAddr
        );
    }
    
    /**
     * @dev 创建赎回请求
     * @param _user 用户地址
     * @param _patAmount PAT金额
     * @param _usdtAmount USDT金额
     * @param _interestPortion 利息部分
     * @param _userType 用户类型
     * @param _sourcePool 来源池
     * @return requestId 请求ID
     */
    function createRedemptionRequest(
        address _user,
        uint256 _patAmount,
        uint256 _usdtAmount,
        uint256 _interestPortion,
        PATStorage.PoolType _userType,
        address _sourcePool
    ) external onlyTreasuryPool whenNotPaused() returns (bytes32) {
        // 生成唯一请求ID
        bytes32 requestId = keccak256(abi.encodePacked(_user, _patAmount, _usdtAmount, block.timestamp, requestNonce));
        requestNonce++;
        
        // 记录锁定的赎回信息
        lockedRedemptions[requestId] = LockedRedemption({
            user: _user,
            patAmount: _patAmount,
            usdtAmount: _usdtAmount,
            interestPortion: _interestPortion,
            userType: _userType,
            sourcePool: _sourcePool,
            timestamp: block.timestamp,
            status: RedemptionStatus.PENDING
        });
        
        // 触发事件
        emit RedemptionRequested(
            requestId,
            _user,
            _sourcePool,
            _userType,
            _patAmount,
            _usdtAmount,
            _interestPortion
        );
        
        return requestId;
    }
    
    /**
     * @dev 确认赎回成功 - 由业务系统回调
     * @param _requestId 请求ID
     * @param _txHash TRON链上的交易哈希（可选）
     */
    function confirmRedemptionSuccess(bytes32 _requestId, string calldata _txHash) external onlyOwner whenNotPaused() nonReentrant {
        LockedRedemption storage redemption = lockedRedemptions[_requestId];
        require(redemption.user != address(0), "Invalid request ID");
        require(redemption.status == RedemptionStatus.PENDING, "Request not pending");
        
        // 更新状态为已完成
        redemption.status = RedemptionStatus.COMPLETED;
        
        // 触发成功事件
        emit RedemptionConfirmed(
            _requestId,
            redemption.user,
            redemption.sourcePool,
            redemption.userType,
            redemption.patAmount,
            redemption.usdtAmount,
            redemption.interestPortion,
            _txHash
        );
    }
    
    /**
     * @dev 确认赎回失败 - 由业务系统回调
     * @param _requestId 请求ID
     */
    function confirmRedemptionFailure(bytes32 _requestId) external onlyOwner whenNotPaused() nonReentrant {
        LockedRedemption storage redemption = lockedRedemptions[_requestId];
        require(redemption.user != address(0), "Invalid request ID");
        require(redemption.status == RedemptionStatus.PENDING, "Request not pending");
        
        // 更新状态为失败
        redemption.status = RedemptionStatus.FAILED;
        
        // 调用TreasuryPool恢复用户余额
        ITreasuryPool(treasuryPool).restoreUserBalance(
            redemption.user,
            redemption.patAmount,
            redemption.usdtAmount,
            redemption.userType
        );
        
        // 触发失败事件
        emit RedemptionFailed(
            _requestId,
            redemption.user,
            redemption.patAmount,
            redemption.usdtAmount
        );
    }
    
    /**
     * @dev 获取赎回请求状态
     * @param _requestId 请求ID
     * @return 请求状态
     */
    function getRedemptionStatus(bytes32 _requestId) external view returns (RedemptionStatus) {
        return lockedRedemptions[_requestId].status;
    }
    
    /**
     * @dev 获取赎回请求详情
     * @param _requestId 请求ID
     * @return user 用户地址
     * @return patAmount PAT金额
     * @return usdtAmount USDT金额
     * @return status 状态
     */
    function getRedemptionDetails(bytes32 _requestId) external view returns (
        address user,
        uint256 patAmount,
        uint256 usdtAmount,
        RedemptionStatus status
    ) {
        LockedRedemption storage redemption = lockedRedemptions[_requestId];
        return (
            redemption.user,
            redemption.patAmount,
            redemption.usdtAmount,
            redemption.status
        );
    }

    /**
    * @dev 设置用户的TRON地址
    * @param _user 用户地址
    * @param _tronAddress TRON地址
    */
    function setUserTronAddress(address _user, string calldata _tronAddress) external {
        // 只允许用户自己或管理员设置
        require(msg.sender == _user || msg.sender == owner(), "Not authorized");
        userTronAddresses[_user] = _tronAddress;
    }
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {
    }

    function pause() external onlyOwner {
        _pause();
    }  
    function unpause() external onlyOwner {
        _unpause();
    }
}