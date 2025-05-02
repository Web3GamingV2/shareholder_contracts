// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {SubscriptionSalePool} from "../src/sale/SubscriptionSalePool.sol";

import { PATAddr, VestingFactoryAddr, USDTAddr, InvestorSalePoolAddr } from "./address.sol";

/**
 * @title SubscriptionSalePoolDeployer
 * @dev Deploys the SubscriptionSalePool contract using the UUPS proxy pattern.
 * forge script script/SubscriptionSalePoolDeployer.s.sol:SubscriptionSalePoolDeployerScripts --rpc-url $WEB3GAMING_ALCHEMY_RPC_URL --private-key $WEB3GAMING_PRIVATE_KEY --broadcast --verify --etherscan-api-key $WEB3GAMING_ETHERSCAN_API_KEY

 == Return ==
0: address 0x16bce603fb64F37c6A8Cf7bEa0151d657558AaC9

== Logs ==
  Deploying contracts with the account: 0x355eb1c3D6dF0642b3abe2785e821C574837C79f
    PAT Coin: 0xA51Ecf228F86195665c09a3fB621128F1CE57eF1
    USDT: 0x419Fe9f14Ff3aA22e46ff1d03a73EdF3b70A62ED
    Vesting Factory: 0x4B860eA39Af4b41EAd50e3f6531eBbc482DA7aF5
    InvestorSalePool: 0xC711619c140663737aDe3b54A4B4974C0FC58D8A
  SubscriptionSalePool Proxy deployed to: 0x16bce603fb64F37c6A8Cf7bEa0151d657558AaC9
  SubscriptionSalePool Implementation deployed to: 0x0e78F3D0F4dcC4e948BA746688E95fe6c7dD687F
  SubscriptionSalePool Owner set to: 0x355eb1c3D6dF0642b3abe2785e821C574837C79f
 */

contract SubscriptionSalePoolDeployerScripts is Script {
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

