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
  cast call --rpc-url $WEB3GAMING_ALCHEMY_RPC_URL 0x23600c0EF51e2d02603E043EE444fcA77CE55B62 "version()(string memory)" 
  cast send --rpc-url $WEB3GAMING_ALCHEMY_RPC_URL --private-key $WEB3GAMING_PRIVATE_KEY 0x23600c0EF51e2d02603E043EE444fcA77CE55B62 "setNftInfos(string,string)()" "NftInvestorSale" "SBNG"
== Return ==
0: address 0xa8fe75deEC2C2Eb0f46eE55577E16F5ea27e6416

== Logs ==
  Deploying contracts with the account: 0x355eb1c3D6dF0642b3abe2785e821C574837C79f
  NftInvestorSaleUpgrades Proxy deployed to: 0x23600c0EF51e2d02603E043EE444fcA77CE55B62
  NftInvestorSaleUpgrades Implementation deployed to: 0xa8fe75deEC2C2Eb0f46eE55577E16F5ea27e6416
  NftInvestorSaleUpgrades Owner set to: 0x355eb1c3D6dF0642b3abe2785e821C574837C79f
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