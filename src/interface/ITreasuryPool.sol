// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "../core/PATStorage.sol";

interface ITreasuryPool {
    /**
     * @dev 存入USDT
     * @param _user 用户地址
     * @param _usdtAmount USDT金额
     * @param _patAmount PAT金额
     */
    function depositUSDT(PATStorage.PoolType _userType, address _user, uint256 _usdtAmount, uint256 _patAmount) external;

    /**
     * @dev 获取用户PAT余额
     * @param _user 用户地址
     * @return balance PAT余额
     */
    function getUserPatBalance(address _user) external view returns (uint256);

     /**
     * @dev 获取用户累积利息
     * @param _user 用户地址
     * @return interest 累积利息
     */
    function getUserInterest(address _user) external view returns (uint256);
    
    /**
     * @dev 计算用户的利息
     * @param _user 用户地址
     * @return interestAmount 利息金额
     */
    function calculateInterest(address _user) external view returns (uint256);
    
    /**
     * @dev 更新用户利息
     * @param _user 用户地址
     * @return interestAmount 新增利息金额
     */
    function updateInterest(address _user) external returns (uint256);
    

    /**
     * @dev 计算用户的利息
     * @param _user 用户地址
     * @return interestAmount 利息金额
     */
    function calculateRedemptionAmount(address _user, uint256 _patBalance) external view returns (uint256);

     /**
     * @dev 赎回PAT为USDT
     * @param _user 用户地址
     * @param _patAmount PAT金额
     * @param _usdtAmount USDT金额
     */
    function redeemPAT(address _user, uint256 _patAmount, uint256 _usdtAmount) external returns (uint256);
    
    /**
     * @dev 授权子合约池
     * @param _pool 池地址
     * @param _userType 用户类型
     * @param _isAuthorized 是否授权
     */
    function authorizePool(address _pool, PATStorage.PoolType _userType, bool _isAuthorized) external;
    
    /**
     * @dev 更新Polygon连接器
     * @param _newConnector 新连接器地址
     */
    function updatePolygonConnector(address _newConnector) external;
    
    /**
     * @dev 将USDT转移到L2
     * @param _amount USDT金额
     */
    function transferUSDTToL2(uint256 _amount, address _proxyAddr) external;
    
    /**
     * @dev 接收从L2转移的USDT
     * @param _proxyAddr 发送方地址
     * @param _amount USDT金额
     */
    function receiveUSDTFromL2(address _proxyAddr, uint256 _amount) external;
    
    /**
     * @dev 提取剩余USDT（仅限多签钱包）
     * @param _to 接收地址
     * @param _amount USDT金额
     */
    function withdrawUSDT(address _to, uint256 _amount) external;
    
    /**
     * @dev 获取用户存款数量
     * @param _user 用户地址
     * @return 存款数量
     */
    function getUserDepositCount(address _user) external view returns (uint256);
    
    /**
     * @dev 获取用户存款信息
     * @param _user 用户地址
     * @param _index 存款索引
     * @return patAmount PAT金额
     * @return usdtAmount USDT金额
     * @return timestamp 存款时间
     * @return sourcePool 来源池地址
     * @return userType 用户类型
     */
    function getUserDeposit(address _user, uint256 _index) external view returns (
        uint256 patAmount,
        uint256 usdtAmount,
        uint256 timestamp,
        address sourcePool,
        PATStorage.PoolType userType
    );
    
    /**
     * @dev 获取特定类型的总PAT余额
     * @param _userType 用户类型
     * @return 总PAT余额
     */
    function getTotalPatBalance(PATStorage.PoolType _userType) external view returns (uint256);
    
    /**
     * @dev 获取特定类型的总利息
     * @param _userType 用户类型
     * @return 总利息
     */
    function getTotalInterest(PATStorage.PoolType _userType) external view returns (uint256);
    
    /**
     * @dev 暂停合约
     */
    function pause() external;
    
    /**
     * @dev 恢复合约
     */
    function unpause() external;
}