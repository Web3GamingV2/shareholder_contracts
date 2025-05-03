// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./SubscriptionSalePoolStorage.sol";
import "../interface/ISubscriptionSalePool.sol"; // 引入接口定义
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
    ISubscriptionSalePool
{
    // --- 事件 ---
    event SubscriptionCreated(
        uint256 indexed subscriptionId,
        address indexed subscriber,
        uint256 patAmount,
        uint256 usdtAmount
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

    function version() external view virtual returns (string memory) {
        return "1.0.0";
    }

    /**
     * @dev 创建一个新的申购记录 (由 InvestorSalePool 调用)
     * @param _subscriber 申购人地址
     * @param _patAmount 申购的PAT数量
     * @param _usdtAmount 需要支付的USDT数量
     * @return expireTimestamp 申购记录的过期时间戳
     */
    function createSubscription(
        address _subscriber,
        uint256 _patAmount,
        uint256 _usdtAmount
    )
        external
        override
        onlyInvestorSalePool
        whenNotPaused
        nonReentrant
        returns (uint256 expireTimestamp)
    {
       // 只需要一个 require 来检查所有的前置条件
        require(_subscriber != address(0) && _patAmount > 0 && _usdtAmount > 0, "Invalid input values");

          // ---> 新增：检查用户是否已有活跃的申购 <---
        uint256 existingSubId = userActiveSubscriptionId[_subscriber];
        if (existingSubId != 0) {
            // 确保之前的申购不是 PENDING 状态
            require(subscriptionsMmutable[existingSubId].status != uint8(SubscriptionStatus.PENDING), "User already has an active subscription");
        }

        uint256 currentId = nextSubscriptionId;

        // 只进行一次结构体初始化，减少存储写操作
        Subscription memory newSubscription = Subscription({
            id: currentId,
            subscriber: _subscriber,
            patAmount: _patAmount,
            usdtAmount: _usdtAmount
        });

        SubscriptionMmutable memory newSubscriptionMmutable = SubscriptionMmutable({
            status: uint8(SubscriptionStatus.PENDING),
            vestingWallet: address(0)
        });
        // 写入存储
        subscriptions[currentId] = newSubscription;
        subscriptionsMmutable[currentId] = newSubscriptionMmutable;
        userActiveSubscriptionId[_subscriber] = currentId;

        unchecked {
            nextSubscriptionId++;
        }

        // 触发事件
        emit SubscriptionCreated(currentId, _subscriber, _patAmount, _usdtAmount);

        return uint256(block.timestamp) + subscriptionDuration;
    }

    /**
     * @dev 用户取消未付款的申购
     * @param _subscriptionId 要取消的申购ID
     */
    function cancelSubscription(uint256 _subscriptionId) external onlyInvestorSalePool() whenNotPaused nonReentrant {
        Subscription storage sub = subscriptions[_subscriptionId];
        SubscriptionMmutable storage subMmutable = subscriptionsMmutable[_subscriptionId];
        require(sub.id != 0 && subMmutable.status == uint8( SubscriptionStatus.PENDING), "Subscription not found");

        // 将预存的PAT退还给 InvestorSalePool
        patToken.transfer(investorSalePoolAddress, sub.patAmount);

        // 更新状态
        subMmutable.status = uint8(SubscriptionStatus.CANCELLED);

        userActiveSubscriptionId[sub.subscriber] = 0;

        emit SubscriptionCancelled(_subscriptionId, sub.subscriber);
    }

    /**
     * @dev 清理过期的申购记录 (任何人可以调用，或由 Keeper 调用)
     * @param _subscriptionId 要清理的申购ID
     */
    function cleanupExpiredSubscription(uint256 _subscriptionId) external onlyInvestorSalePool() whenNotPaused nonReentrant {
        Subscription storage sub = subscriptions[_subscriptionId];
        SubscriptionMmutable storage subMmutable = subscriptionsMmutable[_subscriptionId];
        require(sub.id != 0 && subMmutable.status == uint8(SubscriptionStatus.PENDING), "Subscription not found");

        // 将预存的PAT退还给 InvestorSalePool
        patToken.transfer(investorSalePoolAddress, sub.patAmount);

        // 更新状态
        subMmutable.status = uint8(SubscriptionStatus.EXPIRED);
        
        userActiveSubscriptionId[sub.subscriber] = 0;

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
        address _vestingWallet
    ) {
        Subscription storage sub = subscriptions[_subscriptionId];
        SubscriptionMmutable storage subMmutable = subscriptionsMmutable[_subscriptionId];
        require(sub.id != 0 && subMmutable.status == uint8(SubscriptionStatus.PENDING), "Subscription not found");
        emit SubscriptionUsdtReceived(_subscriptionId, _subscriber, sub.patAmount);

        // 3. 创建锁仓合约
        // 注意：vestingFactory 的 createVestingWallet 函数签名需要匹配整
        uint64 currentVestingStartTime = uint64(block.timestamp);
        address newVestingWallet = IVestingFactory(vestingFactory).createVestingWallet(
            sub.subscriber,
            sub.patAmount,
            currentVestingStartTime
        );
        require(newVestingWallet != address(0), "Vesting wallet creation failed");

        // 4. 将 PAT 转入锁仓合约
        patToken.transfer(newVestingWallet, sub.patAmount);

        // 5. 更新申购状态和信息
        subMmutable.vestingWallet = newVestingWallet;
        subMmutable.status = uint8(SubscriptionStatus.CONFIRMED);

        emit SubscriptionConfirmed(_subscriptionId, _subscriber, newVestingWallet);

        userActiveSubscriptionId[sub.subscriber] = 0;

        return (
            sub.subscriber,
            sub.patAmount,
            sub.usdtAmount,
            subMmutable.vestingWallet
        );
    }

    // --- Getter 函数 ---
    function getSubscription(uint256 _subscriptionId) external view returns (Subscription memory) {
        return subscriptions[_subscriptionId];
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

     /**
     * @dev 获取本合约当前的 PAT 代币余额
     * @return balance 当前的 PAT 余额
     */
    function getContractPatBalance() external view returns (uint256 balance) {
        balance = patToken.balanceOf(address(this));
    }

     /**
     * @dev 将本合约所有的 PAT 代币转回 InvestorSalePool 合约
     * @notice 只有合约所有者可以调用
     */
    function transferAllPatToInvestorPool() external onlyOwner nonReentrant {
        uint256 balance = patToken.balanceOf(address(this));
        if (balance > 0) {
            patToken.transfer(investorSalePoolAddress, balance);
        }
    }

    // --- UUPS Upgrade ---
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

}