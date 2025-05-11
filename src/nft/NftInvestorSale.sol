// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import "../core/Basic.sol";

/**
 * @title NftInvestorSale
 * @dev ERC1155 合约，用于发放投资者销售购买凭证 NFT。
 * 每个凭证代表一次成功的购买，使用不同的 ID 可以区分不同的销售轮次或类型。
 */
contract NftInvestorSale is
    Initializable,
    ERC1155Upgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable, 
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    Basic {

    uint256 public nextTokenId;

    string public _baseURI;

    // 映射：存储每个 token ID 对应的 URI
    mapping(uint256 => string) private _uris;
    
    // 授权铸造者地址
    mapping(address => bool) public minters;

    // 事件：当 URI 更新时触发
    event URIUpdated(uint256 indexed id, string newuri);
    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);

    event MintProof(address indexed to, uint256 indexed currentTokenId, uint256 id, uint256 nextId, uint256 amount, bytes data);
    event MintProofBatch(address indexed to, uint256[] ids, uint256[] amounts);

    // 修饰符：只有授权铸造者可以调用
    modifier onlyMinter(address _minter) {
        require(minters[_minter] || msg.sender == owner(), "Caller is not a minter");
        _;
    }

    modifier hasBasicURI() {
        require(bytes(_baseURI).length > 0, "Base URI is not set");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev 初始化合约
     * @param _owner 合约所有者地址
     * @param _initialBaseURI 初始的基础 URI (可以为空，后续通过 setURI 设置)
     */
    function initialize(
        address _owner,
        string memory _initialBaseURI) public initializer {
        __ERC1155_init(_initialBaseURI);
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        _baseURI = _initialBaseURI;
        nextTokenId = 0;
        minters[_owner] = true;
    }

    /**
     * @dev 设置或更新指定 token ID 的 URI。
     * 只有合约所有者可以调用。
     * @param id 要设置 URI 的 token ID
     * @param newuri 新的 URI 字符串
     */
    function setURI(uint256 id, string memory newuri) external onlyOwner whenNotPaused()  {
        _uris[id] = newuri;
        emit URIUpdated(id, newuri);
    }

    /**
     * @dev 返回指定 token ID 的 URI。
     * 如果为该 ID 设置了特定 URI，则返回该 URI，否则回退到 ERC1155 的基础 URI。
     * @param id 要查询 URI 的 token ID
     * @return URI 字符串
     */
     function uri(uint256 id) public view override returns (string memory) {
        string memory _uri = _uris[id];
        if (bytes(_uri).length > 0) {
            return _uri;
        }
        
        // 获取基础 URI
        string memory baseURI = super.uri(id);
        
        // 如果基础 URI 不包含 {id} 占位符，则手动添加 ID
        if (bytes(baseURI).length > 0) {
            // 注意：这里假设基础 URI 已经包含了 {id} 占位符
            // OpenSea 会自动替换 {id} 为实际的 token ID
            return baseURI;
        }
        
        return "";
    }

    /**
     * @dev 添加铸造者权限
     * @param _minter 要添加的铸造者地址
     */
    function addMinter(address _minter) external onlyOwner {
        require(_minter != address(0), "Invalid minter address");
        minters[_minter] = true;
        emit MinterAdded(_minter);
    }

    /**
     * @dev 移除铸造者权限
     * @param _minter 要移除的铸造者地址
     */
    function removeMinter(address _minter) external onlyOwner {
        minters[_minter] = false;
        emit MinterRemoved(_minter);
    }

    /**
     * @dev 铸造购买凭证 NFT。
     * 只有授权铸造者可以调用。
     * @param to 接收 NFT 的地址
     * @param id 要铸造的凭证类型 ID
     * @param amount 铸造数量（对于凭证通常是 1）
     * @param data 附加数据（可选）
     */
    function mintProof(address to, uint256 id, uint256 amount, bytes memory data) external hasBasicURI() onlyMinter(msg.sender) whenNotPaused {
        require(to != address(0), "Invalid recipient");
        uint256 nextId = nextTokenId;
        uint256 currentTokenId = uint256(keccak256(abi.encode(to, id, nextId)));
        unchecked {
            nextTokenId++;
        }
        _mint(to, currentTokenId, amount, data);
        // 服务端查询直接使用方法 getNftMetadataFromGraph 从 the-graph 事件展示 mint 列表
        emit MintProof(to, currentTokenId, id, nextId, amount, data);
    }

    /**
     * @dev 批量铸造购买凭证 NFT。
     * 只有授权铸造者可以调用。
     * @param to 接收 NFT 的地址
     * @param ids 要铸造的凭证类型 ID 列表
     * @param amounts 每个 ID 对应的铸造数量列表
     * @param data 附加数据（可选）
     */
    function mintProofBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external hasBasicURI() onlyMinter(msg.sender) whenNotPaused {
        require(to != address(0), "Invalid recipient");
        require(ids.length == amounts.length, "IDs and amounts length mismatch");
        _mintBatch(to, ids, amounts, data);
    }

    /**
     * @dev 设置基础 URI
     * @param newBaseURI 新的基础 URI
     */
    function setBaseURI(string memory newBaseURI) external onlyOwner whenNotPaused {
        _baseURI = newBaseURI;
        _setURI(newBaseURI);
    }

    // --- UUPS Upgrade ---
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}