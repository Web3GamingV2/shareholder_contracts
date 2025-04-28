// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {InvestorSalePool} from "../src/sale/InvestorSalePool.sol";
import { MultiSigWalletAddr, PATAddr, VestingFactoryAddr, USDTAddr } from "./address.sol";

/**
 * @title InvestorSalePoolDeployerScript
 * @dev 部署 InvestorSalePool 合约的 UUPS 代理脚本
 * @author Trae AI
 *
 * forge clean && forge build
 * forge script script/InvestorSalePoolDeployer.s.sol:InvestorSalePoolDeployerScript --rpc-url $WEB3GAMING_ALCHEMY_RPC_URL --private-key $WEB3GAMING_PRIVATE_KEY --broadcast --verify --etherscan-api-key $WEB3GAMING_ETHERSCAN_API_KEY
 */

/**
== Return ==
0: address 0xC711619c140663737aDe3b54A4B4974C0FC58D8A

== Logs ==
  Deploying contracts with the account: 0x355eb1c3D6dF0642b3abe2785e821C574837C79f
  Deploying InvestorSalePool with parameters:
    Owner: 0x355eb1c3D6dF0642b3abe2785e821C574837C79f
    PAT Coin: 0xA51Ecf228F86195665c09a3fB621128F1CE57eF1
    USDT: 0x419Fe9f14Ff3aA22e46ff1d03a73EdF3b70A62ED
    Treasury Pool: 0x355eb1c3D6dF0642b3abe2785e821C574837C79f
    Vesting Factory: 0x4B860eA39Af4b41EAd50e3f6531eBbc482DA7aF5
    MultiSig Wallet: 0xDCF27feBde41A0CB7328992bEA630D5B014c5932
    Treasury Ratio (Bps): 10000
  InvestorSalePool Proxy deployed to: 0xC711619c140663737aDe3b54A4B4974C0FC58D8A
  InvestorSalePool Implementation deployed to: 0x7CC3CeE445d2bFD6503c84409952Bb7B679AF055
  InvestorSalePool Owner set to: 0x355eb1c3D6dF0642b3abe2785e821C574837C79f
 */

contract InvestorSalePoolDeployerScript is Script {
    function run() external returns (address) {
        // --- Configuration ---
        uint256 treasuryRatioBps = 10000; // 默认转入资金池比例 100%

        // --- Get Deployer Info ---
        string memory privateKey = vm.envString("WEB3GAMING_PRIVATE_KEY");
        uint256 deployerPrivateKey = vm.parseUint(string.concat("0x", privateKey));
        address deployerAddress = vm.addr(deployerPrivateKey);
        console.log("Deploying contracts with the account: %s", deployerAddress);
        address initialOwner = deployerAddress;
        address treasuryPoolAddr = deployerAddress;

        // --- Log Parameters ---
        console.log("Deploying InvestorSalePool with parameters:");
        console.log("  Owner:", initialOwner);
        console.log("  PAT Coin:", PATAddr);
        console.log("  USDT:", USDTAddr);
        console.log("  Treasury Pool:", treasuryPoolAddr);
        console.log("  Vesting Factory:", VestingFactoryAddr);
        console.log("  MultiSig Wallet:", MultiSigWalletAddr);
        console.log("  Treasury Ratio (Bps):", treasuryRatioBps);

        // --- Encode Initialization Data ---
        bytes memory initData = abi.encodeWithSelector(
            InvestorSalePool.initialize.selector,
            initialOwner,
            PATAddr,
            USDTAddr,
            treasuryPoolAddr,
            VestingFactoryAddr,
            MultiSigWalletAddr,
            treasuryRatioBps
        );

        // --- Deploy UUPS Proxy ---
        vm.startBroadcast(deployerPrivateKey);

        address proxy = Upgrades.deployUUPSProxy(
            "InvestorSalePool.sol:InvestorSalePool", // Contract file and name
            initData
        );

        vm.stopBroadcast();

        // --- Log Deployment Results ---
        console.log("InvestorSalePool Proxy deployed to:", proxy);
        console.log("InvestorSalePool Implementation deployed to:", Upgrades.getImplementationAddress(proxy));
        console.log("InvestorSalePool Owner set to:", initialOwner);

        return proxy;
    }
}