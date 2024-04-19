// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/ILayerZeroEndpoint.sol";

library LibLzApp {
    struct LzAppStorage {
        bool initialized;
        
        uint DEFAULT_PAYLOAD_SIZE_LIMIT;
        mapping(uint16 => bytes) trustedRemoteLookup;
        ILayerZeroEndpoint lzEndpoint;
        mapping(uint16 => mapping(uint16 => uint)) minDstGasLookup;
        mapping(uint16 => uint) payloadSizeLimitLookup;
        address precrime;
        mapping(uint16 => mapping(bytes => mapping(uint64 => bytes32))) failedMessages;
    
        address _currentEndpointAddress;
        uint _generalGas;
        uint16 _version;
    }

    function diamondStorage() internal pure returns (LzAppStorage storage ds) {
        bytes32 storagePosition = keccak256("lzApp.storage");
        assembly {
            ds.slot := storagePosition
        }
    }
}