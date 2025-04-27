// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title 申购销售池接口
 * @dev 定义了与申购销售池交互的标准函数
 */
interface ISubscriptionSalePool {
    /**
     * @notice 创建一个新的申购记录
     * @dev 此函数应由授权的销售合约（如 InvestorSalePool）调用。
     * @dev 调用者（销售合约）必须先授权本合约转移相应数量的PAT代币。
     * @param _subscriber 申购人的地址
     * @param _patAmount 申购的PAT代币数量
     * @param _usdtAmount 申购需要支付的USDT数量
     * @param _tier 申购对应的投资者等级
     * @return expiryTimestamp 申购记录的过期时间戳
     */
    function createSubscription(
        address _subscriber,
        uint256 _patAmount,
        uint256 _usdtAmount,
        uint8 _tier
    ) external returns (uint256 expiryTimestamp);

    function confirmSubscription(uint256 _subscriptionId) external returns (
        address _subscriber,
        uint256 _patAmount,
        uint256 _usdtAmount,
        uint8 _tier,
        address _vestingWallet
    );

    // --- 可以根据需要添加其他外部可调用函数的接口定义 ---

    // 例如，如果需要从外部查询申购状态：
    // function getSubscriptionStatus(uint256 _subscriptionId) external view returns (SubscriptionStatus status);
    // 注意：如果添加了返回结构体或枚举的函数，需要在接口文件中也定义它们，或者导入定义它们的合约/库。

    // 例如，如果允许外部触发清理过期记录：
    // function cleanupExpiredSubscription(uint256 _subscriptionId) external;
}