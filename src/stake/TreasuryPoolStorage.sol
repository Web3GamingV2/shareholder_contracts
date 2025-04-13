// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "../interface/IPAT.sol";
import "../interface/IPATLayerZeroBridge.sol";
import "../interface/ITreasuryPool.sol";
import "../core/PATStorage.sol";


abstract contract TreasuryPoolStorage is Initializable {

    using SafeERC20 for IERC20;
    using SafeERC20 for IPATInterface;

     // 用户存款记录结构体
    struct Deposit {
        uint256 patAmount;     // PAT金额
        uint256 usdtAmount;    // USDT金额
        uint256 timestamp;     // 存款时间
        address sourcePool;    // 来源池合约地址
        PATStorage.PoolType userType;     // 用户类型
    }

    // 用户余额结构体
    struct UserBalance {
        uint256 patAmount;         // PAT总余额
        uint256 interest;          // 累积利息
        uint256 lastInterestTime;  // 上次计息时间
        Deposit[] deposits;        // 存款记录
    }

    // 常量
    uint256 public constant SECONDS_PER_DAY = 86400; // 每天的秒数
    uint256 public constant DAILY_INTEREST_RATE = 3; // 每日利率 0.003 (3/1000)
    uint256 public constant INTEREST_RATE_DENOMINATOR = 1000; // 利率分母

    // 状态变量
    IPATInterface public patCoin;  // PAT代币
    IERC20 public usdtCoin;        // USDT代币
    IPATLayerZeroBridge public polygonConnector; // Polygon跨链连接器
    address public multiSigWallet; // 多签钱包地址

    // 用户余额映射 (用户地址 => 余额信息)
    mapping(address => UserBalance) public userBalances;

    // 可赎回的映射
    mapping(address => uint256) public redeemableBalances;
    // 链下调用 tron 过程中的 锁定
    mapping(address => uint256) public lockedBalancesTron;

    
    // 池类型映射 (池地址 => 用户类型)
    mapping(address => PATStorage.PoolType) public poolTypes;
    
    // 总余额（按合约池类型）
    mapping(PATStorage.PoolType => uint256) public totalPatBalances;  // 总PAT余额
    mapping(PATStorage.PoolType => uint256) public totalInterests;    // 总利息

    uint256 public totalUsdtBalance; // 总USDT余额

    // 事件
    event PoolAuthorized(
        address indexed poolAddress,
        PATStorage.PoolType indexed poolType,
        bool isAuthorized
    );
    
    event USDTDeposited(
        address indexed user,
        address indexed sourcePool,
        PATStorage.PoolType indexed userType,
        uint256 usdtAmount,
        uint256 patAmount,
        uint256 depositIndex
    );
    
    event PATRedeemed(
        address indexed user,
        address indexed sourcePool,
        PATStorage.PoolType indexed userType,
        uint256 patAmount,
        uint256 usdtAmount,
        uint256 interestAmount
    );
    
    event InterestCalculated(
        address indexed user,
        uint256 patAmount,
        uint256 interestAmount,
        uint256 timestamp
    );
    
    event USDTTransferredToL2(
        address indexed initiator,
        uint256 amount,
        uint256 timestamp
    );
    
    event USDTReceivedFromL2(
        address indexed from,
        uint256 amount,
        uint256 timestamp
    );
    
    event PolygonConnectorUpdated(
        address oldConnector,
        address newConnector
    );
    
    event USDTWithdrawn(
        address indexed to,
        uint256 amount,
        address indexed initiator,
        uint256 timestamp
    );

    event BalanceLocked (address indexed user, uint256 amount);


    /**
     * @dev 初始化存储合约
     */
    function __TreasuryPoolStorage_init(
        address _patToken,
        address _usdtToken,
        address _vestingFactory,
        address _multiSigWallet
    ) internal initializer {
        require(_patToken != address(0), "Invalid PAT address");
        require(_usdtToken != address(0), "Invalid USDT address");
        require(_vestingFactory != address(0), "Invalid vesting factory address");
        require(_multiSigWallet != address(0), "Invalid multisig wallet address");
        
        patCoin = IPATInterface(_patToken);
        usdtCoin = IERC20(_usdtToken);
        multiSigWallet = _multiSigWallet;
    }


    // 保留的存储槽位，用于未来扩展
    uint256[50] private __gap;

}