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
        uint256 _treasuryRatioBps,
        uint64 _vestingStartTime
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
            _vestingStartTime,
            _multiSigWallet
        );
        __TierConfig_init();
    }

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
     * @dev 设置锁仓开始时间
     * @param _vestingStartTime 新的开始时间
     */
    function setVestingStartTime(uint64 _vestingStartTime) external onlyMultiSigOrOwner whenNotPaused {
        require(_vestingStartTime > block.timestamp, "Start time must be in the future");
        uint64 oldTime = vestingStartTime;
        vestingStartTime = _vestingStartTime;
        emit VestingStartTimeUpdated(oldTime, _vestingStartTime);
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

    function purchase (uint256 _usdtAmount) public nonReentrant whenNotPaused() whenSaleActive()  {
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
        uint256 userUsdtBalance = usdt.balanceOf(msg.sender);
        require(userUsdtBalance >= _usdtAmount, "Insufficient USDT balance");

        // 转移USDT到合约
        usdt.transferFrom(msg.sender, address(this), _usdtAmount);
         // 计算转入赎回池的USDT金额
        uint256 treasuryAmount = (_usdtAmount * treasuryRatioBps) / 10000;
        
        // 转移USDT到赎回池
        if (treasuryAmount > 0) {
            usdt.approve(address(treasuryPool), treasuryAmount);
            treasuryPool.depositUSDT(PATStorage.PoolType.INVESTOR, msg.sender, treasuryAmount, patAmount);
            usdt.approve(address(treasuryPool), 0); // 重置授权
        }
    
        // 转移PAT到锁仓钱包
        patCoin.approve(address(vestingFactory), patAmount);
        address vestingWallet = IVestingFactory(vestingFactory).createVestingWallet(msg.sender, patAmount, vestingStartTime);
        patCoin.approve(address(vestingFactory), 0); // 重置授权

        // 记录购买信息
        userPurchases[msg.sender].push(Purchase({
            usdtAmount: _usdtAmount,
            patAmount: patAmount,
            tier: tier,
            timestamp: uint64(block.timestamp),
            vestingWallet: vestingWallet,
            isRedeemed: false
        }));

        // 更新用户总投资金额
        totalUserInvestment[msg.sender] += _usdtAmount;
         // 更新销售统计
        totalUsdtRaised += _usdtAmount;
        totalPatSold += patAmount;

        emit PurchaseMade(msg.sender, _usdtAmount, patAmount, tier, vestingWallet);
    }

    function getUserPurchases(address _user) public view returns (Purchase[] memory) {
        return userPurchases[_user];
    }

    function getUserTotalInvestment(address _user) public view returns (uint256) {
        return totalUserInvestment[_user];
    }

    function release(uint256 _purchaseIndex) public nonReentrant whenNotPaused() {
        releaseVested(_purchaseIndex);
        redeemReleased(_purchaseIndex);
    }

    /**
     * @dev 释放已解锁的代币
     * @param _purchaseIndex 购买记录索引
     */
    function releaseVested(uint256 _purchaseIndex) public nonReentrant whenNotPaused() {
        require(_purchaseIndex < userPurchases[msg.sender].length, "Invalid purchase index");
        Purchase storage purchaseOrder = userPurchases[msg.sender][_purchaseIndex];
        // 检查购买是否已赎回
        require(!purchaseOrder.isRedeemed, "Purchase already redeemed");
        
        address vestingWallet = purchaseOrder.vestingWallet;
          // 调用VestingFactory释放代币
        (, , uint256 releasable) = IVestingFactory(vestingFactory).getVestingStatus(vestingWallet);

        // 检查是否有可释放的代币
        require(releasable > 0, "No releasable tokens");

        // 调用VestingFactory释放代币
        IVestingFactory(vestingFactory).releaseVestedTokens(vestingWallet);

        emit TokensReleased(msg.sender, vestingWallet, releasable);
    }

    /**
     * @dev 赎回已释放的代币为USDT
     * @param _purchaseIndex 购买记录索引
     */
    function redeemReleased(uint256 _purchaseIndex) public nonReentrant whenNotPaused {
        require(_purchaseIndex < userPurchases[msg.sender].length, "Invalid purchase index");
        
        Purchase storage purchaseOrder = userPurchases[msg.sender][_purchaseIndex];
        require(!purchaseOrder.isRedeemed, "Purchase already redeemed");
        
        // ITreasuryPool treasuryPool = ITreasuryPool(treasuryPool);
        
        // 获取用户在TreasuryPool中的PAT余额
        uint256 patBalance = treasuryPool.getUserPatBalance(msg.sender);
        require(patBalance > 0, "No PAT balance in treasury");
        
        // 计算可赎回的USDT金额（包括PAX利息）
        uint256 usdtAmount = treasuryPool.calculateRedemptionAmount(msg.sender, patBalance);
        require(usdtAmount > 0, "No USDT to redeem");
        
        // 标记为已赎回
        purchaseOrder.isRedeemed = true;
        
        // 从TreasuryPool赎回USDT
        treasuryPool.redeemPAT(msg.sender, patBalance, usdtAmount);
        
        // 销毁PAT代币
        patCoin.burn(msg.sender, patBalance);

        // 转移USDT到用户
        usdt.transfer(msg.sender, usdtAmount);

        // 更新销售统计
        totalUsdtRaised -= purchaseOrder.usdtAmount;
        totalPatSold -= purchaseOrder.patAmount;
        // 更新用户总投资金额
        totalUserInvestment[msg.sender] -= purchaseOrder.usdtAmount;
        
        emit TokensRedeemed(msg.sender, purchaseOrder.vestingWallet, patBalance, usdtAmount);
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