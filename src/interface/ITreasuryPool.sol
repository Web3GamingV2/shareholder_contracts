// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ITreasuryPool {
    function depositUSDT(address user, uint256 _usdtAmount, uint256 _patAmount) external;
    function getUserPatBalance(address user) external view returns (uint256);
    function calculateRedemptionAmount(address user, uint256 _patBalance) external view returns (uint256);
    function redeemPAT(address user, uint256 _patBalance, uint256 _usdtAmount) external;
}