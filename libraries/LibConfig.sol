// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

library LibConfig {
    struct ConfigStorage {
        bool initialized;
        bool _paused;
    }

    function diamondStorage() internal pure returns (ConfigStorage storage ss) {
        bytes32 storagePosition = keccak256("config.storage");
        assembly {
            ss.slot := storagePosition
        }
    }

    function changePaused() internal {
        LibConfig.ConfigStorage storage ds = LibConfig.diamondStorage();
        if (ds._paused == true) {
            ds._paused = false;
        }
        else{
            ds._paused = true;
        }
    }

    function getPaused() internal view returns (bool) {
        LibConfig.ConfigStorage storage ds = LibConfig.diamondStorage();
        return ds._paused;
    }
}