// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/finance/VestingWallet.sol";

import "../core/Basic.sol";
import "../interface/IPAT.sol";
import "./VestingFactoryStorage.sol";
import "../core/PATStorage.sol";

contract VestingFactory is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    VestingFactoryStorage,
    Basic
{
    using SafeERC20 for IPATInterface;

     // 修饰符：仅限多签钱包或所有者
    modifier onlyMultiSigOrOwner() {
        require(msg.sender == multiSigWallet || msg.sender == owner(), "Not multisig or owner");
        _;
    }

    modifier onlyInvestorSalePool() {
        require(msg.sender == investorSalePool, "Not investor sale pool");
        _;
    }
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /**
     * @dev 初始化函数
     * @param _patToken PAT代币合约地址
     * @param _multiSigWallet 多签钱包地址
     * @param _earlyRedemptionFeeBps 提前赎回费率（基点）
     */
    function initialize(
        address _initalOwner,
        address _patToken,
        address _investorSalePool,
        address _multiSigWallet,
        uint256 _earlyRedemptionFeeBps
    ) initializer public {
        require(_patToken != address(0), "Invalid PAT token address");
        require(_multiSigWallet != address(0), "Invalid multisig wallet address");
        require(_earlyRedemptionFeeBps <= 10000, "Fee cannot exceed 100%");
        
        __Ownable_init(_initalOwner);
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        
       __VestingFactoryStorage_init(_patToken, _investorSalePool, _multiSigWallet, _earlyRedemptionFeeBps);
        
        // 一期只设置投资人池配置
        _setPoolConfig(PATStorage.PoolType.INVESTOR, 0, 365 days, 0, true, true);  // 投资人池：无悬崖期，1年线性释放，无初始释放，可提前赎回
        
        // 其他池子配置预留，但设置为非激活状态
        _setPoolConfig(PATStorage.PoolType.DIRECT, 180 days, 730 days, 0, false, false);
        _setPoolConfig(PATStorage.PoolType.FOUNDATION, 90 days, 365 days, 0, false, false);
        _setPoolConfig(PATStorage.PoolType.RESERVE, 0, 730 days, 0, false, false);
    }
    
    /**
     * @dev 设置池子配置
     * @param _poolType 池子类型
     * @param _cliffDuration 悬崖期（秒）
     * @param _vestingDuration 锁仓期（秒）
     * @param _initialRelease 初始释放比例（基点，10000=100%）
     * @param _canEarlyRedeem 是否可以提前赎回
     */
    function _setPoolConfig(
        PATStorage.PoolType _poolType,
        uint64 _cliffDuration,
        uint64 _vestingDuration,
        uint256 _initialRelease,
        bool _canEarlyRedeem,
        bool _isActive
    ) internal {
         poolConfigs[_poolType] = PoolInfo({
            cliffDuration: _cliffDuration,
            vestingDuration: _vestingDuration,
            initialRelease: _initialRelease,
            canEarlyRedeem: _canEarlyRedeem,
            isActive: _isActive
         });
        emit PoolConfigUpdated(_poolType, _cliffDuration, _vestingDuration, _initialRelease, _canEarlyRedeem); 
    }

     /**
     * @dev 设置池子配置
     * @param _poolType 池子类型
     * @param _cliffDuration 悬崖期（秒）
     * @param _vestingDuration 锁仓期（秒）
     * @param _initialRelease 初始释放比例（基点，10000=100%）
     * @param _canEarlyRedeem 是否可以提前赎回
     */
    function setPoolConfig(
        PATStorage.PoolType _poolType,
        uint64 _cliffDuration,
        uint64 _vestingDuration,
        uint256 _initialRelease,
        bool _canEarlyRedeem
    ) public override onlyOwner() whenNotPaused {
        require(_vestingDuration > 0, "Vesting duration must be > 0");
        require(_initialRelease <= 10000, "Initial release cannot exceed 100%");
        
        _setPoolConfig(_poolType, _cliffDuration, _vestingDuration, _initialRelease, _canEarlyRedeem, true);
    }

    /**
     * @dev 创建锁仓钱包 - 一期只支持投资人池
     * @param _beneficiary 受益人地址
     * @param _amount 锁仓金额
     * @param _startTimestamp 开始时间戳
     */
    function createVestingWallet(
        address _beneficiary,
        uint256 _amount,
        uint64 _startTimestamp,
        uint256 _subscriptionId
    ) public onlyInvestorSalePool whenNotPaused nonReentrant returns (address) {

        require(_beneficiary != address(0), "Invalid beneficiary");
        require(_amount > 0, "Amount must be > 0");
        require(poolConfigs[PATStorage.PoolType.INVESTOR].isActive, "Investor pool not active");
        
        PoolInfo memory poolInfo = poolConfigs[PATStorage.PoolType.INVESTOR];
        
        // 创建锁仓钱包
        uint64 vestingStart = _startTimestamp + poolInfo.cliffDuration;
        uint64 vestingEnd = vestingStart + poolInfo.vestingDuration;

        // 检查锁仓金额是否超过池子限制
        require(_startTimestamp >= block.timestamp + 0.5 hours, "Start timestamp must be in the future");
        require(_startTimestamp <= block.timestamp + poolInfo.vestingDuration + poolInfo.cliffDuration, "Start timestamp too far in the future");

        VestingWallet vestingWallet = new VestingWallet(
            _beneficiary,
            vestingStart, // 线性释放的起点
            poolInfo.vestingDuration // 线性释放的持续时间
        );

        address vestingWalletAddr = address(vestingWallet);

        // 记录锁仓信息
        vestingInfos[vestingWalletAddr] = VestingInfo({
            poolType: PATStorage.PoolType.INVESTOR,
            beneficiary: _beneficiary,
            startTime: vestingStart,
            endTime: vestingEnd,
            totalAmount: _amount,
            isEarlyRedeemed: false,
            subscriptionId: _subscriptionId
        });
        
        // 检查用户是否有足够的代币
        uint256 userBalance = patToken.balanceOf(_beneficiary);
        uint256 userAllowance = patToken.allowance(_beneficiary, address(this));
        require(userBalance >= _amount, "Insufficient token balance");
        require(userAllowance >= _amount, "Insufficient token allowance");

        // 转移代币 从 address(this) 到锁仓钱包
        patToken.safeTransferFrom(_beneficiary, vestingWalletAddr, _amount);

        poolVestingWallets[PATStorage.PoolType.INVESTOR].push(vestingWalletAddr);
        beneficiaryVestingWallets[_beneficiary].push(vestingWalletAddr);

        emit VestingWalletCreated(PATStorage.PoolType.INVESTOR, vestingWalletAddr, _beneficiary, _amount);

        return vestingWalletAddr;
    }

     /**
     * @dev 批量创建投资人锁仓钱包
     * @param _beneficiaries 受益人地址数组
     * @param _amounts 锁仓金额数组
     * @param _startTimestamp 开始时间戳
     */
     function batchCreateVestingWallets(
        address[] calldata _beneficiaries,
        uint256[] calldata _amounts,
        uint256[] calldata _subscriptionIds,
        uint64 _startTimestamp
    ) public onlyInvestorSalePool whenNotPaused nonReentrant {
        require(_beneficiaries.length == _amounts.length, "Arrays length mismatch");
        require(_beneficiaries.length > 0, "Empty arrays");
        require(poolConfigs[PATStorage.PoolType.INVESTOR].isActive, "Investor pool not active");
         for (uint256 i = 0; i < _beneficiaries.length; i++) {
            if (_beneficiaries[i] != address(0) && _amounts[i] > 0) {
                createVestingWallet(_beneficiaries[i], _amounts[i], _startTimestamp, _subscriptionIds[i]);
            }
        }
    }

    function getVestingInfo(address _vestingWallet) external view returns (
        PATStorage.PoolType poolType,
        address beneficiary,
        uint64 startTime,
        uint64 endTime,
        uint256 totalAmount,
        bool isEarlyRedeemed,
        uint256 subscriptionId) {
        require(vestingInfos[_vestingWallet].beneficiary!= address(0), "Invalid vesting wallet");
        return (
            vestingInfos[_vestingWallet].poolType,
            vestingInfos[_vestingWallet].beneficiary,
            vestingInfos[_vestingWallet].startTime,
            vestingInfos[_vestingWallet].endTime,
            vestingInfos[_vestingWallet].totalAmount,
            vestingInfos[_vestingWallet].isEarlyRedeemed,
            vestingInfos[_vestingWallet].subscriptionId
        );
    }

     /**
     * @dev 提前赎回锁仓代币（由受益人调用）
     * @param _vestingWallet 锁仓钱包地址
     * TODO: 这一期不给提前赎回的能力
     */
     function earlyRedeem(address _vestingWallet) public override nonReentrant whenNotPaused {
        // emit EarlyRedemptionPerformed(_vestingWallet, msg.sender, redemptionAmount, fee);
    }

    /**
     * @dev 获取锁仓钱包的释放状态
     * @param _vestingWallet 锁仓钱包地址
     */
     function getVestingStatus(address _vestingWallet) external view returns (
        uint256 total,
        uint256 released,
        uint256 releasable
    ) {
        
        require(vestingInfos[_vestingWallet].beneficiary != address(0), "Invalid vesting wallet");
        
        VestingWallet wallet = VestingWallet(payable(_vestingWallet));
        address tokenAddress = address(patToken);

        total = vestingInfos[_vestingWallet].totalAmount; // 总量
        released = wallet.released(tokenAddress);         // 已释放
        releasable = wallet.releasable(tokenAddress);     // 可释放
        
        return (total, released, releasable);
        
    }

    /**
     * @dev 释放锁仓钱包中的代币（由多签钱包或所有者调用）
     * @param _vestingWallet 锁仓钱包地址
     */
    function releaseVestedTokens(address _vestingWallet) external onlyInvestorSalePool {
        // 检查锁仓钱包是否有效
        require(vestingInfos[_vestingWallet].beneficiary != address(0), "Invalid vesting wallet");
        
        // 检查是否已经提前赎回
        require(!vestingInfos[_vestingWallet].isEarlyRedeemed, "Already early redeemed");
        
        // 获取锁仓钱包实例
        VestingWallet wallet = VestingWallet(payable(_vestingWallet));
        address tokenAddress = address(patToken);
        
        // 检查是否有可释放的代币
        uint256 releasableAmount = wallet.releasable(tokenAddress);
        require(releasableAmount > 0, "No tokens to release");
        
        // 释放代币
        // createWallet的时候 通过 Owneable 指定了 _beneficiary 就是 owner
        // 所以 这里的 release 就是 owner 调用的
        wallet.release(tokenAddress);
        
        emit TokensReleased(_vestingWallet, vestingInfos[_vestingWallet].beneficiary, releasableAmount);
    }
    
    /**
     * @dev 设置提前赎回费率
     * @param _earlyRedemptionFeeBps 新的提前赎回费率（基点）
     */
    function setEarlyRedemptionFee(uint256 _earlyRedemptionFeeBps) public override onlyMultiSigOrOwner whenNotPaused {
        require(_earlyRedemptionFeeBps <= 10000, "Fee cannot exceed 100%");
        uint256 oldFee = earlyRedemptionFeeBps;
        earlyRedemptionFeeBps = _earlyRedemptionFeeBps;
        emit EarlyRedemptionFeeUpdated(oldFee, _earlyRedemptionFeeBps);
    }

     /**
     * @dev 获取受益人的所有锁仓钱包
     * @param _beneficiary 受益人地址
     */
    function getBeneficiaryVestingWallets(address _beneficiary) public view override returns (address[] memory) {
        return beneficiaryVestingWallets[_beneficiary];
    }

    /**
     * @dev 获取池子的所有锁仓钱包
     * @param _poolType 池子类型
     */
    function getPoolVestingWallets(PATStorage.PoolType _poolType) public view override returns (address[] memory) {
        return poolVestingWallets[_poolType];
    }

     /**
     * @dev 暂停合约
     */
    function pause() external override onlyOwner {
        _pause();
    }
    
    /**
     * @dev 恢复合约
     */
    function unpause() external override onlyOwner {
        _unpause();
    }

    /**
     * @dev 升级合约
     * @param newImplementation 新合约地址
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}