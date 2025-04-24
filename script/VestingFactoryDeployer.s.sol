// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {VestingFactory} from "../src/stake/VestingFactory.sol";
import { MultiSigWalletAddr, PATAddr } from "./multiSigWallet.sol";
/**
 * @title VestingFactoryDeployerScript
 * @dev 部署 VestingFactory 合约的 UUPS 代理脚本
 * @author Trae AI
 *
 * forge clean && forge build
 * export DEPLOYER_PRIVATE_KEY=<your_private_key>
 * export PAT_ADDRESS=<your_pat_token_address>
 * export INVESTOR_POOL_ADDRESS=<your_investor_pool_address>
 * export MULTISIG_ADDRESS=<your_multisig_address>
 * forge script script/VestingFactoryDeployer.s.sol:VestingFactoryDeployerScript --rpc-url $WEB3GAMING_ALCHEMY_RPC_URL --private-key $WEB3GAMING_PRIVATE_KEY --broadcast --verify --etherscan-api-key $WEB3GAMING_ETHERSCAN_API_KEY
 */
contract VestingFactoryDeployerScript is Script {
    function run() external returns (address) {
        // --- 配置 ---
        uint256 earlyRedemptionFeeBps = 0; // 初始提前赎回费率 (e.g., 0 = 0%, 1000 = 10%)

        string memory privateKey = vm.envString("WEB3GAMING_PRIVATE_KEY");
        uint256 deployerPrivateKey = vm.parseUint(string.concat("0x", privateKey));
        address deployerAddress = vm.addr(deployerPrivateKey);
        console.log("Deploying contracts with the account: %s", deployerAddress);
        address initialOwner = deployerAddress; // 或者其他指定的owner地址
        address investorSalePoolAddress = deployerAddress; // 直接销售池子地址
        console.log("Deploying VestingFactory with account:", deployerAddress);
        console.log("  PAT Token:", PATAddr);
        console.log("  Investor Sale Pool:", deployerAddress);
        console.log("  MultiSig Wallet:", MultiSigWalletAddr);
        console.log("  Initial Owner:", initialOwner);
        console.log("  Early Redemption Fee (Bps):", earlyRedemptionFeeBps);


        // --- 编码初始化数据 ---
        bytes memory initData = abi.encodeWithSelector(
            VestingFactory.initialize.selector,
            initialOwner,
            PATAddr,
            investorSalePoolAddress,
            MultiSigWalletAddr,
            earlyRedemptionFeeBps
        );

        // --- 部署 ---
        vm.startBroadcast(deployerPrivateKey);

        address proxy = Upgrades.deployUUPSProxy(
            "VestingFactory.sol:VestingFactory", // 合约文件名:合约名
            initData
        );

        vm.stopBroadcast();

        // --- 输出结果 ---
        console.log("VestingFactory Proxy deployed to:", proxy);
        address implementation = Upgrades.getImplementationAddress(proxy);
        console.log("VestingFactory Implementation deployed to:", implementation);
        console.log("VestingFactory Owner set to:", initialOwner);

        return proxy;
    }
}