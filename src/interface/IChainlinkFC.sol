// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IChainlinkFC {

    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        bytes response; // The response data
        bytes err; // Any error data
        address callee; // The address to call back upon fulfillment
        string source; // The source code for the request
    }

    function sendRequest(
        uint64 subscriptionId,
        string[] calldata args,
        string calldata source, // Allow specifying source per request
        uint32 gasLimit         // Allow specifying gasLimit per request
    ) external returns (bytes32 requestId);

    function getResponse(bytes32 _requestId)
        external
        view
        returns (
            bytes memory response
    );

     function removeResponse(bytes32 _requestId)
        external;
}
