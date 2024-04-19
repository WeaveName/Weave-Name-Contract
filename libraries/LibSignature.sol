// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibSignature {
    struct SignatureStorage {
        bool initialized;
        address _myWebsitePublicKey;
    }

    function diamondStorage() internal pure returns (SignatureStorage storage ss) {
        bytes32 storagePosition = keccak256("signature.storage");
        assembly {
            ss.slot := storagePosition
        }
    }

    function changePublicKey(address key_) internal {
       LibSignature.SignatureStorage storage dp = LibSignature.diamondStorage();
       dp._myWebsitePublicKey = key_;
    }

    function isValidSignature(bytes memory signature_, string calldata data_) internal view returns (bool) {
        LibSignature.SignatureStorage storage dp = LibSignature.diamondStorage();
        bytes32 messageHash = keccak256(abi.encodePacked(data_));
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(signature_, 32))
            s := mload(add(signature_, 64))
            v := byte(0, mload(add(signature_, 96)))
        }
        address recoveredAddress = ecrecover(messageHash, v, r, s);
        return (recoveredAddress == dp._myWebsitePublicKey);
    }
}
