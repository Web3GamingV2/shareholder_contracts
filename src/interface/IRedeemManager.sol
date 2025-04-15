// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../core/PATStorage.sol";

interface IRedeemManager {
    // 赎回状态枚举
    enum RedemptionStatus {
        PENDING,
        COMPLETED,
        FAILED
    }
    
    /**
     * @dev 创建赎回请求
     * @param _user 用户地址
     * @param _patAmount PAT金额
     * @param _usdtAmount USDT金额
     * @param _interestPortion 利息部分
     * @param _userType 用户类型
     * @param _sourcePool 来源池
     * @return requestId 请求ID
     */
    function createRedemptionRequest(
        address _user,
        uint256 _patAmount,
        uint256 _usdtAmount,
        uint256 _interestPortion,
        PATStorage.PoolType _userType,
        address _sourcePool
    ) external returns (bytes32);
    
    /**
     * @dev 确认赎回成功
     * @param _requestId 请求ID
     */
    function confirmRedemptionSuccess(bytes32 _requestId) external;
    
    /**
     * @dev 确认赎回失败
     * @param _requestId 请求ID
     */
    function confirmRedemptionFailure(bytes32 _requestId) external;
    
    /**
     * @dev 获取赎回请求状态
     * @param _requestId 请求ID
     * @return 请求状态
     */
    function getRedemptionStatus(bytes32 _requestId) external view returns (RedemptionStatus);
    
    /**
     * @dev 获取赎回请求详情
     * @param _requestId 请求ID
     * @return user 用户地址
     * @return patAmount PAT金额
     * @return usdtAmount USDT金额
     * @return status 状态
     */
    function getRedemptionDetails(bytes32 _requestId) external view returns (
        address user,
        uint256 patAmount,
        uint256 usdtAmount,
        RedemptionStatus status
    );
}