// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/Strings.sol";
import { InvestorSalePool } from "../InvestorSalePool.sol";

/// @custom:oz-upgrades-from InvestorSalePool
contract InvestorSalePoolUpgrades is InvestorSalePool {
    function version() external virtual override view returns (string memory) {
         return string.concat("3.0.0_", Strings.toString(block.timestamp));
    }
}