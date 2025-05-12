// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {NftInvestorSaleUpgrades} from "../../src/nft/upgrade/NftInvestorSaleUpgrades.sol";
import { NftInvestorSaleAddr } from "../address.sol";

/**
 * @title 升级InvestorSalePool合约脚本
 * @dev 升级InvestorSalePool合约脚本
 * forge script script/upgrade/NftInvestorSaleUpgrade.s.sol:NftInvestorSaleUpgradesScripts --rpc-url $WEB3GAMING_ALCHEMY_RPC_URL --private-key $WEB3GAMING_PRIVATE_KEY --broadcast --verify --etherscan-api-key $WEB3GAMING_ETHERSCAN_API_KEY
  cast call --rpc-url $WEB3GAMING_ALCHEMY_RPC_URL 0xA51Ecf228F86195665c09a3fB621128F1CE57eF1 "mintedSupply()"
 
 */

contract NftInvestorSaleUpgradesScripts is Script {

    function run() external returns (address) {
      string memory privateKey = vm.envString("WEB3GAMING_PRIVATE_KEY");
        uint256 deployerPrivateKey = vm.parseUint(string.concat("0x", privateKey));
        address deployerAddress = vm.addr(deployerPrivateKey);
        console.log("Deploying contracts with the account: %s", deployerAddress);

        vm.startBroadcast(deployerPrivateKey);

         Upgrades.upgradeProxy(
            NftInvestorSaleAddr,
            "NftInvestorSaleUpgrades.sol:NftInvestorSaleUpgrades",
            ""
        );

        console.log("NftInvestorSaleUpgrades Proxy deployed to:", NftInvestorSaleAddr);
        address implementation = Upgrades.getImplementationAddress(NftInvestorSaleAddr);
        console.log("NftInvestorSaleUpgrades Implementation deployed to:", implementation);
        console.log("NftInvestorSaleUpgrades Owner set to:", deployerAddress);

        vm.stopBroadcast();

        return implementation;
    }
}