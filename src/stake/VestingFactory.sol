// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/finance/VestingWallet.sol";

import "../interface/IPAT.sol";
import "../interface/IRedemptionPool.sol";
import "./VestingFactoryStorage.sol";

contract VestingFactory is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    VestingFactoryStorage
{
    using SafeERC20 for IPATInterface;

     // 修饰符：仅限多签钱包或所有者
    modifier onlyMultiSigOrOwner() {
        require(msg.sender == multiSigWallet || msg.sender == owner(), "Not multisig or owner");
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
        address _patToken,
        address _multiSigWallet,
        uint256 _earlyRedemptionFeeBps
    ) initializer public {
        require(_patToken != address(0), "Invalid PAT token address");
        require(_multiSigWallet != address(0), "Invalid multisig wallet address");
        require(_earlyRedemptionFeeBps <= 10000, "Fee cannot exceed 100%");
        
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        
       __VestingFactoryStorage_init(_patToken, _multiSigWallet, _earlyRedemptionFeeBps);
        
        // 一期只设置投资人池配置
        _setPoolConfig(PoolType.INVESTOR, 0, 365 days, 0, true, true);  // 投资人池：无悬崖期，1年线性释放，无初始释放，可提前赎回
        
        // 其他池子配置预留，但设置为非激活状态
        _setPoolConfig(PoolType.DIRECT, 180 days, 730 days, 0, false, false);
        _setPoolConfig(PoolType.LIQUIDITY, 0, 365 days, 1000, true, false);
        _setPoolConfig(PoolType.FOUNDATION, 90 days, 365 days, 0, false, false);
        _setPoolConfig(PoolType.RESERVE, 0, 730 days, 0, false, false);
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
        PoolType _poolType,
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
        PoolType _poolType,
        uint64 _cliffDuration,
        uint64 _vestingDuration,
        uint256 _initialRelease,
        bool _canEarlyRedeem
    ) public override onlyMultiSigOrOwner whenNotPaused {
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
        uint64 _startTimestamp
    ) public onlyMultiSigOrOwner whenNotPaused nonReentrant returns (address) {

        require(_beneficiary != address(0), "Invalid beneficiary");
        require(_amount > 0, "Amount must be > 0");
        require(poolConfigs[PoolType.INVESTOR].isActive, "Investor pool not active");
        
        PoolInfo memory poolInfo = poolConfigs[PoolType.INVESTOR];
        
        // 创建锁仓钱包
        uint64 vestingStart = _startTimestamp + poolInfo.cliffDuration;
        uint64 vestingEnd = vestingStart + poolInfo.vestingDuration;

        // 检查锁仓金额是否超过池子限制
        require(_startTimestamp >= block.timestamp + 0.5 hours, "Start timestamp must be in the future");
        require(_startTimestamp <= block.timestamp + poolInfo.vestingDuration + poolInfo.cliffDuration, "Start timestamp too far in the future");

        address vestingWallet = address(new VestingWallet(
            _beneficiary,
            vestingStart,
            poolInfo.vestingDuration
        ));

        // 记录锁仓信息
        vestingInfos[vestingWallet] = VestingInfo({
            poolType: PoolType.INVESTOR,
            beneficiary: _beneficiary,
            startTime: vestingStart,
            endTime: vestingEnd,
            totalAmount: _amount,
            isEarlyRedeemed: false
        });
        
        // // 检查多签账户中是否有足够的代币
        // uint256 userBalance = patToken.balanceOf(msg.sender);
        // uint256 userAllowance = patToken.allowance(msg.sender, address(this));
        // require(userBalance >= _amount, "Insufficient token balance");
        // require(userAllowance >= _amount, "Insufficient token allowance");

        // 转移代币到锁仓钱包
        // patToken.safeTransferFrom(msg.sender, vestingWallet, _amount);

        poolVestingWallets[PoolType.INVESTOR].push(vestingWallet);
        beneficiaryVestingWallets[_beneficiary].push(vestingWallet);

        emit VestingWalletCreated(PoolType.INVESTOR, vestingWallet, _beneficiary, _amount);

        return vestingWallet;
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
        uint64 _startTimestamp
    ) public onlyMultiSigOrOwner whenNotPaused nonReentrant {
        require(_beneficiaries.length == _amounts.length, "Arrays length mismatch");
        require(_beneficiaries.length > 0, "Empty arrays");
        require(poolConfigs[PoolType.INVESTOR].isActive, "Investor pool not active");
        // TODO 有一个锁仓钱包失败 是否全部revert掉了
         for (uint256 i = 0; i < _beneficiaries.length; i++) {
            if (_beneficiaries[i] != address(0) && _amounts[i] > 0) {
                createVestingWallet(_beneficiaries[i], _amounts[i], _startTimestamp);
            }
        }
    }

     /**
     * @dev 提前赎回锁仓代币（由受益人调用）
     * @param _vestingWallet 锁仓钱包地址
     */
     function earlyRedeem(address _vestingWallet) public override nonReentrant whenNotPaused {
         VestingInfo storage info = vestingInfos[_vestingWallet];

          // 检查是否是受益人
        require(info.beneficiary == msg.sender, "Not beneficiary");
        
        // 检查是否可以提前赎回
        require(poolConfigs[info.poolType].canEarlyRedeem, "Early redemption not allowed");

        // 检查是否已经提前赎回
        require(!info.isEarlyRedeemed, "Already redeemed");

         // 获取锁仓钱包中的代币余额
        uint256 balance = patToken.balanceOf(_vestingWallet);
        require(balance > 0, "No tokens to redeem");

        // 计算提前赎回手续费
        // TODO 所有子合约池的提前赎回手续费是否一样
        uint256 fee = (balance * earlyRedemptionFeeBps) / 10000;
        uint256 redemptionAmount = balance - fee;

        // 标记为已提前赎回
        info.isEarlyRedeemed = true;
        
        // TODO 用一个代理合约来处理 或者 自定义的VestingWallet实现 why?

        // // 转账赎回金额给受益人
        // patToken.safeTransferFrom(_vestingWallet, msg.sender, redemptionAmount);

        //  // 转账费用给赎回池
        // if (fee > 0) {
        //     patToken.safeTransferFrom(_vestingWallet, address(redemptionPool), fee);
        // }

        emit EarlyRedemptionPerformed(_vestingWallet, msg.sender, redemptionAmount, fee);
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

        total = vestingInfos[_vestingWallet].totalAmount;
        released = wallet.released(tokenAddress);
        releasable = wallet.releasable(tokenAddress);
        
        return (total, released, releasable);
        
    }

    function releaseVestedTokens(address _vestingWallet) external onlyMultiSigOrOwner {
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
    function getPoolVestingWallets(PoolType _poolType) public view override returns (address[] memory) {
        return poolVestingWallets[_poolType];
    }

     /**
     * @dev 暂停合约
     */
    function pause() external override onlyMultiSigOrOwner {
        _pause();
    }
    
    /**
     * @dev 恢复合约
     */
    function unpause() external override onlyMultiSigOrOwner {
        _unpause();
    }

    /**
     * @dev 升级合约
     * @param newImplementation 新合约地址
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}