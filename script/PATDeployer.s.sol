// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {PAT} from "../src/core/PAT.sol"; 
import { MultiSigWalletAddr } from "./address.sol";

/**
 * @title PATDeployer
 * @dev 部署脚本
 * @author Web3Gaming
 * forge clean && forge build
 * forge script script/PATDeployer.s.sol:PATDeployerScript --rpc-url $WEB3GAMING_ALCHEMY_RPC_URL --private-key $WEB3GAMING_PRIVATE_KEY --broadcast --verify --etherscan-api-key $WEB3GAMING_ETHERSCAN_API_KEY
 * https://sepolia.etherscan.io/address/0xd030106997dbd7c499ff46220cd268a6e45b3a66
 *  Deploying contracts with the account: 0x355eb1c3D6dF0642b3abe2785e821C574837C79f
    PAT Proxy deployed to: 0xA51Ecf228F86195665c09a3fB621128F1CE57eF1
    PAT Implementation deployed to: 0xd030106997dBD7c499fF46220Cd268a6E45b3a66
    PAT Owner set to: 0x355eb1c3D6dF0642b3abe2785e821C574837C79f
 */

contract PATDeployerScript is Script {
    function run() external returns (address) {

        string memory privateKey = vm.envString("WEB3GAMING_PRIVATE_KEY");
        uint256 deployerPrivateKey = vm.parseUint(string.concat("0x", privateKey));
        address deployerAddress = vm.addr(deployerPrivateKey);
        console.log("Deploying contracts with the account: %s", deployerAddress);
        address initialOwner = deployerAddress; // 或者其他指定的owner地址

        bytes memory initData = abi.encodeWithSelector(
            PAT.initialize.selector,
            initialOwner,
            MultiSigWalletAddr
        );

        vm.startBroadcast(deployerPrivateKey);

        // 部署 UUPS 代理
        address proxy = Upgrades.deployUUPSProxy(
            "PAT.sol:PAT", // 合约文件名
            initData
        );

        vm.stopBroadcast();

        console.log("PAT Proxy deployed to:", proxy);
        console.log("PAT Implementation deployed to:", Upgrades.getImplementationAddress(proxy)); // 可选：获取实现地址
        console.log("PAT Owner set to:", initialOwner);

        return proxy;
    }
}