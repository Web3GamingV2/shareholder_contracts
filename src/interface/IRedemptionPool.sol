// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IRedemptionPool {
    function redeem(uint256 _amount) external;
}  