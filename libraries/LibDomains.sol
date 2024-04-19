// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

library LibDomains {
    struct DomainStorage {
        bool initialized;
        bool locked;

        string _name;
        string _symbol;

        mapping(uint256 => address) _owners;
        mapping(address => uint256) _balances;
        mapping(uint256 => address) _tokenApprovals;
        mapping(address => mapping(address => bool)) _operatorApprovals;
        mapping(uint256 => string) _tokenURIs;
        string _baseUrl;

        mapping(address => mapping(uint256 => uint256)) _ownedTokens;
        mapping(uint256 => uint256) _ownedTokensIndex;
        uint256[] _allTokens;
        mapping(uint256 => uint256) _allTokensIndex;
        
        mapping(string => uint256) _expTime;
        mapping(string => uint256) _domainID;

        mapping(uint256 => bool) _primaryDomainName;
        mapping(uint256 => string) _domainName;

        mapping(address => uint256) _addressToName;
        mapping(string => address) _nameToAddress;
    }
    

    function diamondStorage() internal pure returns (DomainStorage storage ds) {
        bytes32 storagePosition = keccak256("domainName.storage");
        assembly {
            ds.slot := storagePosition
        }
    }

    function changeBaseUrl(string memory newUrl_) internal {
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        ds._baseUrl = newUrl_;
    }

    function totalSupply() internal view returns (uint256) {
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        return ds._allTokens.length;
    }

    function tokenOfOwnerByIndex(address owner, uint256 index) internal view returns (uint256) {
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        return ds._ownedTokens[owner][index];
    }

    function _ownerOf(uint256 tokenId) internal view returns (address) {
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        return ds._owners[tokenId];
    }

    function _balanceOf(address owner) internal view returns (uint256) {
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        return ds._balances[owner];
    }

    function _checkDomainAvaliable(string calldata domainName_) internal view returns(bool){
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        if(ds._expTime[domainName_] == 0 ){
            return true;
        }
        else{
            return false;
        }
    }
}