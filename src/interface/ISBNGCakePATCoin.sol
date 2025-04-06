// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISBNGCakePATCoin is IERC20 {

    error SBNGC_PATToken_ImproperlyInitialized();
    error SBNGC_PATToken_MintAmountTooLarge(uint256 amount, uint256 maximumAmount);
    error SBNGC_PATToken_MintCapNumeratorTooLarge(uint256 numerator, uint256 maximumNumerator);
    error SBNGC_PATToken_BurnNotRedemptionPool(address from);
    error SBNGC_PATToken_MintIntervalNotReached(uint256 lastMintTime, uint256 currentTime, uint256 requiredInterval);
    error SBNGC_PATToken_InvalidAddress();
    error SBNGC_PATToken_InsufficientAllowance(uint256 allowance, uint256 amount);
    error SBNGC_PATToken_NotAllowedMintRecipientsAddress(address from);
    error SBNGC_PATToken_NotAllowedMintMultiSigWallet(address from);
    error SBNGC_PATToken_NotBSCChain(uint256 currentChainId);


    event MintCapNumeratorChanged(address indexed from, uint256 previousMintCapNumerator, uint256 mintCapNumerator);
    event MintPerformed(address indexed recipient, uint256 amount, uint256 newTotalSupply);
    event MultiSigWalletAdressChanged(address indexed from, address indexed oldAddr, address indexed newAddr);
    event RedemptionPoolChanged(address indexed from, address indexed oldPool, address indexed newPool);
    event ContractUpgraded(address indexed from, address indexed newContract);
    event AllowedMintRecipientsUpdated(address indexed from, address indexed minter, bool isAllowed);
    
    // 销毁事件
    event Burn(
        uint256 _burnAmount,
        uint256 _totalSupply
    );

    function setMintCapNumerator(uint256 mintCapNumerator) external;
    function setRedemptionPool(address redemptionPoolAddress) external;
    function setMultiSigWallet(address multiSigWalletAdress) external;

    function mint(address _recipient, uint256 _amount) external;
    function burn(address user, uint256 _amount) external;

    function pause() external;
    function unpause() external;

    function setAllowedMintRecipient(address minter, bool isAllowed) external;
    function allowedMintRecipient(address minter) external view returns (bool);
}