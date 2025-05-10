// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library SourceFC {
    function getFCGet() internal pure returns (string memory) {
         return "const characterId = args[0];"
            "const apiResponse = await Functions.makeHttpRequest({"
            "url: `https://swapi.info/api/people/${characterId}/`"
            "});"
            "if (apiResponse.error) {"
            "throw Error('Request failed');"
            "}"
            "const { data } = apiResponse;"
            "return Functions.encodeString(data.name);";
    }
    function getFCPost() internal pure returns (string memory) {
          return "const apiResponse = await Functions.makeHttpRequest({"
            "url: `https://swapi.info/api/people/`,"
            "method: 'POST',"
            "headers: {"
            "  'Content-Type': 'application/json'"
            "},"
            "data: {"
            "  'params': args"
            "}"
            "});"
            "if (apiResponse.error) {"
            "throw Error('Request failed');"
            "}"
            "const { data } = apiResponse;"
            "return Functions.encodeString(data.id);";
    }
}