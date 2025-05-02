// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/Strings.sol";
import { SubscriptionSalePool } from "../SubscriptionSalePool.sol";

/// @custom:oz-upgrades-from SubscriptionSalePool
contract SubscriptionSalePoolUpgrades is SubscriptionSalePool {
    function version() external virtual override view returns (string memory) {
         return string.concat("2.0.0_", Strings.toString(block.timestamp));
    }
}