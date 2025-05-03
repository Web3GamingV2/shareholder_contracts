// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

uint256 constant usdtDecimal = 10 ** 6;
uint256 constant patDecimal = 10 ** 6;

library Calculate {
    // 按照投资人的 USDT 数量分级计算购买的FCC数量
    function calculatePatByUsdt(uint256 _usdtAmount) internal pure returns (uint256) {
        if (_usdtAmount >= 100_000 * usdtDecimal) { // Tier 1: 1 FCC = 0.6 USDT
            // patAmount = usdtAmount / 0.6 = (usdtAmount * 10 * patDecimal) / (6 * usdtDecimal)
            return (_usdtAmount * 10 * patDecimal) / (6 * usdtDecimal);
        } else if (_usdtAmount < 100_000 * usdtDecimal && _usdtAmount >= 10_000 * usdtDecimal) { // Tier 2: 1 FCC = 0.7 USDT
            // patAmount = usdtAmount / 0.7 = (usdtAmount * 10 * patDecimal) / (7 * usdtDecimal)
            return (_usdtAmount * 10 * patDecimal) / (7 * usdtDecimal);
        } else if (_usdtAmount < 10_000 * usdtDecimal && _usdtAmount >= 5_000 * usdtDecimal) { // Tier 3: 1 FCC = 0.8 USDT
            // patAmount = usdtAmount / 0.8 = (usdtAmount * 10 * patDecimal) / (8 * usdtDecimal)
            return (_usdtAmount * 10 * patDecimal) / (8 * usdtDecimal);
        } else if (_usdtAmount < 5_000 * usdtDecimal && _usdtAmount >= 1_000 * usdtDecimal) { // Tier 4: 1 FCC = 0.9 USDT
            // patAmount = usdtAmount / 0.9 = (usdtAmount * 10 * patDecimal) / (9 * usdtDecimal)
            return (_usdtAmount * 10 * patDecimal) / (9 * usdtDecimal);
        } else if (_usdtAmount < 1_000 * usdtDecimal && _usdtAmount > 0 * usdtDecimal) { // Tier 5: 1 FCC = 1 USDT
            // patAmount = usdtAmount / 1 = (usdtAmount * patDecimal) / usdtDecimal
            // Since patDecimal == usdtDecimal, this simplifies to _usdtAmount
            // However, to maintain consistency and avoid potential precision issues if decimals differ later, use the division.
            return (_usdtAmount * patDecimal) / usdtDecimal;
        } else {
            return 0;
        }
    }

    // 按照投资人的希望购买的FCC数量分级计算 需要多少 USDT
    function calculateUsdtByPat(uint256 _patAmount) internal pure returns (uint256) {
        if (_patAmount >= 5_000_000 * patDecimal) { // tier1: 1 FCC = 0.06 USDT
            return (_patAmount * 6 * usdtDecimal) / (100 * patDecimal);
        } else if (_patAmount < 5_000_000 * patDecimal && _patAmount >= 250_000 * patDecimal) { // tier2: 1 FCC = 0.07 USDT
            return (_patAmount * 7 * usdtDecimal) / (100 * patDecimal);
        } else if (_patAmount < 250_000 * patDecimal && _patAmount >= 100_000 * patDecimal) { // tier3: 1 FCC = 0.08 USDT
            return (_patAmount * 8 * usdtDecimal) / (100 * patDecimal);
        } else if (_patAmount < 100_000 * patDecimal && _patAmount >= 16_666 * patDecimal) { // tier4: 1 FCC = 0.09 USDT
            return (_patAmount * 9 * usdtDecimal) / (100 * patDecimal);
        } else if (_patAmount < 16_666 * patDecimal && _patAmount > 0 * patDecimal) { // tier5: 1 FCC = 0.1 USDT
            return (_patAmount * 10 * usdtDecimal) / (100 * patDecimal);
        } else {
            return 0;
        }
    }
}