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
import "../utils/calculate.sol";
import "../interface/IChainlinkFC.sol";

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

    using Calculate for uint256;

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
        );
    }


    function version() external view virtual returns (string memory) {
        return "1.0.0";
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
     * @dev 发起一个新的PAT代币申购请求
     * @param _usdtAmount 用户希望用于申购的USDT金额
     * @return expiryTimestamp 申购请求的过期时间戳
     */
    function createSubscriptionByUsdt(address _user, uint256 _usdtAmount)
        external
        nonReentrant
        whenNotPaused
        whenSaleActive
        returns (uint256 expiryTimestamp, uint256 currentId)
    {
        address subscriptionSalePoolAddress = address(subscriptionSalePool); // 确保地址不为零地址
        address _subscriber = _user; // 申购者是调用者
        require(_usdtAmount > 0 && _user != address(0) && subscriptionSalePoolAddress != address(0), "USDT amount must be positive");

        // 2. 计算PAT数量
        uint256 patAmount = Calculate.calculatePatByUsdt(_usdtAmount);
        require(patAmount > 0, "Calculated PAT amount is zero");

        // 3. 检查本合约是否有足够的PAT代币用于本次申购
        uint256 contractPatBalance = patCoin.balanceOf(address(this));
        require(contractPatBalance >= patAmount, "Insufficient PAT balance in InvestorSalePool");

        // 检查用户是否有足够的 USDT 余额
        // uint256 userUsdtBalance = usdt.balanceOf(_user);
        // require(userUsdtBalance >= _usdtAmount, "Insufficient USDT balance");

        patCoin.transfer(subscriptionSalePoolAddress, patAmount);
        // 5. 调用 SubscriptionSalePool 创建申购记录
        (uint256 _expiryTimestamp, uint256 _currentId) = ISubscriptionSalePool(subscriptionSalePoolAddress).createSubscription(
            _subscriber,
            patAmount,
            _usdtAmount
        );

        // 7. 触发事件
        emit SubscriptionRequestedByUsdt(_subscriber, _currentId, patAmount, _usdtAmount, _expiryTimestamp);
        return (
            _expiryTimestamp,
            _currentId
        );
    }

    // 接收 Ccip 消息 确定完成 usdt 付款行为
    function handleCCIPMessage(
        uint64 sourceChainSelector,
        address sender,
        bytes calldata data
    ) external override {

        // 检查是否是预期的链下消息
        require(chainlinkFCAddress != address(0), "ChainlinkFCAddress is zero");

        emit CCIPMessageReceived(sourceChainSelector, sender, data);

        IChainlinkFC chainlinkFC = IChainlinkFC(chainlinkFCAddress);

        // data -> payUsdtHash

        // bytes32 requestId = chainlinkFC.sendRequest(
        //     subscriptionId,
        //     args,
        //     source,
        //     callbackGasLimit
        // );

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
            
            // pat 开始锁仓
            (address _user, uint256 _patAmount, uint256 _usdtAmount, address _vestingWallet) = ISubscriptionSalePool(subscriptionSalePoolAddress).confirmSubscription(_subscriptionId);
            
            // TODO 记录购买信息 Gas 优化
            userPurchases[_user].push(Purchase({
                usdtAmount: _usdtAmount,
                patAmount: _patAmount,
                timestamp: uint64(block.timestamp),
                vestingWallet: _vestingWallet,
                isRedeemed: false
            }));

            // 更新用户总投资金额
            totalUserInvestment[_user] += _usdtAmount;
            // 更新销售统计
            totalUsdtRaised += _usdtAmount;
            totalPatSold += _patAmount;
            
            // TODO 调用链下生成PDF

            // 触发事件
            emit PurchaseConfirm(_user, _usdtAmount, _patAmount, _vestingWallet);
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

    function setChainlinkFCAddress (address _chainlinkFCAddress) external onlyOwner {
        require(_chainlinkFCAddress!= address(0), "ChainlinkFCAddress address is zero");
        chainlinkFCAddress = _chainlinkFCAddress;
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
    {
        // 在此处添加任何额外的授权逻辑
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
    
}