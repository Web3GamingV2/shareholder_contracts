// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {NftInvestorSale} from "../src/nft/NftInvestorSale.sol";

/**
 * @title NftInvestorSaleDeployer.s
 * @dev 部署脚本
 * @author Web3Gaming
 * forge clean && forge build
 * forge script script/NftInvestorSaleDeployer.s.sol:NftInvestorSaleDepolyerScript --rpc-url $WEB3GAMING_ALCHEMY_RPC_URL --private-key $WEB3GAMING_PRIVATE_KEY --broadcast --verify --etherscan-api-key $WEB3GAMING_ETHERSCAN_API_KEY

 == Return ==
0: address 0x23600c0EF51e2d02603E043EE444fcA77CE55B62

== Logs ==
  Deploying contracts with the account: 0x355eb1c3D6dF0642b3abe2785e821C574837C79f
  NftInvestorSale Proxy deployed to: 0x23600c0EF51e2d02603E043EE444fcA77CE55B62
  NftInvestorSale Implementation deployed to: 0xc0e60Cb4B71a88acaBF6a425f00c774028ab3186
  NftInvestorSale Owner set to: 0x355eb1c3D6dF0642b3abe2785e821C574837C79f
 */

contract NftInvestorSaleDepolyerScript is Script {
    function run() external returns (address) {

        string memory privateKey = vm.envString("WEB3GAMING_PRIVATE_KEY");
        uint256 deployerPrivateKey = vm.parseUint(string.concat("0x", privateKey));
        address deployerAddress = vm.addr(deployerPrivateKey);
        console.log("Deploying contracts with the account: %s", deployerAddress);
        address initialOwner = deployerAddress; // 或者其他指定的owner地址

        bytes memory initData = abi.encodeWithSelector(
            NftInvestorSale.initialize.selector,
            initialOwner,
            ""
        );

        vm.startBroadcast(deployerPrivateKey);

        // 部署 UUPS 代理
        address proxy = Upgrades.deployUUPSProxy(
            "NftInvestorSale.sol:NftInvestorSale", // 合约文件名
            initData
        );

        vm.stopBroadcast();

        console.log("NftInvestorSale Proxy deployed to:", proxy);
        console.log("NftInvestorSale Implementation deployed to:", Upgrades.getImplementationAddress(proxy)); // 可选：获取实现地址
        console.log("NftInvestorSale Owner set to:", initialOwner);

        return proxy;
    }
}