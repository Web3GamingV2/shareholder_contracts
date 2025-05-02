// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {InvestorSalePoolUpgrades} from "../../src/sale/upgrade/InvestorSalePoolUpgrades.sol";
import { InvestorSalePoolAddr } from "../address.sol";

/**
 * @title 升级InvestorSalePool合约脚本
 * @dev 升级InvestorSalePool合约脚本
 * forge script script/upgrade/InvestorSalePoolUpgrade.s.sol:InvestorSalePoolUpgradesScripts --rpc-url $WEB3GAMING_ALCHEMY_RPC_URL --private-key $WEB3GAMING_PRIVATE_KEY --broadcast --verify --etherscan-api-key $WEB3GAMING_ETHERSCAN_API_KEY

== Return ==
0: address 0x7c0a97eC6eBBb6d6c246936c162DbDFfC55442Cf

== Logs ==
  Deploying contracts with the account: 0x355eb1c3D6dF0642b3abe2785e821C574837C79f
  InvestorSalePoolUpgrades Proxy deployed to: 0xC711619c140663737aDe3b54A4B4974C0FC58D8A
  InvestorSalePoolUpgrades Implementation deployed to: 0x7c0a97eC6eBBb6d6c246936c162DbDFfC55442Cf
  InvestorSalePoolUpgrades Owner set to: 0x355eb1c3D6dF0642b3abe2785e821C574837C79f

  cast call --rpc-url $WEB3GAMING_ALCHEMY_RPC_URL 0xC711619c140663737aDe3b54A4B4974C0FC58D8A "version()(string memory)" 
  cast call --rpc-url $WEB3GAMING_ALCHEMY_RPC_URL 0xC711619c140663737aDe3b54A4B4974C0FC58D8A "getSubscriptionSalePool()(address)"
  cast call --rpc-url $WEB3GAMING_ALCHEMY_RPC_URL 0xC711619c140663737aDe3b54A4B4974C0FC58D8A "getContractPatBalance()(uint256)"
  cast send --rpc-url $WEB3GAMING_ALCHEMY_RPC_URL --private-key $WEB3GAMING_PRIVATE_KEY 0xC711619c140663737aDe3b54A4B4974C0FC58D8A "setSubscriptionSalePool(address)" 0x16bce603fb64F37c6A8Cf7bEa0151d657558AaC9
  cast send --rpc-url $WEB3GAMING_ALCHEMY_RPC_URL --private-key $WEB3GAMING_PRIVATE_KEY 0xC711619c140663737aDe3b54A4B4974C0FC58D8A "setSaleActive(bool)" true
  cast send --rpc-url $WEB3GAMING_ALCHEMY_RPC_URL --private-key $WEB3GAMING_PRIVATE_KEY 0xC711619c140663737aDe3b54A4B4974C0FC58D8A "createSubscriptionRequest(address,uint256)(uint256)" 0x355eb1c3D6dF0642b3abe2785e821C574837C79f 1200
 */

contract InvestorSalePoolUpgradesScripts is Script {
    function run() external returns (address) {
      string memory privateKey = vm.envString("WEB3GAMING_PRIVATE_KEY");
        uint256 deployerPrivateKey = vm.parseUint(string.concat("0x", privateKey));
        address deployerAddress = vm.addr(deployerPrivateKey);
        console.log("Deploying contracts with the account: %s", deployerAddress);

        vm.startBroadcast(deployerPrivateKey);

         Upgrades.upgradeProxy(
            InvestorSalePoolAddr,
            "InvestorSalePoolUpgrades.sol:InvestorSalePoolUpgrades",
            ""
        );

        console.log("InvestorSalePoolUpgrades Proxy deployed to:", InvestorSalePoolAddr);
        address implementation = Upgrades.getImplementationAddress(InvestorSalePoolAddr);
        console.log("InvestorSalePoolUpgrades Implementation deployed to:", implementation);
        console.log("InvestorSalePoolUpgrades Owner set to:", deployerAddress);

        vm.stopBroadcast();

        return implementation;
    }
}