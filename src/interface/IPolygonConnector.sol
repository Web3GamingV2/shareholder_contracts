// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title IPolygonConnector
 * @dev Polygon跨链连接器接口
 */
interface IPolygonConnector {
    /**
     * @dev 将代币桥接到L2
     * @param _token 代币地址
     * @param _amount 金额
     */
    function bridgeTokensToL2(address _token, uint256 _amount) external;
    
    /**
     * @dev 从L2接收代币
     * @param _token 代币地址
     * @param _to 接收地址
     * @param _amount 金额
     */
    function receiveTokensFromL2(address _token, address _to, uint256 _amount) external;
}