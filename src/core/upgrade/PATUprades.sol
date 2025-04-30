// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { PAT } from "../PAT.sol";

/// @custom:oz-upgrades-from PAT
contract PATUprades is PAT {
    function version() external virtual override pure returns (uint256) {
        return 2;
    }
}