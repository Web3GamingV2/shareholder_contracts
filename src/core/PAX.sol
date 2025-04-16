// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./PAXStorage.sol";
import "../interface/IPAX.sol";

contract PAX is 
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    OwnableUpgradeable,
    ERC20PermitUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    PAXStorage,
    IPAXInterface
{
    string private constant NAME = "SBNGPAXCoin";
    string private constant SYMBOL = "PAX";

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    modifier onlyBSCChain() {
        require(block.chainid == 56, SBNGC_PAXToken_NotBSCChain(block.chainid));
        _;
    }

    modifier onlyAllowedTreasuryPool() {
        require(msg.sender == treasuryPool, SBNGC_PAXToken_BurnOrMintNotTreasuryPool(msg.sender));
        _;
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    function initialize(
        address _owner,
        address _treasuryPool
    ) public initializer {
        require(_owner != address(0), SBNGC_PAXToken_ImproperlyInitialized());
        require(_treasuryPool != address(0), SBNGC_PAXToken_ImproperlyInitialized());
        __ERC20_init(NAME, SYMBOL);
        __ERC20Burnable_init();
        __Ownable_init(_owner);
        __ERC20Permit_init(NAME);
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        treasuryPool = _treasuryPool;
    }

    // 重新设置赎回池地址
    function setTreasuryPool(address _treasuryPool) external onlyOwner {
        address _oldTreasuryPool = treasuryPool;
        treasuryPool = _treasuryPool;
        emit TreasuryPoolChanged(msg.sender, _oldTreasuryPool, _treasuryPool);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address _recipient, uint256 _amount) public onlyBSCChain onlyAllowedTreasuryPool {
        _mint(_recipient, _amount);
    }

    function burn(address user, uint256 _amount) public onlyBSCChain() onlyAllowedTreasuryPool {
        _burn(user, _amount);
    }

     // 添加 UUPS 所需的授权升级函数
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {
        // 可以添加额外的升级条件
        emit ContractUpgraded(msg.sender, newImplementation);
    }

    // 添加 _beforeTokenTransfer 函数以支持暂停功能
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override whenNotPaused {
        super._update(from, to, amount);
    }

}