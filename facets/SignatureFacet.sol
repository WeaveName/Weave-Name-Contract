// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IMainDiamond} from "../interfaces/IMainDiamond.sol";
import {LibSignature} from "../libraries/LibSignature.sol";


contract SignatureFacet {

    modifier onlyOwner() {
        require(IMainDiamond(payable(address(this))).owner() == msg.sender, "Only the owner can call this");
        _;
    }

    function initializeSignature(address myWebsitePublicKey_) external onlyOwner {
       LibSignature.SignatureStorage storage dp = LibSignature.diamondStorage();
       require(!dp.initialized, "SignatureFacet: Contract instance has already been initialized");
       dp._myWebsitePublicKey = myWebsitePublicKey_;
       dp.initialized = true;
    }

    function changePublicKey(address key_) external onlyOwner {
       LibSignature.changePublicKey(key_);
    }

    function isValidSignature(bytes memory signature_, string calldata data_) external view returns (bool) {
        return LibSignature.isValidSignature(signature_, data_);
    }
}
