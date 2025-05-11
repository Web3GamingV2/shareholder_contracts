// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

abstract contract Basic {
    function version() external virtual view returns (string memory) {
        return '1.0.0';
    }
}