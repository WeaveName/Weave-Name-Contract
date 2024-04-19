// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

library LibSuffix {
    struct SuffixStorage {
        bool initialized;

        mapping(uint256 => string) _suffix;
        uint256 _nextKey;
    }
    
    function diamondStorage() internal pure returns (SuffixStorage storage ds) {
        bytes32 storagePosition = keccak256("suffix.storage");
        assembly {
            ds.slot := storagePosition
        }
    }

    function addSuffix(string memory _suffix) internal {
        LibSuffix.SuffixStorage storage ds = LibSuffix.diamondStorage();
        ds._suffix[ds._nextKey] = _suffix;
        ds._nextKey++;
    }

    function getSuffix(uint256 _suffixId) internal view returns (string memory) {
        LibSuffix.SuffixStorage storage ds = LibSuffix.diamondStorage();
        return ds._suffix[_suffixId];
    }

    function isValidSuffix(uint256 _suffixId) internal view returns (bool) {
        return bytes(getSuffix(_suffixId)).length > 0;
    }
}