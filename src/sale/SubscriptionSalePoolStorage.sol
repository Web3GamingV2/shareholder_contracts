
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interface/IPAT.sol";

abstract contract SubscriptionSalePoolStorage is Initializable {
    using SafeERC20 for IPATInterface;
    using SafeERC20 for IERC20;

    // --- 枚举 ---
    enum SubscriptionStatus {
        PENDING,   // 待处理 (用户已申购，等待付款)
        CONFIRMED, // 已确认 (用户已付款，等待处理或已处理)
        EXPIRED,   // 已过期 (用户未在有效期内付款)
        CANCELLED  // 已取消 (用户或管理员取消)
    }

    // --- 结构体 ---
    struct Subscription {
        uint256 id;                 // 申购记录唯一ID
        address subscriber;         // 申购人地址
        uint256 patAmount;          // 申购的PAT数量
        uint256 usdtAmount;         // 需要支付的USDT数量
    }

    struct SubscriptionMmutable {
        uint8 status;  // 申购状态
        address vestingWallet;      // 确认后创建的锁仓钱包地址 (可选)
    }

    // --- 状态变量 ---

    IPATInterface public patToken;          // PAT代币合约
    IERC20 public usdtToken;     // USDT代币合约

    address public investorSalePoolAddress; // InvestorSalePool合约地址 (用于权限控制)
    address public vestingFactory; // 锁仓工厂合约

    uint256 public subscriptionDuration;   // 申购记录有效期 (例如 3600 秒 = 1 小时)
    uint256 public nextSubscriptionId;     // 下一个申购记录的ID

    // --- 映射 ---

    // 申购ID到申购记录的映射
    mapping(uint256 => Subscription) public subscriptions;
    mapping(uint256 => SubscriptionMmutable) public subscriptionsMmutable;

    // 用户地址到其所有申购记录ID列表的映射
    mapping(address => uint256[]) public userSubscriptionIds;

    // --- 初始化 ---
    function __SubscriptionSalePoolStorage_init(
        address _patToken,
        address _usdtToken,
        address _investorSalePoolAddress,
        address _vestingFactory,
        uint256 _subscriptionDuration // 默认 1 小时 = 3600 秒
    ) internal {
        require(_patToken != address(0), "Invalid PAT address");
        require(_usdtToken != address(0), "Invalid USDT address");
        require(_investorSalePoolAddress != address(0), "Invalid InvestorSalePool address");
        require(_subscriptionDuration > 0, "Subscription duration must be positive");

        patToken = IPATInterface(_patToken);
        usdtToken = IERC20(_usdtToken);
        investorSalePoolAddress = _investorSalePoolAddress;
        subscriptionDuration = _subscriptionDuration;
        vestingFactory = _vestingFactory;
        nextSubscriptionId = 1; // ID 从 1 开始
    }

    // 保留的存储槽位，用于未来扩展
    uint256[50] private __gap;
}