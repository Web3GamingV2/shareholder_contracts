// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract PATStorage is Initializable {

    /// @dev 最小铸造时间间隔
    uint256 public constant MIN_MINT_INTERVAL = 1 days; 

    /// @dev The total supply of SBNG. 1亿
    uint256 public constant MAX_SUPPLY = 100_000_000 * 10 ** 6;

    /// @dev 铸币总量上限的分母 表示为  MINT_CAP_MAX_NUMERATOR / MINT_CAP_DENOMINATOR 每次不能超过 10%
    uint256 public constant MINT_CAP_DENOMINATOR = 10_000;

    /// @dev 铸币总量上限的分子的最大值 5% 
    uint256 public constant MINT_CAP_MAX_NUMERATOR = 500;

    // @dev 链ID 56
    uint256 public constant CHAIN_ID = 11155111;

    /// @dev The total supply of SBNG that has been minted.
    uint256 public mintedSupply;

    /// @dev The total supply of SBNG that has been burned.
    uint256 public burnedSupply;

    /// @dev 上一次铸币时间
    uint256 public lastMintTime;    

    /// @dev 铸币总量上限的分子
    uint256 public mintCapNumerator;

    // 添加多签钱包地址
    address public multiSigWallet;

    // @dev 允许的池子地址
    mapping (address => bool) allowedRecipients;

    function __PATStorage_init(address _multiSigWallet) internal initializer {
        // 初始化铸币总量上限的分子
        mintCapNumerator = MINT_CAP_MAX_NUMERATOR;
        // 初始化上一次铸币时间
        lastMintTime = block.timestamp;
        multiSigWallet = _multiSigWallet;
    }

    /// @dev 低位槽预留
    uint256[100] private __gap;

}