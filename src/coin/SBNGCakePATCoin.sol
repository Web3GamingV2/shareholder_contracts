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

import "./SBNGCakePATCoinStorage.sol";
import "../interface/ISBNGCakePATCoin.sol";

contract PAT is 
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    OwnableUpgradeable,
    ERC20PermitUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    SBNGCakePATCoinStorage,
    ISBNGCakePATCoin {

    string private constant NAME = "SBNGPATCoin";
    string private constant SYMBOL = "PAT";

     /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    modifier onlyRedemptionPool() {
        require(msg.sender == redemptionPool, SBNGC_PATToken_BurnNotRedemptionPool(msg.sender));
        _;
    }

    modifier onlyAllowedMintRecipients(address _recipient) {
        require(allowedMintRecipients[_recipient], SBNGC_PATToken_NotAllowedMintRecipientsAddress(_recipient));
        _;
    }

    modifier onlyAllowedMultiSigWalletAndOwnCall(address _multiSigWallet) {
        require(msg.sender == _multiSigWallet || msg.sender == owner(), SBNGC_PATToken_NotAllowedMintMultiSigWallet(msg.sender));
        _;
    }

    modifier onlyAllowedMultiSigWalletCall(address _multiSigWallet) {
        require(msg.sender == _multiSigWallet, SBNGC_PATToken_NotAllowedMintMultiSigWallet(msg.sender));
        _;
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    function initialize(address _owner, address _redemptionPool, address _multiSigWallet) initializer public {
        require(_owner != address(0), SBNGC_PATToken_ImproperlyInitialized());
        require(_redemptionPool != address(0), SBNGC_PATToken_ImproperlyInitialized());
        __ERC20_init(NAME, SYMBOL);
        __ERC20Burnable_init();
        __Ownable_init(_owner);
        __ERC20Permit_init(NAME);
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        redemptionPool = _redemptionPool;
        multiSigWallet = _multiSigWallet;
         // 设置默认铸造上限为总供应量的 5%
        mintCapNumerator = MINT_CAP_MAX_NUMERATOR;
    }

    // 铸币
    function mint(address _recipient, uint256 _amount) external 
        onlyAllowedMintRecipients(_recipient) onlyAllowedMultiSigWalletAndOwnCall(multiSigWallet) nonReentrant whenNotPaused {
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
    function burn(address user, uint256 _amount) external onlyRedemptionPool nonReentrant whenNotPaused {

        require(user!= address(0), SBNGC_PATToken_InvalidAddress());
        require(_amount > 0, SBNGC_PATToken_ImproperlyInitialized());
        require(_amount <= balanceOf(user), SBNGC_PATToken_InsufficientAllowance(balanceOf(user), _amount));
        
        // 确保用户已授权赎回池
        uint256 currentAllowance = allowance(user, redemptionPool);

        if (currentAllowance < _amount) {
            revert SBNGC_PATToken_InsufficientAllowance(currentAllowance, _amount);
        }

        _burn(user, _amount);
        burnedSupply += _amount;
        emit Burn(_amount, totalSupply());
    }

    // 重新设置赎回池地址
    function setRedemptionPool(address _redemptionPool) external onlyOwner whenNotPaused {
        require(_redemptionPool!= address(0), SBNGC_PATToken_InvalidAddress());
        address oldRedemptionPool = redemptionPool;
        redemptionPool = _redemptionPool;
        emit RedemptionPoolChanged(msg.sender, oldRedemptionPool, _redemptionPool);
    }

    // 重新设置多签钱包地址
    function setMultiSigWallet(address _multiSigWallet) external onlyAllowedMultiSigWalletCall(multiSigWallet) whenNotPaused {
        require(_multiSigWallet!= address(0), SBNGC_PATToken_InvalidAddress());
        address oldMultiSigWallet = multiSigWallet;
        multiSigWallet = _multiSigWallet;
        emit MultiSigWalletAdressChanged(msg.sender, oldMultiSigWallet, _multiSigWallet);
    }

    // 重新设置铸币总量上限的分子
    function setMintCapNumerator(uint256 _numerator) external onlyOwner whenNotPaused {
         // 不能超过 20 % 的单次铸造
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

    function setAllowedMintRecipient(address _recipient, bool allowed) external onlyOwner whenNotPaused {
        require(_recipient != address(0), SBNGC_PATToken_InvalidAddress());
        allowedMintRecipients[_recipient] = allowed;
        emit AllowedMintRecipientsUpdated(msg.sender, _recipient, allowed);
    }

    function allowedMintRecipient(address _recipient) external view returns (bool) {
        return allowedMintRecipients[_recipient]; 
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