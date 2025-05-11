// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {VestingFactoryUpgrades} from "../../src/stake/upgrade/VestingFactoryUpgrades.sol";
import { VestingFactoryAddr } from "../address.sol";

/**
 * @title 升级InvestorSalePool合约脚本
 * @dev 升级InvestorSalePool合约脚本
 * forge script script/upgrade/VestingFactoryUpgrade.s.sol:VestingFactoryUpgradesScripts --rpc-url $WEB3GAMING_ALCHEMY_RPC_URL --private-key $WEB3GAMING_PRIVATE_KEY --broadcast --verify --etherscan-api-key $WEB3GAMING_ETHERSCAN_API_KEY

== Return ==
0: address 0x2Ca1c2Cf81bA8305eA1c7Ec3d8ed7E8200370a75

== Logs ==
  Deploying contracts with the account: 0x355eb1c3D6dF0642b3abe2785e821C574837C79f
  VestingFactoryUpgrades Proxy deployed to: 0x4B860eA39Af4b41EAd50e3f6531eBbc482DA7aF5
  VestingFactoryUpgrades Implementation deployed to: 0x2Ca1c2Cf81bA8305eA1c7Ec3d8ed7E8200370a75
  VestingFactoryUpgrades Owner set to: 0x355eb1c3D6dF0642b3abe2785e821C574837C79f
 
 */

contract VestingFactoryUpgradesScripts is Script {

    function run() external returns (address) {
      string memory privateKey = vm.envString("WEB3GAMING_PRIVATE_KEY");
        uint256 deployerPrivateKey = vm.parseUint(string.concat("0x", privateKey));
        address deployerAddress = vm.addr(deployerPrivateKey);
        console.log("Deploying contracts with the account: %s", deployerAddress);

        vm.startBroadcast(deployerPrivateKey);

         Upgrades.upgradeProxy(
            VestingFactoryAddr,
            "VestingFactoryUpgrades.sol:VestingFactoryUpgrades",
            ""
        );

        console.log("VestingFactoryUpgrades Proxy deployed to:", VestingFactoryAddr);
        address implementation = Upgrades.getImplementationAddress(VestingFactoryAddr);
        console.log("VestingFactoryUpgrades Implementation deployed to:", implementation);
        console.log("VestingFactoryUpgrades Owner set to:", deployerAddress);

        vm.stopBroadcast();

        return implementation;
    }
}