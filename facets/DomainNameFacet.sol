// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.4.1/contracts/utils/Address.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.4.1/contracts/utils/math/Math.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.4.1/contracts/utils/Strings.sol";

import {LibLzApp} from "../libraries/LibLzApp.sol";
import {LibDomains} from "../libraries/LibDomains.sol";
import {LibConfig} from "../libraries/LibConfig.sol";
import {LibSignature} from "../libraries/LibSignature.sol";

import {LzApp} from "../contracts/LzApp.sol";
import {ERC721} from "../contracts/ERC721.sol";

import {ILayerZeroEndpoint} from "../interfaces/ILayerZeroEndpoint.sol";
import {IMainDiamond} from "../interfaces/IMainDiamond.sol";
import {IDomainPrice} from "../interfaces/IDomainPrice.sol";
import {ISuffix} from "../interfaces/ISuffix.sol";


contract DomainsFacet is LzApp, ERC721 {
    using Address for address;
    using SafeMath for uint256;

    modifier noReentrancy() {
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        require(!ds.locked, "Reentrant call");
        ds.locked = true;
        _;
        ds.locked = false;
    }

    function initializeCrossChain(address _currentEndpointAddress) external onlyOwner {
        LibLzApp.LzAppStorage storage ls = LibLzApp.diamondStorage();
        require(!ls.initialized, "DomainsFacet: Contract instance has already been initialized");
        ls.lzEndpoint = ILayerZeroEndpoint(_currentEndpointAddress);
        ls._currentEndpointAddress = _currentEndpointAddress;
        ls.DEFAULT_PAYLOAD_SIZE_LIMIT = 10000;
        ls._generalGas = 350000;
        ls._version = 1;
        ls.initialized = true;
    }

    function initializeNFTFacet(string calldata name_, string calldata symbol_, string calldata baseUrl_) external onlyOwner {
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        require(!ds.initialized, "DomainsFacet: Contract instance has already been initialized");
        ds._name = name_;
        ds._symbol = symbol_;
        ds._baseUrl = baseUrl_;
        ds.initialized = true;
    }

    event DomainTransfered(uint tokenId);

    function _nonblockingLzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload) internal override {
        (address toAddr, uint tokenId, uint256 time, string memory domainName) = abi.decode(_payload, (address, uint, uint256, string));
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        ds._expTime[domainName] = time;
        ds._domainID[domainName] = tokenId;
        ds._domainName[tokenId] = domainName;
        _safeMint(toAddr, tokenId);
        string memory metadataURI = string(abi.encodePacked(ds._baseUrl, domainName));
        _setTokenURI(tokenId, metadataURI);
        emit DomainTransfered(tokenId);
    }

    function getEstimateFees(uint16 _chainId, uint tokenId) public view returns (uint) {
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        LibLzApp.LzAppStorage storage ls = LibLzApp.diamondStorage();
        bytes memory payload = abi.encode(msg.sender , tokenId , ds._expTime[ds._domainName[tokenId]] , ds._domainName[tokenId]);
        bytes memory adapterParams = abi.encodePacked(ls._version, ls._generalGas);
        (uint messageFee, ) = ls.lzEndpoint.estimateFees(_chainId, address(this), payload, false, adapterParams);
        return messageFee;
    }
    
    event TraverseChain(uint tokenId);

    function traverseChains(uint16 _chainId, uint tokenId) public payable noReentrancy {
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        LibLzApp.LzAppStorage storage ls = LibLzApp.diamondStorage();
        require(msg.sender == ownerOf(tokenId), "You must own the token to traverse");
        require(ls.trustedRemoteLookup[_chainId].length > 0, "This chain is currently unavailable for travel");
        bytes memory payload = abi.encode(msg.sender , tokenId , ds._expTime[ds._domainName[tokenId]], ds._domainName[tokenId]);
        bytes memory adapterParams = abi.encodePacked(ls._version, ls._generalGas);
        (uint messageFee, ) = ls.lzEndpoint.estimateFees(_chainId, address(this), payload, false, adapterParams);
        require(msg.value >= messageFee, "msg.value not enough to cover messageFee. Send gas for message fees");
        ls.lzEndpoint.send{value: msg.value}(
            _chainId,                           
            ls.trustedRemoteLookup[_chainId],      
            payload,                           
            payable(msg.sender),               
            address(0x0),                       
            adapterParams                      
        );
        _burn(tokenId);
        emit TraverseChain(tokenId);
    }

    function changeBaseUrl(string calldata newUrl_) external onlyOwner{
        LibDomains.changeBaseUrl(newUrl_);
    }

    event OwnerMint(uint256 tokenId);

    function ownerMint(address to, string calldata domainName_, uint256 year, uint256 tokenId_, uint256 _suffixId) public onlyOwner {
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        require(LibDomains._checkDomainAvaliable(domainName_) == true , "Domain unavaliable (Has been registered)");
        require(bytes(domainName_).length >= 3, "Name is too short. Names must be at least 3 characters long");
        require(!LibConfig.getPaused(), "Register now not avaliable. Try again later");
        require(ISuffix(payable(address(this))).isValidSuffix(_suffixId), "Suffix does not exist");

        string memory suffix = ISuffix(payable(address(this))).getSuffix(_suffixId);
        string memory domainNameWithSuffix = string(abi.encodePacked(domainName_, suffix));

        ds._expTime[domainNameWithSuffix] = block.timestamp + year * 31557600;
        ds._domainID[domainNameWithSuffix] = tokenId_;
        ds._domainName[tokenId_] = domainNameWithSuffix;
        _safeMint(to, tokenId_);
        string memory metadataURI = string(abi.encodePacked(ds._baseUrl, domainNameWithSuffix));
        _setTokenURI(tokenId_, metadataURI);
        emit OwnerMint(tokenId_);
    }

    event DomainRegistred(uint256 tokenId);

    function registerDomain(string calldata domainName_ , uint256 year_, uint256 tokenId_, bytes memory signature_, uint256 _suffixId) external payable noReentrancy{
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        require(LibSignature.isValidSignature(signature_, domainName_), "Invalid signature");
        require(!LibConfig.getPaused(), "Register now not avaliable");
        require(year_ >= 1 , "Invalid year value");
        require(bytes(domainName_).length >= 3, "Name is too short. Names must be at least 3 characters long");
        require(LibDomains._checkDomainAvaliable(domainName_) == true , "Domain unavaliable (Has been registered)");
        require(ISuffix(payable(address(this))).isValidSuffix(_suffixId), "Suffix does not exist");
        uint256 price = IDomainPrice(payable(address(this))).getDomainPrice(domainName_, year_);
        uint256 requiredValue = price.mul(IDomainPrice(payable(address(this))).getTolerance()).div(100);
        require(msg.value >= requiredValue, "Check register price");

        string memory suffix = ISuffix(payable(address(this))).getSuffix(_suffixId);
        string memory domainNameWithSuffix = string(abi.encodePacked(domainName_, suffix));

        ds._expTime[domainNameWithSuffix] = block.timestamp + year_ * 31557600;
        ds._domainID[domainNameWithSuffix] = tokenId_;
        ds._domainName[tokenId_] = domainNameWithSuffix;
        _safeMint(msg.sender, tokenId_);
        string memory metadataURI = string(abi.encodePacked(ds._baseUrl, domainNameWithSuffix));
        _setTokenURI(tokenId_, metadataURI);
        emit DomainRegistred(tokenId_);
    }

    event RenewDomain(uint256 tokenId);

    function renewDomain(string calldata domainName_, uint256 year_, bytes memory signature_) external payable noReentrancy{
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        require(!LibConfig.getPaused(), "Renew now not avaliable");
        require(LibSignature.isValidSignature(signature_, domainName_), "Invalid signature");
        require(msg.sender == ownerOf(ds._domainID[domainName_]) , "Access denied");
        uint256 price = IDomainPrice(payable(address(this))).getDomainPrice(domainName_, year_);
        uint256 requiredValue = price.mul(IDomainPrice(payable(address(this))).getTolerance()).div(100);
        require(msg.value >= requiredValue, "Check register price");
        ds._expTime[domainName_] += year_ * 31557600;
        emit RenewDomain(ds._domainID[domainName_]);
    }

    event BurnExpDomain(string indexed domainName_);

    function burnExpiredDomain(string calldata domainName_) external onlyOwner{
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        require(ds._expTime[domainName_] < block.timestamp, "Domain is not expired");
        if(_exists(ds._domainID[domainName_])){
            _burn(ds._domainID[domainName_]);
        }   
        emit BurnExpDomain(domainName_); 
    }

    event BurnDomain(string indexed domainName_);

    function burnDomain(string calldata domainName_) external onlyOwner{
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        if(_exists(ds._domainID[domainName_])){
            _burn(ds._domainID[domainName_]);
        }   
        emit BurnDomain(domainName_); 
    }

    function setPrimaryDomain(uint256 tokenId_) external noReentrancy{
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        require(msg.sender == ownerOf(tokenId_) , "You are not a domain holder!");
        uint256 currentPrimaryId = ds._addressToName[msg.sender];
        require(currentPrimaryId != tokenId_ , "Already set as primary!");
        if (currentPrimaryId != tokenId_) {
            ds._primaryDomainName[currentPrimaryId] = false;
        }
        ds._primaryDomainName[tokenId_] = true;
        ds._addressToName[msg.sender] = tokenId_;
        ds._nameToAddress[ds._domainName[tokenId_]] = msg.sender;
    }
    
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }
}
