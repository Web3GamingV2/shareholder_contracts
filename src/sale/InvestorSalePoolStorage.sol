// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "../interface/IPAT.sol";
import "../interface/ITreasuryPool.sol";
import "../interface/IVestingFactory.sol";
import "../interface/IRedeemManager.sol";
import "../interface/ISubscriptionSalePool.sol";

abstract contract InvestorSalePoolStorage is Initializable {

    using SafeERC20 for IERC20;
    using SafeERC20 for IPATInterface;

    uint256 public constant usdtDecimal = 10 ** 6;
    uint256 public constant patDecimal = 10 ** 6;

    IPATInterface public patCoin;          // PAT代币
    IERC20 public usdt;                    // USDT代币
    ITreasuryPool public treasuryPool;     // 资金池
    IVestingFactory public vestingFactory; // 锁仓工厂合约
    ISubscriptionSalePool public subscriptionSalePool; // 申购销售池合约
    
    // 销售配置
    uint256 public treasuryRatioBps;       // 转入赎回池的比例（基点）
    address public multiSigWallet;         // 多签钱包地址
    bool public saleActive;                // 销售是否激活

    // 赎回请求映射
    mapping(bytes32 => RedemptionRequest) public redemptionRequests;

    // 赎回请求结构体
    struct RedemptionRequest {
        address user;              // 用户地址
        uint256 purchaseIndex;     // 购买记录索引
        uint256 patAmount;         // PAT金额
        uint256 usdtAmount;        // USDT金额
        uint256 timestamp;         // 时间戳
        IRedeemManager.RedemptionStatus status;   // 状态
    }

     // 投资者级别配置
    struct TierConfig {
        uint256 minAmount;                 // 最低购买金额（USDT）
        uint256 maxAmount;                 // 最高购买金额（USDT）
        uint256 price;                     // 价格（USDT/PAT，精度为1e18）
        bool isActive;                     // 是否激活
    }

    mapping(uint8 => TierConfig) public tierConfigs;  // 级别配置映射

    // 用户购买记录
    struct Purchase {
        uint256 usdtAmount;                // USDT金额
        uint256 patAmount;                 // PAT金额
        uint8 tier;                        // 投资者级别
        uint64 timestamp;                  // 时间戳
        address vestingWallet;             // 锁仓钱包地址
        bool isRedeemed;                   // 是否已赎回
    }
    
    mapping(address => Purchase[]) public userPurchases;  // 用户购买记录映射
    mapping(address => uint256) public totalUserInvestment; // 用户总投资金额
    
    // 销售统计
    uint256 public totalUsdtRaised;        // 总筹集USDT
    uint256 public totalPatSold;           // 总销售PAT
    
    // 事件
    event PurchaseMade(
        address indexed user,
        uint256 usdtAmount,
        uint256 patAmount,
        uint8 tier,
        address vestingWallet
    );
    event TierConfigUpdated(
        uint8 tier,
        uint256 minAmount,
        uint256 maxAmount,
        uint256 price,
        bool isActive
    );
    event TreasuryRatioUpdated(uint256 oldRatio, uint256 newRatio);
    event VestingStartTimeUpdated(uint64 oldTime, uint64 newTime);
    event SaleStateUpdated(bool isActive);
    event TokensRedeemed(
        address indexed user,
        address indexed vestingWallet,
        uint256 patAmount,
        uint256 usdtAmount
    );
    event TokensReleased(
        address indexed user,
        address indexed vestingWallet,
        uint256 releasedAmount
    );

    // 事件定义
    event RedemptionRequested(
        bytes32 indexed requestId,
        address indexed user,
        uint256 patAmount,
        uint256 usdtAmount,
        uint256 purchaseIndex
    );

    event RedemptionCompleted(
        bytes32 indexed requestId,
        address indexed user,
        uint256 patAmount,
        uint256 usdtAmount
    );

    event RedemptionCancelled(
        bytes32 indexed requestId,
        address indexed user,
        uint256 patAmount,
        uint256 usdtAmount
    );

    // 新增的申购请求事件
    event SubscriptionRequested(
        address indexed user,
        uint256 patAmount,
        uint256 usdtAmount,
        uint8 tier,
        uint256 expiryTimestamp
    );

    function __InvestorSalePoolStorage_init(
        address _patCoin,
        address _usdt,
        address _treasuryPool,
        address _vestingFactory,
        uint256 _treasuryRatioBps,
        address _multiSigWallet,
        address _subscriptionSalePool
    ) internal initializer {
        patCoin = IPATInterface(_patCoin);
        usdt = IERC20(_usdt);
        treasuryPool = ITreasuryPool(_treasuryPool);
        vestingFactory = IVestingFactory(_vestingFactory);
        subscriptionSalePool = ISubscriptionSalePool(_subscriptionSalePool);
        treasuryRatioBps = _treasuryRatioBps;
        multiSigWallet = _multiSigWallet;
        saleActive = false;
    }

     // 保留的存储槽位，用于未来扩展
    uint256[50] private __gap;
}