// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// @dev 锁仓池类型
enum PoolType {
    INVESTOR,    // 投资人池 
    DIRECT,      // 直售池
    RESERVE,     // 储备池
    LIQUIDITY,   // 流动性池
    FOUNDATION   // 基金会池
}