// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title IVestingFactory
 * @dev 锁仓工厂合约接口
 */
interface IVestingFactory {

    /// @dev 锁仓池类型
    enum PoolType {
        INVESTOR,    // 投资人池 
        TEAM,        // 团队池
        COMMUNITY,   // 社区池
        ADVISOR,     // 顾问池
        RESERVE      // 储备池
    }

    /// @dev 锁仓池信息
    struct PoolInfo {
        bool isActive;   // 是否激活
        uint64 cliffDuration; // 悬崖期 (秒)
        uint64 vestingDuration; // 锁仓期 (秒)
        uint256 initialRelease;  // 初始释放比例（基点，10000=100%）
        bool canEarlyRedeem;     // 是否可以提前赎回
    }

    struct VestingInfo {
        PoolType poolType;       // 池子类型
        address beneficiary;  // 受益人地址
        uint64 startTime;     // 开始时间
        uint64 endTime;       // 结束时间
        uint256 totalAmount;  // 总金额
        bool isEarlyRedeemed;    // 是否已提前赎回
    }

    // 事件
    event PoolConfigUpdated(PoolType indexed poolType, uint64 cliffDuration, uint64 vestingDuration, uint256 initialRelease, bool canEarlyRedeem);
    event VestingWalletCreated(PoolType indexed poolType, address indexed vestingWallet, address indexed beneficiary, uint256 amount);
    event EarlyRedemptionPerformed(address indexed vestingWallet, address indexed beneficiary, uint256 redeemedAmount, uint256 feeAmount);
    event RedemptionPoolUpdated(address oldPool, address newPool);
    event EarlyRedemptionFeeUpdated(uint256 oldFee, uint256 newFee);

    // 函数

    // 设置特定类型锁仓池的配置参数
    function setPoolConfig(PoolType _poolType, uint64 _cliffDuration, uint64 _vestingDuration, uint256 _initialRelease, bool _canEarlyRedeem) external;
    
    // 为指定受益人创建一个锁仓钱包
    function createVestingWallet(PoolType _poolType, address _beneficiary, uint256 _amount, uint64 _startTimestamp) external returns (address);
    function batchCreateVestingWallets(PoolType _poolType, address[] calldata _beneficiaries, uint256[] calldata _amounts, uint64 _startTimestamp) external;

    // 提前赎回锁仓钱包中的代币
    function earlyRedeem(address _vestingWallet) external;
    // 设置提前赎回的费率 (单位：基点，10000=100%)
    function setEarlyRedemptionFee(uint256 _earlyRedemptionFeeBps) external;

    // 设置赎回池合约地址
    function setRedemptionPool(address _redemptionPool) external;

    // 获取特定池子类型的所有锁仓钱包地址
    function getPoolVestingWallets(PoolType _poolType) external view returns (address[] memory);
    // 获取特定受益人的所有锁仓钱包地址
    function getBeneficiaryVestingWallets(address _beneficiary) external view returns (address[] memory);
    
    function pause() external;
    function unpause() external;

}