// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/Strings.sol";
import { VestingFactory } from "../VestingFactory.sol";

/// @custom:oz-upgrades-from VestingFactory
contract VestingFactoryUpgrades is VestingFactory {
    function version() external virtual override view returns (string memory) {
         return string.concat("2.0.0_", Strings.toString(block.timestamp));
    }
}