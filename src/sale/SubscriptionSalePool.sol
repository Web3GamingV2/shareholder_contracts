// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./SubscriptionSalePoolStorage.sol";
import "../interface/ISubscriptionSalePool.sol"; // 引入接口定义
// import "../core/PATStorage.sol"; // 引入 PoolType
import "../interface/IVestingFactory.sol";


/**
 * @title 申购销售池
 * @dev 管理用户申购PAT代币的记录，处理付款和后续的代币锁仓流程。
 */
contract SubscriptionSalePool is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    SubscriptionSalePoolStorage,
    ISubscriptionSalePool // 实现接口
{
    // --- 事件 ---
    event SubscriptionCreated(
        uint256 indexed subscriptionId,
        address indexed subscriber,
        uint256 patAmount,
        uint256 usdtAmount,
        uint8 tier,
        uint64 expiryTimestamp
    );
    event SubscriptionConfirmed(uint256 indexed subscriptionId, address indexed subscriber, address vestingWallet);
    event SubscriptionExpired(uint256 indexed subscriptionId, address indexed subscriber);
    event SubscriptionCancelled(uint256 indexed subscriptionId, address indexed subscriber);
    event SubscriptionUsdtReceived(uint256 indexed subscriptionId, address indexed subscriber, uint256 usdtAmount);

    // --- 修饰符 ---
    modifier onlyInvestorSalePool() {
        require(msg.sender == investorSalePoolAddress, "Caller is not the InvestorSalePool");
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
        address _investorSalePoolAddress,
        address _vestingFactory,
        uint256 _subscriptionDuration // 例如 3600
    ) public initializer {
        __Ownable_init(_owner);
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        __SubscriptionSalePoolStorage_init(
            _patToken,
            _usdtToken,
            _investorSalePoolAddress,
            _vestingFactory,
            _subscriptionDuration
        );
    }

    /**
     * @dev 创建一个新的申购记录 (由 InvestorSalePool 调用)
     * @param _subscriber 申购人地址
     * @param _patAmount 申购的PAT数量
     * @param _usdtAmount 需要支付的USDT数量
     * @param _tier 对应的投资者等级
     * @return expiryTimestamp 申购记录的过期时间戳
     */
    function createSubscription(
        address _subscriber,
        uint256 _patAmount,
        uint256 _usdtAmount,
        uint8 _tier
    )
        external
        override
        onlyInvestorSalePool
        whenNotPaused
        nonReentrant
        returns (uint256 expiryTimestamp)
    {
        require(_subscriber != address(0), "Invalid subscriber address");
        require(_patAmount > 0, "PAT amount must be positive");
        require(_usdtAmount > 0, "USDT amount must be positive");
        // 可以添加检查，例如一个用户是否已有待处理的申购
        // require(pendingSubscriptionIdByUser[_subscriber] == 0, "User already has a pending subscription");

        // 从 InvestorSalePool 合约转移 PAT 到本合约
        // InvestorSalePool 需要先 approve 本合约地址
        patToken.transferFrom(msg.sender, address(this), _patAmount);

        uint256 currentId = nextSubscriptionId;
        uint64 creationTime = uint64(block.timestamp);
        uint64 expiryTime = creationTime + uint64(subscriptionDuration);

        Subscription memory newSubscription = Subscription({
            id: currentId,
            subscriber: _subscriber,
            patAmount: _patAmount,
            usdtAmount: _usdtAmount,
            tier: _tier,
            creationTimestamp: creationTime,
            expiryTimestamp: expiryTime,
            status: SubscriptionStatus.PENDING,
            vestingWallet: address(0), // 初始为空
            usdtReceived: false
        });

        subscriptions[currentId] = newSubscription;
        userSubscriptionIds[_subscriber].push(currentId);
        // pendingSubscriptionIdByUser[_subscriber] = currentId; // 如果需要限制

        nextSubscriptionId++;

        emit SubscriptionCreated(currentId, _subscriber, _patAmount, _usdtAmount, _tier, expiryTime);

        return uint256(expiryTime);
    }

    /**
     * @dev 用户取消未付款的申购
     * @param _subscriptionId 要取消的申购ID
     */
    function cancelSubscription(uint256 _subscriptionId) external whenNotPaused nonReentrant {
        Subscription storage sub = subscriptions[_subscriptionId];

        require(sub.id != 0, "Subscription not found");
        require(sub.subscriber == msg.sender, "Caller is not the subscriber");
        require(sub.status == SubscriptionStatus.PENDING, "Subscription not pending");
        // 过期后不能主动取消，应由清理机制处理
        require(block.timestamp <= sub.expiryTimestamp, "Subscription expired, cannot cancel");

        // 将预存的PAT退还给 InvestorSalePool
        patToken.transfer(investorSalePoolAddress, sub.patAmount);

        // 更新状态
        sub.status = SubscriptionStatus.CANCELLED;
        // delete pendingSubscriptionIdByUser[msg.sender]; // 如果使用了限制

        emit SubscriptionCancelled(_subscriptionId, msg.sender);
    }

    /**
     * @dev 清理过期的申购记录 (任何人可以调用，或由 Keeper 调用)
     * @param _subscriptionId 要清理的申购ID
     */
    function cleanupExpiredSubscription(uint256 _subscriptionId) external whenNotPaused nonReentrant {
         Subscription storage sub = subscriptions[_subscriptionId];

        require(sub.id != 0, "Subscription not found");
        require(sub.status == SubscriptionStatus.PENDING, "Subscription not pending or already handled");
        require(block.timestamp > sub.expiryTimestamp, "Subscription not expired yet");

        // 将预存的PAT退还给 InvestorSalePool
        patToken.transfer(investorSalePoolAddress, sub.patAmount);

        // 更新状态
        sub.status = SubscriptionStatus.EXPIRED;
        // delete pendingSubscriptionIdByUser[sub.subscriber]; // 如果使用了限制

        emit SubscriptionExpired(_subscriptionId, sub.subscriber);
    }


    /**
     * @notice 调用此函数前，用户必须先 approve 本合约地址足额的 USDT
     * @param _subscriptionId 用户的申购ID
     */
    function confirmSubscription(uint256 _subscriptionId) external onlyInvestorSalePool() whenNotPaused nonReentrant returns(
        address _subscriber,
        uint256 _patAmount,
        uint256 _usdtAmount,
        uint8 _tier,
        address _vestingWallet
    ) {
        Subscription storage sub = subscriptions[_subscriptionId];

        require(sub.id != 0, "Subscription not found");
        require(sub.subscriber == msg.sender, "Caller is not the subscriber");
        require(sub.status == SubscriptionStatus.PENDING, "Subscription not pending");
        require(block.timestamp <= sub.expiryTimestamp, "Subscription expired");
        require(!sub.usdtReceived, "USDT already received for this subscription");

        // 2. 标记 USDT 已收到
        sub.usdtReceived = true;
        emit SubscriptionUsdtReceived(_subscriptionId, msg.sender, sub.usdtAmount);

        // 3. 创建锁仓合约
        // 注意：vestingFactory 的 createVestingWallet 函数签名需要匹配
        // 这里假设了一个简单的签名，实际需要根据 VestingFactory 合约调整
        uint64 currentVestingStartTime = uint64(block.timestamp);
        address newVestingWallet = IVestingFactory(vestingFactory).createVestingWallet(
            sub.subscriber,
            sub.patAmount,
            currentVestingStartTime
            // 可能需要传入 tier 或其他参数来确定锁仓计划
        );
        require(newVestingWallet != address(0), "Vesting wallet creation failed");

        // 4. 将 PAT 转入锁仓合约
        // 此时 PAT 应该在本合约地址 (在 createSubscription 时转入)
        patToken.transfer(newVestingWallet, sub.patAmount);

        // 5. 更新申购状态和信息
        sub.vestingWallet = newVestingWallet;
        sub.status = SubscriptionStatus.CONFIRMED;
        // delete pendingSubscriptionIdByUser[msg.sender]; // 如果使用了限制

        emit SubscriptionConfirmed(_subscriptionId, msg.sender, newVestingWallet);

        return (
            sub.subscriber,
            sub.patAmount,
            sub.usdtAmount,
            sub.tier,
            sub.vestingWallet
        );
    }

    // --- Getter 函数 ---
    function getSubscription(uint256 _subscriptionId) external view returns (Subscription memory) {
        return subscriptions[_subscriptionId];
    }

    function getUserSubscriptionIds(address _user) external view returns (uint256[] memory) {
        return userSubscriptionIds[_user];
    }

    // --- 管理功能 ---
    function setSubscriptionDuration(uint256 _newDuration) external onlyOwner() {
        require(_newDuration > 0, "Duration must be positive");
        subscriptionDuration = _newDuration;
    }

    function pause() external onlyOwner() {
        _pause();
    }

    function unpause() external onlyOwner() {
        _unpause();
    }

    // 允许管理员提取意外发送到合约的PAT (例如清理失败的)
    function withdrawStuckPAT(address _to, uint256 _amount) external onlyOwner() {
        require(_to != address(0), "Invalid recipient");
        uint256 balance = patToken.balanceOf(address(this));
        require(_amount <= balance, "Insufficient balance");
        patToken.transfer(_to, _amount);
    }


    // --- UUPS Upgrade ---
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

}