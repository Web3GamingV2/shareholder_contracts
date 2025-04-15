// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

// forge script script/ChainlinkFC.s.sol:ChainlinkFCScript --rpc-url $WEB3GAMING_ALCHEMY_RPC_URL --private-key $WEB3GAMING_PRIVATE_KEY --broadcast --verify --etherscan-api-key $WEB3GAMING_ETHERSCAN_API_KEY
/**
  == Logs ==
  Deploying contracts with the account: 0x355eb1c3D6dF0642b3abe2785e821C574837C79f
  GettingStartedFunctionsConsumer address: 0x4A56B83B35B225fc5108edfe7477566C5b814fE0
  Contract owner: 0x355eb1c3D6dF0642b3abe2785e821C574837C79f
  Is deployer owner? true

  cast call --rpc-url $WEB3GAMING_ALCHEMY_RPC_URL 0x4A56B83B35B225fc5108edfe7477566C5b814fE0 "character()(string)"
  cast send --rpc-url $WEB3GAMING_ALCHEMY_RPC_URL --private-key $WEB3GAMING_PRIVATE_KEY 0x4A56B83B35B225fc5108edfe7477566C5b814fE0 "sendRequest(uint64,string[])(bytes32)" 4605 "[1]"
  cast call --rpc-url $WEB3GAMING_ALCHEMY_RPC_URL 0x4A56B83B35B225fc5108edfe7477566C5b814fE0 "s_lastError()"
 */

import {ChainlinkFC} from "../src/external/ChainlinkFC.sol";

contract ChainlinkFCScript is Script {
    
    function run() external {
        // 获取部署者私钥
        string memory privateKey = vm.envString("WEB3GAMING_PRIVATE_KEY");
        uint256 deployerPrivateKey = vm.parseUint(string.concat("0x", privateKey));
        address deployerAddress = vm.addr(deployerPrivateKey);
        console.log("Deploying contracts with the account: %s", deployerAddress);
        vm.startBroadcast(deployerPrivateKey);
        // 部署合约
        ChainlinkFC consumer = new ChainlinkFC();
        console.log("GettingStartedFunctionsConsumer address: %s", address(consumer));
        console.log("Contract owner: %s", consumer.owner());
        console.log("Is deployer owner? %s", consumer.owner() == deployerAddress);
        vm.stopBroadcast();
    }
}