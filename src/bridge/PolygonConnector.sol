// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { OAppUpgradeable } from "./OAppUpgradeable.sol";

/// @title PolygonConnector
/// @notice 使用 OAppUpgradeable 实现的 LayerZero 跨链通信合约（部署在 Polygon 上）
/// @dev 支持 UUPS 升级、设置 peer、发送和接收消息
contract PolygonConnector is OAppUpgradeable {
    event MessageReceived(uint32 indexed srcEid, bytes32 indexed sender, string message);
    event MessageSent(uint32 indexed dstEid, bytes32 indexed receiver, string message);

    /// @notice 初始化函数，在代理部署时调用
    /// @param _owner 合约 owner 地址
    function initialize(address _endpoint, address _owner) external initializer {
        __OAppUpgradeable_init(_owner);
        endpoint = ILayerZeroEndpointV2(_endpoint); // 必须设置 endpoint（父类构造函数不会自动执行）
    }

    /// @notice 接收 LayerZero 消息的函数
    function _lzReceive(
        Origin calldata _origin,
        bytes32, // guid 不使用
        bytes calldata _message,
        address, // executor 不使用
        bytes calldata // extraData 不使用
    ) internal override {
        string memory decodedMessage = abi.decode(_message, (string));
        emit MessageReceived(_origin.srcEid, _origin.sender, decodedMessage);
    }

    /// @notice 向目标链发送消息
    /// @param _dstEid 目标链的 endpoint ID
    /// @param _message 要发送的字符串信息
    /// @param _fee fee 信息（调用者提前用 quote 估算）
    function sendMessage(
        uint32 _dstEid,
        string calldata _message,
        bytes calldata _options,
        address _refundAddress,
        uint256 _fee
    ) external payable onlyOwner {
        bytes32 receiver = peers[_dstEid];
        require(receiver != bytes32(0), "Receiver not set");

        bytes memory payload = abi.encode(_message);
        _lzSend(
            _dstEid,
            receiver,
            payload,
            _options,
            _refundAddress,
            _fee
        );

        emit MessageSent(_dstEid, receiver, _message);
    }
}
