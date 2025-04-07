// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPAXInterface is IERC20 {
    
    error SBNGC_PAXToken_InvalidAddress();
    error SBNGC_PAXToken_NotBSCChain(uint256 currentChainId);
    error SBNGC_PAXToken_BurnOrMintNotTreasuryPool(address from);
    error SBNGC_PAXToken_ImproperlyInitialized();

    event MintPerformed(address indexed recipient, uint256 amount, uint256 newTotalSupply);
    event BurnPerformed(address indexed recipient, uint256 amount, uint256 newTotalSupply);
    event TreasuryPoolChanged(address indexed from, address indexed oldPool, address indexed newPool);
    event ContractUpgraded(address indexed from, address indexed newContract);
    event AllowedRecipientsUpdated(address indexed from, address indexed minter, bool isAllowed);
    event SBNGC_PAXToken_CoefficientNumeratorTooLarge(uint256 coefficientNumerator, uint256 coefficientDenominator);

    function setCoefficientNumerator(uint256 coefficientNumerator) external;
    function setTreasuryPool(address _treasuryPool) external;

    function mint(address _recipient, uint256 _amount) external;
    function burn(address user, uint256 _amount) external;

    function pause() external;
    function unpause() external;

}