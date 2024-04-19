// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {LibDomains} from "../libraries/LibDomains.sol";
import {IMainDiamond} from "../interfaces/IMainDiamond.sol";


contract GettersDomainsFacet {

    modifier onlyOwner() {
        require(IMainDiamond(payable(address(this))).owner() == msg.sender, "Only the owner can call this");
        _;
    }

    function checkDomainAvaliable(string calldata domainName_) external view returns(bool){
        return LibDomains._checkDomainAvaliable(domainName_);
    }

    function getDomainData(uint256 tokenId_) external view returns (uint256 exp_time, uint256 nft_id, string memory domain_name, bool primary_name, address owner) {
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        exp_time = ds._expTime[ds._domainName[tokenId_]];
        nft_id = ds._domainID[ds._domainName[tokenId_]];
        domain_name = ds._domainName[tokenId_];
        primary_name = ds._primaryDomainName[tokenId_];
        owner = LibDomains._ownerOf(tokenId_);
    }

    function getNameFromAddress(address holderAddress_) external view returns (string memory) {
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        require(ds._addressToName[holderAddress_] != 0, "Address not associated with any domain");
        return ds._domainName[ds._addressToName[holderAddress_]];
    }

    function getAddressFromName(string calldata domainName_) external view returns (address) {
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        return ds._nameToAddress[domainName_];
    }

    function walletOfOwner(address _owner) public view returns(uint256[] memory) {
        require(_owner != address(0), "ERC721: address zero is not a valid owner");
        uint256 ownerTokenCount = LibDomains._balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds [i]
            = LibDomains.tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }
}