// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// import { OAppCore } from "layerzero-v2/packages/layerzero-v2/evm/oapp/contracts/oapp/OAppCore.sol";
// import { ILayerZeroEndpointV2 } from "layerzero-v2/packages/layerzero-v2/evm/oapp/contracts/oapp/interfaces/IOAppCore.sol";

// /// @title OAppUpgradeable
// /// @notice 可升级的 LayerZero V2 OApp 基类，适用于所有 UUPS Proxy 合约
// abstract contract OAppUpgradeable is
//     Initializable,
//     OwnableUpgradeable,
//     UUPSUpgradeable,
//     OAppCore
// {
//     /// @dev constructor 禁用初始化（用于 UUPS Proxy 模式）
//     constructor(address _endpoint) OAppCore(ILayerZeroEndpointV2(_endpoint)) {
//         _disableInitializers();
//     }

//     /// @dev 初始化方法，请在子合约中调用
//     function __OAppUpgradeable_init(address _owner) internal onlyInitializing {
//         __Ownable_init(_owner);
//         __UUPSUpgradeable_init();
//     }

//     /// @dev 授权升级，仅限 owner
//     function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

//     /// @dev 公开设置远程 OApp 地址
//     function setPeer(uint32 _eid, bytes32 _peer) external onlyOwner {
//         _setPeer(_eid, _peer);
//     }

//     /// @dev 设置 LayerZero config
//     function setConfig(uint32 _eid, uint32 _configType, bytes calldata _config) external onlyOwner {
//         _setConfig(_eid, _configType, _config);
//     }

//     /// @dev 设置 UA Options
//     function setOptions(uint32 _eid, bytes calldata _options) external onlyOwner {
//         _setOptions(_eid, _options);
//     }
// }

contract OAppUpgradeable {}