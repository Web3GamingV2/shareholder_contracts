// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title ICrossChainReceiverHandler Interface
 * @notice Defines the interface for contracts that handle the logic
 *         for processing verified CCIP messages received by CrossCcipReceiver.
 */
interface ICrossChainReceiverHandler {

    /**
     * @notice Handles a verified CCIP message.
     * @param sourceChainSelector The chain selector of the source chain.
     * @param sender The address of the sender contract on the source chain.
     * @param data The arbitrary data payload sent with the message.
     * @dev This function is called by CrossCcipReceiver after validating the message source.
     */
    function handleCCIPMessage(
        uint64 sourceChainSelector,
        address sender,
        bytes32 messageId,
        bytes calldata data
    ) external;
}