// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {SubscriptionSalePool} from "../src/sale/SubscriptionSalePool.sol";

import { PATAddr, VestingFactoryAddr, USDTAddr, InvestorSalePoolAddr } from "./address.sol";

contract SubscriptionSalePoolDeployer is Script {
    function run() external returns (address)  {
         // --- Get Deployer Info ---
        string memory privateKey = vm.envString("WEB3GAMING_PRIVATE_KEY");
        uint256 deployerPrivateKey = vm.parseUint(string.concat("0x", privateKey));
        address deployerAddress = vm.addr(deployerPrivateKey);
        console.log("Deploying contracts with the account: %s", deployerAddress);
        console.log("  PAT Coin:", PATAddr);
        console.log("  USDT:", USDTAddr);
        console.log("  Vesting Factory:", VestingFactoryAddr);
        console.log("  InvestorSalePool:", InvestorSalePoolAddr);

         // --- Encode Initialization Data ---
        bytes memory initData = abi.encodeWithSelector(
            SubscriptionSalePool.initialize.selector,
            deployerAddress,
            PATAddr,
            USDTAddr,
            InvestorSalePoolAddr,
            VestingFactoryAddr,
            3600
        );

        // --- Deploy SubscriptionSalePool ---  
        vm.startBroadcast(deployerPrivateKey);

        address proxy = Upgrades.deployUUPSProxy(
            "SubscriptionSalePool.sol:SubscriptionSalePool", // Contract file and name
            initData
        );

        vm.stopBroadcast();

        // --- Log Deployment Results ---
        console.log("SubscriptionSalePool Proxy deployed to:", proxy);
        console.log("SubscriptionSalePool Implementation deployed to:", Upgrades.getImplementationAddress(proxy));
        console.log("SubscriptionSalePool Owner set to:", deployerAddress);
        return proxy;
    }
}

