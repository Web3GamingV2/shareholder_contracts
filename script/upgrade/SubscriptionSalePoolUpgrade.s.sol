// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {SubscriptionSalePoolUpgrades} from "../../src/sale/upgrade/SubscriptionSalePoolUpgrades.sol";
import { SubscriptionSalePoolAddr } from "../address.sol";

/**
 * @title 升级InvestorSalePool合约脚本
 * @dev 升级InvestorSalePool合约脚本
 * forge script script/upgrade/SubscriptionSalePoolUpgrade.s.sol:SubscriptionSalePoolUpgradesScripts --rpc-url $WEB3GAMING_ALCHEMY_RPC_URL --private-key $WEB3GAMING_PRIVATE_KEY --broadcast --verify --etherscan-api-key $WEB3GAMING_ETHERSCAN_API_KEY

== Return ==
0: address 0xc092Fa1E618fDa7524B573d7e43393b77B3B5Bf1

== Logs ==
  Deploying contracts with the account: 0x355eb1c3D6dF0642b3abe2785e821C574837C79f
  SubscriptionSalePoolUpgrades Proxy deployed to: 0x16bce603fb64F37c6A8Cf7bEa0151d657558AaC9
  SubscriptionSalePoolUpgrades Implementation deployed to: 0xc092Fa1E618fDa7524B573d7e43393b77B3B5Bf1
  SubscriptionSalePoolUpgrades Owner set to: 0x355eb1c3D6dF0642b3abe2785e821C574837C79f

  cast call --rpc-url $WEB3GAMING_ALCHEMY_RPC_URL 0x16bce603fb64F37c6A8Cf7bEa0151d657558AaC9 "getContractPatBalance()(uint256)"
  cast call --rpc-url $WEB3GAMING_ALCHEMY_RPC_URL 0x16bce603fb64F37c6A8Cf7bEa0151d657558AaC9 "getSubscription(uint256)(uint256,address,uint256,uint256)" 1
  cast send --rpc-url $WEB3GAMING_ALCHEMY_RPC_URL --private-key $WEB3GAMING_PRIVATE_KEY 0x16bce603fb64F37c6A8Cf7bEa0151d657558AaC9 "transferAllPatToInvestorPool()()"
  cast send --rpc-url $WEB3GAMING_ALCHEMY_RPC_URL --private-key $WEB3GAMING_PRIVATE_KEY 0x16bce603fb64F37c6A8Cf7bEa0151d657558AaC9 "cleanupExpiredSubscription(uint256)()" 1
 */

contract SubscriptionSalePoolUpgradesScripts is Script {

    function run() external returns (address) {
      string memory privateKey = vm.envString("WEB3GAMING_PRIVATE_KEY");
        uint256 deployerPrivateKey = vm.parseUint(string.concat("0x", privateKey));
        address deployerAddress = vm.addr(deployerPrivateKey);
        console.log("Deploying contracts with the account: %s", deployerAddress);

        vm.startBroadcast(deployerPrivateKey);

         Upgrades.upgradeProxy(
            SubscriptionSalePoolAddr,
            "SubscriptionSalePoolUpgrades.sol:SubscriptionSalePoolUpgrades",
            ""
        );

        console.log("SubscriptionSalePoolUpgrades Proxy deployed to:", SubscriptionSalePoolAddr);
        address implementation = Upgrades.getImplementationAddress(SubscriptionSalePoolAddr);
        console.log("SubscriptionSalePoolUpgrades Implementation deployed to:", implementation);
        console.log("SubscriptionSalePoolUpgrades Owner set to:", deployerAddress);

        vm.stopBroadcast();

        return implementation;
    }
}