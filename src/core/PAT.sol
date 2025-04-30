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

import "./PATStorage.sol";
import "../interface/IPAT.sol";

contract PAT is 
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    OwnableUpgradeable,
    ERC20PermitUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    PATStorage,
    IPATInterface {

    string private constant NAME = "SBNGPATCoin";
    string private constant SYMBOL = "PAT";

     /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    modifier onlyEthereumChain() {
        require(block.chainid == CHAIN_ID, SBNGC_PATToken_NotBSCChain(block.chainid));
        _;
    }

    // 只能通过指定的池子销毁
    modifier onlyAllowedRecipients(address _recipient) {
        require(allowedRecipients[_recipient], SBNGC_PATToken_NotAllowedRecipientsAddress(_recipient));
        _;
    }

    modifier onlyAllowedMultiSigWalletAndOwnCall(address _multiSigWallet) {
        require(msg.sender == _multiSigWallet || msg.sender == owner(), SBNGC_PATToken_NotAllowedMultiSigWallet(msg.sender));
        _;
    }

    modifier onlyAllowedMultiSigWalletCall(address _multiSigWallet) {
        require(msg.sender == _multiSigWallet, SBNGC_PATToken_NotAllowedMultiSigWallet(msg.sender));
        _;
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    function version() external virtual pure returns (uint256) {
        return 1;
    }

    function initialize(address _owner, address _multiSigWallet) initializer public {
        require(_owner != address(0), SBNGC_PATToken_ImproperlyInitialized());
        require(_multiSigWallet!= address(0), SBNGC_PATToken_ImproperlyInitialized());
        __ERC20_init(NAME, SYMBOL);
        __ERC20Burnable_init();
        __Ownable_init(_owner);
        __ERC20Permit_init(NAME);
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        __PATStorage_init(_multiSigWallet);
    }

    // 铸币 只能由指定的地址触发 mint 调用 到指定的池子里
    function mint(address _recipient, uint256 _amount) external 
        onlyAllowedRecipients(_recipient)
        onlyAllowedMultiSigWalletAndOwnCall(multiSigWallet) nonReentrant whenNotPaused {
        require(_recipient != address(0), SBNGC_PATToken_InvalidAddress());
        require(_amount > 0, SBNGC_PATToken_ImproperlyInitialized());
        
         // 检查铸造时间间隔
        if (lastMintTime > 0 && block.timestamp < lastMintTime + MIN_MINT_INTERVAL) {
            revert SBNGC_PATToken_MintIntervalNotReached(lastMintTime, block.timestamp, MIN_MINT_INTERVAL);
        }

        // 检查总供应量上限
        require(totalSupply() + _amount <= MAX_SUPPLY, SBNGC_PATToken_MintAmountTooLarge(_amount, MAX_SUPPLY));

        uint256 maximumMintAmount;
        if (totalSupply() == 0) {
            // 初始铸造时没有限制
            maximumMintAmount = MAX_SUPPLY;
        } else {
            maximumMintAmount = (totalSupply() * mintCapNumerator) / MINT_CAP_DENOMINATOR;
        }
        
        // 检查单次铸造上限
        if (_amount > maximumMintAmount) {
            revert SBNGC_PATToken_MintAmountTooLarge(_amount, maximumMintAmount);
        }

        _mint(_recipient, _amount);
        mintedSupply += _amount;
        lastMintTime = block.timestamp;

        emit MintPerformed(_recipient, _amount, totalSupply());
    }

    // 销毁 由赎回池调用
    function burn(address addrPool, uint256 _amount) external onlyAllowedRecipients(addrPool) nonReentrant whenNotPaused {

        require(addrPool!= address(0), SBNGC_PATToken_InvalidAddress());
        require(_amount > 0, SBNGC_PATToken_ImproperlyInitialized());
        require(_amount <= balanceOf(addrPool), SBNGC_PATToken_InsufficientAllowance(balanceOf(addrPool), _amount));

        _burn(addrPool, _amount);
        burnedSupply += _amount;
        emit Burn(_amount, totalSupply());
    }

    // 重新设置多签钱包地址
    function setMultiSigWallet(address _multiSigWallet) external onlyAllowedMultiSigWalletCall(multiSigWallet) whenNotPaused {
        require(_multiSigWallet != address(0), SBNGC_PATToken_InvalidAddress());
        address oldMultiSigWallet = multiSigWallet;
        multiSigWallet = _multiSigWallet;
        emit MultiSigWalletAdressChanged(msg.sender, oldMultiSigWallet, _multiSigWallet);
    }

    // 重新设置铸币总量上限的分子
    function setMintCapNumerator(uint256 _numerator) external onlyOwner whenNotPaused {
         // 不能超过 5 % 的单次铸造
        if (_numerator > MINT_CAP_MAX_NUMERATOR) {
            revert SBNGC_PATToken_MintCapNumeratorTooLarge(_numerator, MINT_CAP_MAX_NUMERATOR);
        }
        emit MintCapNumeratorChanged(msg.sender, mintCapNumerator, _numerator);
        mintCapNumerator = _numerator;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // 白名单多签控制 设置铸币/销毁地址
    function setAllowedRecipient(address _recipient, bool allowed) external onlyAllowedMultiSigWalletCall(multiSigWallet) whenNotPaused {
        require(_recipient != address(0), SBNGC_PATToken_InvalidAddress());
        allowedRecipients[_recipient] = allowed;
        emit AllowedRecipientsUpdated(msg.sender, _recipient, allowed);
    }

    function isAllowedRecipient(address _recipient) public view returns (bool) {
        return allowedRecipients[_recipient]; 
    }

    // 新增函数实现：获取下一次可以 mint 的时间
    function nextMintTime() external view returns (uint256) {
        // 如果从未 mint 过 (lastMintTime == 0)，则返回 MIN_MINT_INTERVAL
        // 否则返回上次 mint 时间 + 最小间隔
        return lastMintTime + MIN_MINT_INTERVAL;
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