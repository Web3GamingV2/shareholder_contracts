// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import { PoolType } from "../enum/PoolType.sol";

interface ITreasuryPool {
    /**
     * @dev 存入USDT
     * @param _user 用户地址
     * @param _usdtAmount USDT金额
     * @param _patAmount PAT金额
     */
    function depositUSDT(PoolType _userType, address _user, uint256 _usdtAmount, uint256 _patAmount) external;

    /**
     * @dev 获取用户PAT余额
     * @param _user 用户地址
     * @return balance PAT余额
     */
    function getUserPatBalance(address _user) external view returns (uint256);

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
    function redeemPAT(address _user, uint256 _patAmount, uint256 _usdtAmount) external;
}