
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../interface/IPAT.sol";
import "../interface/IVestingFactory.sol";
import "../core/PATStorage.sol";

abstract contract VestingFactoryStorage is Initializable, IVestingFactory {
    
    // PAT代币合约
    IPATInterface public patToken;

    // 多签钱包地址
    address public multiSigWallet;

    // 提前赎回费率（基点，10000=100%）
    uint256 public earlyRedemptionFeeBps;

    // 池子类型到配置的映射
    mapping(PATStorage.PoolType => PoolInfo) public poolConfigs;

    // 锁仓钱包地址到锁仓信息的映射
    mapping(address => VestingInfo) public vestingInfos;

    // 池子类型到锁仓钱包的映射
    mapping(PATStorage.PoolType => address[]) public poolVestingWallets;

    // 受益人地址到其锁仓钱包的映射
    mapping(address => address[]) public beneficiaryVestingWallets;

    // 授权管理员映射 - 一期先预留，暂不使用
    mapping(address => bool) public authorizedAdmins;

    // 用于存储实现版本的变量
    uint256 public version;

    function __VestingFactoryStorage_init(
        address _patToken,
        address _multiSigWallet,
        uint256 _earlyRedemptionFeeBps
    ) internal initializer {
        patToken = IPATInterface(_patToken);
        multiSigWallet = _multiSigWallet;
        earlyRedemptionFeeBps = _earlyRedemptionFeeBps;
        version = 1;
    }
    
    // 保留的存储槽位，用于未来扩展
    uint256[50] private __gap;

}