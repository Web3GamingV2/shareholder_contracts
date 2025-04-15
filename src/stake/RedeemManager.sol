// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../interface/ITreasuryPool.sol";
import "../core/PATStorage.sol";
import "../interface/IRedeemManager.sol";

/**
 * @title RedeemManager
 * @dev 管理赎回请求的合约，负责处理跨链赎回操作
 */
contract RedeemManager is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    IRedeemManager
{
    
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
        uint256 interestPortion
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
    ) external onlyTreasuryPool returns (bytes32) {
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
     */
    function confirmRedemptionSuccess(bytes32 _requestId) external onlyOwner nonReentrant {
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
            redemption.interestPortion
        );
    }
    
    /**
     * @dev 确认赎回失败 - 由业务系统回调
     * @param _requestId 请求ID
     */
    function confirmRedemptionFailure(bytes32 _requestId) external onlyOwner nonReentrant {
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
            redemption.interestPortion,
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
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {
    }
}