// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {PATUprades} from "../../src/core/upgrade/PATUprades.sol";
import "../address.sol";

/**
 * @title 升级PAT合约脚本
 * @dev 升级PAT合约脚本
 * forge script script/upgrade/PATUpgrade.s.sol:PATUpgradesScripts --rpc-url $WEB3GAMING_ALCHEMY_RPC_URL --private-key $WEB3GAMING_PRIVATE_KEY --broadcast --verify --etherscan-api-key $WEB3GAMING_ETHERSCAN_API_KEY
 * cast call --rpc-url $WEB3GAMING_ALCHEMY_RPC_URL 0xA51Ecf228F86195665c09a3fB621128F1CE57eF1 "version()(uint256)" 
 == Return ==
    0: address 0x1b97d18992215497242b68D5D842D81C0d981A3a
    == Logs ==
    Deploying contracts with the account: 0x355eb1c3D6dF0642b3abe2785e821C574837C79f
    PATUpgradesScripts Proxy deployed to: 0xA51Ecf228F86195665c09a3fB621128F1CE57eF1
    PATUpgradesScripts Implementation deployed to: 0x1b97d18992215497242b68D5D842D81C0d981A3a
    PATUpgradesScripts Owner set to: 0x355eb1c3D6dF0642b3abe2785e821C574837C79f
 */
contract PATUpgradesScripts is Script {
    function run() external returns (address) {
        string memory privateKey = vm.envString("WEB3GAMING_PRIVATE_KEY");
        uint256 deployerPrivateKey = vm.parseUint(string.concat("0x", privateKey));
        address deployerAddress = vm.addr(deployerPrivateKey);
        console.log("Deploying contracts with the account: %s", deployerAddress);

        vm.startBroadcast(deployerPrivateKey);

         Upgrades.upgradeProxy(
            PATAddr,
            "PATUprades.sol:PATUprades",
            ""
        );

        console.log("PATUpgradesScripts Proxy deployed to:", PATAddr);
        address implementation = Upgrades.getImplementationAddress(PATAddr);
        console.log("PATUpgradesScripts Implementation deployed to:", implementation);
        console.log("PATUpgradesScripts Owner set to:", deployerAddress);

        vm.stopBroadcast();

        return implementation;

    }
}