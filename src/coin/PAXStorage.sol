// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

abstract contract PAXStorage { 

    uint256 public constant MAX_COEFFICIENT = 10;

    // @dev 链ID 56
    uint256 public constant CHAIN_ID = 11155111;

    // @dev 合约地址
    address public treasuryPool;

    /// @dev The total supply of SBNG that has been minted.
    uint256 public mintedSupply;

    /// @dev The total supply of SBNG that has been burned.
    uint256 public burnedSupply;

    /// @dev 系数
    uint256 public coefficientNumerator;    // 分子：3
    uint256 public coefficientDenominator;  // 分母：1000

    // @dev 允许的池子地址
    mapping (address => bool) allowedRecipients;

    /// @dev 低位槽预留
    uint256[100] private __gap;


}