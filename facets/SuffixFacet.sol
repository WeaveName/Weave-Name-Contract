// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {LibSuffix} from "../libraries/LibSuffix.sol";
import {IMainDiamond} from "../interfaces/IMainDiamond.sol";

contract SuffixFacet {

    modifier onlyOwner() {
        require(IMainDiamond(payable(address(this))).owner() == msg.sender, "Only the owner can call this");
        _;
    }

    function initializeSuffix() external onlyOwner {
       LibSuffix.SuffixStorage storage dp = LibSuffix.diamondStorage();
       require(!dp.initialized, "SuffixFacet: Contract instance has already been initialized");
       dp._nextKey = 1;
       LibSuffix.addSuffix(".zc");
       LibSuffix.addSuffix(".op");
       LibSuffix.addSuffix(".lz");
       LibSuffix.addSuffix(".ava");
       LibSuffix.addSuffix(".ft");
       LibSuffix.addSuffix(".arb");
       LibSuffix.addSuffix(".ftm");
       LibSuffix.addSuffix(".celo");
       LibSuffix.addSuffix(".beam");
       LibSuffix.addSuffix(".fuse");
       LibSuffix.addSuffix(".klay");
       LibSuffix.addSuffix(".metis");
       LibSuffix.addSuffix(".okt");
       LibSuffix.addSuffix(".river");
       LibSuffix.addSuffix(".tenet");
       LibSuffix.addSuffix(".meter");
       LibSuffix.addSuffix(".kava");
       LibSuffix.addSuffix(".linea");
       LibSuffix.addSuffix(".base");
       LibSuffix.addSuffix(".man");
       LibSuffix.addSuffix(".loot");
       dp.initialized = true;
    }

    function addSuffix(string calldata value) external onlyOwner {
        LibSuffix.SuffixStorage storage dp = LibSuffix.diamondStorage();
        require(bytes(value).length > 0, "Suffix cannot be empty");
        for (uint256 i = 1; i < dp._nextKey; i++) {
            require(keccak256(bytes(dp._suffix[i])) != keccak256(bytes(value)), "Suffix already exists");
        }
        LibSuffix.addSuffix(value);
    }

    function getSuffix(uint256 _suffixId) public view returns (string memory) {
        return LibSuffix.getSuffix(_suffixId);
    }

    function isValidSuffix(uint256 _suffixId) public view returns (bool) {
        return LibSuffix.isValidSuffix(_suffixId);
    }
}