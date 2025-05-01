// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";


import "../core/PATStorage.sol";
import "../interface/IPAT.sol";
import "../interface/ITreasuryPool.sol";
import "../interface/IVestingFactory.sol";
import "../stake/VestingFactoryStorage.sol";
import "./InvestorSalePoolStorage.sol";
import "../interface/IRedeemManager.sol";

/**
 * @title 投资者销售池
 * @dev 投资者销售池合约，允许投资者购买PAT代币
 */
contract InvestorSalePool is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    InvestorSalePoolStorage
{
      // 修饰符
    modifier onlyMultiSigOrOwner() {
        require(msg.sender == multiSigWallet || msg.sender == owner(), "Not multisig or owner");
        _;
    }

    modifier whenSaleActive() {
        require(saleActive, "Sale not active");
        _;
    }

     /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _owner,
        address _patCoin,
        address _usdt,
        address _treasuryPool,
        address _vestingFactory,
        address _multiSigWallet,
        // address _subscriptionSalePool,
        uint256 _treasuryRatioBps // 转入赎回池的比例（基点）默认是 1
    ) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        __InvestorSalePoolStorage_init(
            _patCoin,
            _usdt,
            _treasuryPool,
            _vestingFactory,
            _treasuryRatioBps,
            _multiSigWallet
            // _subscriptionSalePool
        );
        __TierConfig_init();
    }

    // 投资人级别配置 购买价格不一样 但是最后等比赎回
    function __TierConfig_init() internal {
        // 初始化投资者级别配置 - 调整为1:1比例
        // 一级投资者：50,000 - 100,000 USDT，1PAT = 1 USDT
        _setTierConfig(1, 50000 * 1e6, 100000 * 1e6, 1e18, true);
        // 二级投资者：10,000 - 49,999 USDT，1PAT = 1 USDT
        _setTierConfig(2, 10000 * 1e6, 49999 * 1e6, 1e18, true);
        // 三级投资者：5,000 - 9,999 USDT，1PAT = 1 USDT
        _setTierConfig(3, 5000 * 1e6, 9999 * 1e6, 1e18, true);
        // 四级投资者：1,000 - 4,999 USDT，1PAT = 1 USDT
        _setTierConfig(4, 1000 * 1e6, 4999 * 1e6, 1e18, true);
    }

    function _setTierConfig(
        uint8 _tier,
        uint256 _minAmount,
        uint256 _maxAmount,
        uint256 _price,
        bool _isActive
    ) internal {
        require(_tier > 0 && _tier <= 10, "Invalid tier");
        require(_minAmount <= _maxAmount, "Min amount must be <= max amount");
        require(_price > 0, "Price must be > 0");
        
        tierConfigs[_tier] = TierConfig({
            minAmount: _minAmount,
            maxAmount: _maxAmount,
            price: _price,
            isActive: _isActive
        });
        
        emit TierConfigUpdated(_tier, _minAmount, _maxAmount, _price, _isActive);
    }

    function version() external view virtual returns (string memory) {
        return "1.0.0";
    }

     // 外部调用
     function setTierConfig(
        uint8 _tier,
        uint256 _minAmount,
        uint256 _maxAmount,
        uint256 _price,
        bool _isActive
    ) public onlyMultiSigOrOwner whenNotPaused {
        _setTierConfig(_tier, _minAmount, _maxAmount, _price, _isActive);
    }
    
    /**
     * @dev 设置转入赎回池的比例
     * @param _treasuryRatioBps 新的比例（基点）
     */
    function setTreasuryRatio(uint256 _treasuryRatioBps) external onlyMultiSigOrOwner whenNotPaused {
        require(_treasuryRatioBps <= 10000, "Ratio cannot exceed 100%");
        uint256 oldRatio = treasuryRatioBps;
        treasuryRatioBps = _treasuryRatioBps;
        emit TreasuryRatioUpdated(oldRatio, _treasuryRatioBps);
    }
    
    /**
     * @dev 设置销售状态
     * @param _isActive 是否激活
     */
    function setSaleActive(bool _isActive) external onlyMultiSigOrOwner {
        saleActive = _isActive;
        emit SaleStateUpdated(_isActive);
    }
    
    /**
     * @dev 获取用户适用的投资者级别
     * @param _usdtAmount USDT金额
     * @return tier 投资者级别
     */
    function getUserTier(uint256 _usdtAmount) public view returns (uint8) {
        for (uint8 i = 1; i <= 10; i++) {
            TierConfig memory config = tierConfigs[i];
            if (config.isActive && _usdtAmount >= config.minAmount && _usdtAmount <= config.maxAmount) {
                return i;
            }
        }
        revert("No matching tier found");
    }

    /**
     * @dev 计算PAT数量
     * @param _usdtAmount USDT金额
     * @param _tier 投资者级别
     * @return patAmount PAT数量
     */
    function calculatePatAmount(uint256 _usdtAmount, uint8 _tier) public view returns (uint256) {
        require(_tier > 0 && _tier <= 10, "Invalid tier");
        require(tierConfigs[_tier].isActive, "Tier not active");
        
        // 计算PAT数量：USDT金额 / 价格
        // 注意：价格单位为USDT/PAT，精度为1e18
        return (_usdtAmount * 1e18) / tierConfigs[_tier].price;
    }

    /**
     * @dev 发起一个新的PAT代币申购请求
     * @param _usdtAmount 用户希望用于申购的USDT金额
     * @return expiryTimestamp 申购请求的过期时间戳
     */
    function createSubscriptionRequest(address _user, uint256 _usdtAmount)
        external
        nonReentrant
        whenNotPaused
        whenSaleActive
        returns (uint256 expiryTimestamp)
    {
        require(_usdtAmount > 0, "USDT amount must be positive");
        require(_user != address(0), "Invalid user address");
        address _subscriber = _user; // 申购者是调用者

        // 1. 确定投资者级别
        uint8 tier = getUserTier(_usdtAmount);

        // 2. 计算PAT数量
        uint256 patAmount = calculatePatAmount(_usdtAmount, tier);
        require(patAmount > 0, "Calculated PAT amount is zero");

        // 3. 检查本合约是否有足够的PAT代币用于本次申购
        uint256 contractPatBalance = patCoin.balanceOf(address(this));
        require(contractPatBalance >= patAmount, "Insufficient PAT balance in InvestorSalePool");
        
        address subscriptionSalePoolAddress = address(subscriptionSalePool); // 确保地址不为零地址
        require(subscriptionSalePoolAddress != address(0), "SubscriptionSalePool address is zero"); // 确保地址不为零地址
        require(patCoin.allowance(address(this), subscriptionSalePoolAddress) >= patAmount, "Insufficient allowance"); // 确保合约有足够的 PAT 授权

        // 4. 授权 SubscriptionSalePool 合约转移 PAT
        patCoin.approve(subscriptionSalePoolAddress, patAmount);

        // 5. 调用 SubscriptionSalePool 创建申购记录
        expiryTimestamp = ISubscriptionSalePool(subscriptionSalePoolAddress).createSubscription(
            _subscriber,
            patAmount,
            _usdtAmount,
            tier
        );

        // 6. 重置授权 (可选，但推荐)
        patCoin.approve(subscriptionSalePoolAddress, 0);

        // 7. 触发事件
        emit SubscriptionRequested(_subscriber, patAmount, _usdtAmount, tier, expiryTimestamp);

        // 注意：此函数不处理USDT。USDT的接收和处理将在 SubscriptionSalePool 的 confirmSubscription 函数中进行。
    }

    /**
     * 用户在L2完成USDT交付后形成一条购买记录
     * ccip 调用此方法 (L2 Sender)
     * 成功后chainlinkFC调用链下生成购买PDF用户决定是否IPFS
     */
    function confirmSubscriptionRequest(uint256 _subscriptionId) external
        nonReentrant
        whenNotPaused
        whenSaleActive {
            address subscriptionSalePoolAddress = address(subscriptionSalePool); // 确保地址不为零地址
            (address _user, uint256 _patAmount, uint256 _usdtAmount, uint8 _tier, address _vestingWallet) = ISubscriptionSalePool(subscriptionSalePoolAddress).confirmSubscription(_subscriptionId);
            // 记录购买信息
            userPurchases[_user].push(Purchase({
                usdtAmount: _usdtAmount,
                patAmount: _patAmount,
                tier: _tier,
                timestamp: uint64(block.timestamp),
                vestingWallet: _vestingWallet,
                isRedeemed: false
            }));

            // 更新用户总投资金额
            totalUserInvestment[_user] += _usdtAmount;
            // 更新销售统计
            totalUsdtRaised += _usdtAmount;
            totalPatSold += _patAmount;

            emit PurchaseMade(_user, _usdtAmount, _patAmount, _tier, _vestingWallet);
    }

    /**
     * @dev 购买PAT代币
     * @param _usdtAmount USDT金额 1 : 1
     */
    function purchase (address _user, uint256 _usdtAmount) public nonReentrant whenNotPaused() whenSaleActive()  {
        require(_usdtAmount > 0, "Invalid PAT amount");
        // 确定投资者级别
        uint8 tier = getUserTier(_usdtAmount);

          // 计算PAT数量
        uint256 patAmount = calculatePatAmount(_usdtAmount, tier);
        require(patAmount > 0, "PAT amount too small");
        
         // 检查合约是否有足够的PAT代币
        uint256 contractPatBalance = patCoin.balanceOf(address(this));

        require(contractPatBalance >= patAmount, "Insufficient PAT balance in contract");
        
         // 检查用户是否有足够的USDT
        uint256 userUsdtBalance = usdt.balanceOf(_user);
        require(userUsdtBalance >= _usdtAmount, "Insufficient USDT balance");

        // 转移USDT到合约
        usdt.transferFrom(_user, address(this), _usdtAmount);
         // 计算转入赎回池的USDT金额
        uint256 treasuryAmount = (_usdtAmount * treasuryRatioBps) / 10000;
        
        // 转移USDT到投资人池
        if (treasuryAmount > 0) {
            usdt.approve(address(treasuryPool), treasuryAmount);
            treasuryPool.depositUSDT(PATStorage.PoolType.INVESTOR, _user, treasuryAmount, patAmount);
            // 重置授权
            usdt.approve(address(treasuryPool), 0);
        }
    
        // 转移用户的 PAT 到锁仓钱包
        patCoin.approve(address(vestingFactory), patAmount);
          // 使用当前区块时间作为锁仓开始时间，确保锁仓立即开始
        uint64 currentVestingStartTime = uint64(block.timestamp);
        address vestingWallet = IVestingFactory(vestingFactory).createVestingWallet(_user, patAmount, currentVestingStartTime);
        // 重置授权
        patCoin.approve(address(vestingFactory), 0); 

        // 记录购买信息
        userPurchases[_user].push(Purchase({
            usdtAmount: _usdtAmount,
            patAmount: patAmount,
            tier: tier,
            timestamp: uint64(block.timestamp),
            vestingWallet: vestingWallet,
            isRedeemed: false
        }));

        // 更新用户总投资金额
        totalUserInvestment[_user] += _usdtAmount;
         // 更新销售统计
        totalUsdtRaised += _usdtAmount;
        totalPatSold += patAmount;

        emit PurchaseMade(_user, _usdtAmount, patAmount, tier, vestingWallet);
    }

    function getUserPurchases(address _user) public view returns (Purchase[] memory) {
        return userPurchases[_user];
    }

    function getUserTotalInvestment(address _user) public view returns (uint256) {
        return totalUserInvestment[_user];
    }

    /**
     * @dev 释放已解锁的代币数量并尝试释放
     * @param _purchaseIndex 购买记录索引
     */
    function releaseVested(address _user, uint256 _purchaseIndex) public nonReentrant whenNotPaused() returns(bool, uint256) {
        require(_purchaseIndex < userPurchases[_user].length, "Invalid purchase index");
        Purchase storage purchaseOrder = userPurchases[_user][_purchaseIndex];
        // 检查购买是否已赎回
        require(!purchaseOrder.isRedeemed, "Purchase already redeemed");
        
        address vestingWallet = purchaseOrder.vestingWallet;
          // 调用VestingFactory先获取可以释放的代币数量
        (, , uint256 releasable) = IVestingFactory(vestingFactory).getVestingStatus(vestingWallet);

        // 检查是否有可释放的代币
        require(releasable > 0, "No releasable tokens");

        // 调用VestingFactory释放代币
        IVestingFactory(vestingFactory).releaseVestedTokens(vestingWallet);

        emit TokensReleased(_user, vestingWallet, releasable);

        return (true, releasable); // 返回是否成功和释放的金额
    }

    /**
     * @dev 赎回已释放的代币为USDT
     * @param _purchaseIndex 购买记录索引
     * TODO: 需要 chainlink 链接链下
     */
    function redeemReleased(address _user, uint256 _purchaseIndex) public nonReentrant whenNotPaused returns(bytes32)  {
        require(_purchaseIndex < userPurchases[_user].length, "Invalid purchase index");
        
        Purchase storage purchaseOrder = userPurchases[_user][_purchaseIndex];
        require(!purchaseOrder.isRedeemed, "Purchase already redeemed");
        
        uint256 patBalance = treasuryPool.getUserPatBalance(_user);
        require(patBalance > 0, "No PAT balance in treasury");
        
        // 计算可赎回的USDT金额（包括PAX利息） 按照 0.003 算
        uint256 usdtAmount = treasuryPool.calculateRedemptionAmount(_user, patBalance);
        require(usdtAmount > 0, "No USDT to redeem");
        
        // 从TreasuryPool赎回USDT，获取请求ID
        (uint256 actualUsdtAmount, bytes32 requestId) = treasuryPool.redeemPAT(_user, patBalance, usdtAmount);

          // 记录赎回请求信息
        redemptionRequests[requestId] = RedemptionRequest({
            user: _user,
            purchaseIndex: _purchaseIndex,
            patAmount: patBalance,
            usdtAmount: actualUsdtAmount,
            timestamp: block.timestamp,
            status: IRedeemManager.RedemptionStatus.PENDING
        });
        
        emit RedemptionRequested(requestId, _user, patBalance, actualUsdtAmount, _purchaseIndex);
        
        return requestId;
    
    }

     /**
     * @dev 完成赎回流程 - 由管理员调用，确认链下处理完成
     * @param _requestId 赎回请求ID
     */
    function completeRedemption(bytes32 _requestId) external onlyMultiSigOrOwner nonReentrant {
        RedemptionRequest storage request = redemptionRequests[_requestId];
        require(request.user != address(0), "Invalid request ID");
        require(request.status == IRedeemManager.RedemptionStatus.PENDING, "Request not pending");
    
        // 更新状态
        request.status = IRedeemManager.RedemptionStatus.COMPLETED;
        
        // 销毁PAT代币
        patCoin.burn(request.user, request.patAmount);
        
        // 更新销售统计
        Purchase storage purchaseOrder = userPurchases[request.user][request.purchaseIndex];
        // 标记为已赎回
        purchaseOrder.isRedeemed = true;
        totalUsdtRaised -= purchaseOrder.usdtAmount;
        totalPatSold -= purchaseOrder.patAmount;
        // 更新用户总投资金额
        totalUserInvestment[request.user] -= purchaseOrder.usdtAmount;
        
        emit RedemptionCompleted(_requestId, request.user, request.patAmount, request.usdtAmount);
    }

     /**
     * @dev 取消赎回流程 - 由管理员调用，确认链下处理失败
     * @param _requestId 赎回请求ID
     */
    function cancelRedemption(bytes32 _requestId) external onlyMultiSigOrOwner nonReentrant {
        RedemptionRequest storage request = redemptionRequests[_requestId];
        require(request.user != address(0), "Invalid request ID");
        require(request.status == IRedeemManager.RedemptionStatus.PENDING, "Request not pending");
        
        // 更新状态
        request.status = IRedeemManager.RedemptionStatus.FAILED;
        
        // 取消标记为已赎回
        Purchase storage purchaseOrder = userPurchases[request.user][request.purchaseIndex];
        purchaseOrder.isRedeemed = false;
        
        emit RedemptionCancelled(_requestId, request.user, request.patAmount, request.usdtAmount);
    }

    function setSubscriptionSalePool(address _subscriptionSalePool) external onlyOwner {
        require(_subscriptionSalePool!= address(0), "SubscriptionSalePool address is zero");
        subscriptionSalePool = ISubscriptionSalePool(_subscriptionSalePool);
    }

    function getSubscriptionSalePool() external view returns (address _subscriptionSalePoolAddress) {
        return address(subscriptionSalePool);
    }

     /**
     * @dev 获取合约中的PAT余额
     * @return 合约中的PAT代币数量
     */
    function getContractPatBalance() public view returns (uint256) {
        return patCoin.balanceOf(address(this));
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
    
}