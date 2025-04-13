// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// TODO: 这一期由于 4 方支持 TRX 放到另一个 tron 的仓库，所以暂时先这样写
interface IRedemptionPool {
    function redeem(uint256 _amount) external;
}
