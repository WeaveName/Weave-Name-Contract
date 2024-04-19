// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC721} from "../interfaces/IERC721.sol";
import {IERC721Receiver} from "../interfaces/IERC721Receiver.sol";
import {LibDomains} from "../libraries/LibDomains.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.4.1/contracts/utils/Strings.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.4.1/contracts/utils/Context.sol";


abstract contract ERC721 is Context, IERC721 {

    using Strings for uint256;

    function balanceOf(address owner) public view virtual  returns (uint256) {
        require(owner != address(0), "ERC721: address zero is not a valid owner");
        return LibDomains._balanceOf(owner);
    }

    function ownerOf(uint256 tokenId) public view virtual returns (address) {
        address owner = _ownerOf(tokenId);
        require(owner != address(0), "ERC721: invalid token ID");
        return owner;
    }

    function name() public view virtual  returns (string memory) {
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        return ds._name;
    }

    function symbol() public view virtual  returns (string memory) {
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        return ds._symbol;
    }

    function tokenURI(uint256 tokenId) public view virtual returns (string memory) {
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        _requireMinted(tokenId);
        string memory _tokenURI = ds._tokenURIs[tokenId];
        string memory base = _baseURI();
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        if (bytes(_tokenURI).length > 0) {
            return string.concat(base, _tokenURI);
        }
        return tokenURI(tokenId);
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal {
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        require(_exists(tokenId), "ERC721URIStorage: URI set of nonexistent token");
        ds._tokenURIs[tokenId] = _tokenURI;
        emit MetadataUpdate(tokenId);
    }

    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    function approve(address to, uint256 tokenId) public virtual {
        _approve(to, tokenId, _msgSender());
    }

    function getApproved(uint256 tokenId) public view virtual returns (address) {
        _requireMinted(tokenId);
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        return ds._tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) public virtual {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    function isApprovedForAll(address owner, address operator) public view virtual returns (bool) {
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        return ds._operatorApprovals[owner][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) public virtual {
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        address previousOwner = _update(to, tokenId, _msgSender());
        if (previousOwner != from) {
            revert ERC721IncorrectOwner(from, tokenId, previousOwner);
        }
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual {
        transferFrom(from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, data);
    }

    function _ownerOf(uint256 tokenId) internal view virtual returns (address) {
        return LibDomains._ownerOf(tokenId);
    }

    function _getApproved(uint256 tokenId) internal view virtual returns (address) {
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        return ds._tokenApprovals[tokenId];
    }

    function _isAuthorized(address owner, address spender, uint256 tokenId) internal view virtual returns (bool) {
        return
            spender != address(0) &&
            (owner == spender || isApprovedForAll(owner, spender) || _getApproved(tokenId) == spender);
    }

    function _checkAuthorized(address owner, address spender, uint256 tokenId) internal view virtual {
        if (!_isAuthorized(owner, spender, tokenId)) {
            if (owner == address(0)) {
                revert ERC721NonexistentToken(tokenId);
            } else {
                revert ERC721InsufficientApproval(spender, tokenId);
            }
        }
    }

    function _increaseBalance(address account, uint128 value) internal virtual {
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        if (value > 0) {
            revert ERC721EnumerableForbiddenBatchMint();
        }
        unchecked {
            ds._balances[account] += value;
        }
    }

    function _update(address to, uint256 tokenId, address auth) internal virtual returns (address) {
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        address from = _ownerOf(tokenId);
        if (auth != address(0)) {
            _checkAuthorized(from, auth, tokenId);
        }
        if (to == address(0) && bytes(ds._tokenURIs[tokenId]).length != 0) {
            delete ds._tokenURIs[tokenId];
        }
        if (from != address(0)) {
            delete ds._tokenApprovals[tokenId];
            unchecked {
                ds._balances[from] -= 1;
            }
        }
        if (to != address(0)) {
            unchecked {
                ds._balances[to] += 1;
            }
        }
        ds._owners[tokenId] = to;
        if (from == address(0)) {
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (from != to) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (from != to) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }
        emit Transfer(from, to, tokenId);
        return from;
    }

    function _burn(uint256 tokenId) internal {
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        address previousOwner = _update(address(0), tokenId, address(0));
        string memory domainName = ds._domainName[tokenId];
        if (ds._primaryDomainName[tokenId]) {
            ds._addressToName[ds._nameToAddress[domainName]] = 0;
            ds._nameToAddress[domainName] = address(0);
            ds._primaryDomainName[tokenId] = false;
        }
        if (ds._expTime[domainName] > 0) {
            ds._expTime[domainName] = 0;
            ds._domainID[domainName] = 0;
            delete ds._domainName[tokenId];
        }
        if (previousOwner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }
    }

    function _mint(address to, uint256 tokenId) internal {
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        address previousOwner = _update(to, tokenId, address(0));
        if (previousOwner != address(0)) {
            revert ERC721InvalidSender(address(0));
        }
    }

    function _safeMint(address to, uint256 tokenId) internal {
        _safeMint(to, tokenId, "");
    }

    function _safeMint(address to, uint256 tokenId, bytes memory data) internal virtual {
        _mint(to, tokenId);
        _checkOnERC721Received(address(0), to, tokenId, data);
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        address previousOwner = _update(to, tokenId, address(0));
        if (previousOwner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        } else if (previousOwner != from) {
            revert ERC721IncorrectOwner(from, tokenId, previousOwner);
        }
    }

    function _safeTransfer(address from, address to, uint256 tokenId) internal {
        _safeTransfer(from, to, tokenId, "");
    }

    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory data) internal virtual {
        _transfer(from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, data);
    }

    function _approve(address to, uint256 tokenId, address auth) internal virtual returns (address) {
        address owner = ownerOf(tokenId);
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        if (auth != address(0) && owner != auth && !isApprovedForAll(owner, auth)) {
            revert ERC721InvalidApprover(auth);
        }
        ds._tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
        return owner;
    }

    function _setApprovalForAll(address owner, address operator, bool approved) internal virtual {
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        if (operator == address(0)) {
            revert ERC721InvalidOperator(operator);
        }
        ds._operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    function _requireMinted(uint256 tokenId) internal view virtual {
        if (_ownerOf(tokenId) == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }
    }

    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory data) private {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                if (retval != IERC721Receiver.onERC721Received.selector) {
                    revert ERC721InvalidReceiver(to);
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert ERC721InvalidReceiver(to);
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }

    function tokenOfOwnerByIndex(address owner, uint256 index) public view returns (uint256) {
        require(index < balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
        return LibDomains.tokenOfOwnerByIndex(owner, index);
    }

    function totalSupply() public view returns (uint256) {
        return LibDomains.totalSupply();
    }

    function tokenByIndex(uint256 index) public view virtual returns (uint256) {
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        if (index >= totalSupply()) {
            revert ERC721OutOfBoundsIndex(address(0), index);
        }
        return ds._allTokens[index];
    }

    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        uint256 length = balanceOf(to) - 1;
        ds._ownedTokens[to][length] = tokenId;
        ds._ownedTokensIndex[tokenId] = length;
    }

    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        ds._allTokensIndex[tokenId] = ds._allTokens.length;
        ds._allTokens.push(tokenId);
    }

    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        uint256 lastTokenIndex = balanceOf(from);
        uint256 tokenIndex = ds._ownedTokensIndex[tokenId];
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = ds._ownedTokens[from][lastTokenIndex];

            ds._ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            ds._ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }
        delete ds._ownedTokensIndex[tokenId];
        delete ds._ownedTokens[from][lastTokenIndex];
    }

    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        LibDomains.DomainStorage storage ds = LibDomains.diamondStorage();
        uint256 lastTokenIndex = ds._allTokens.length - 1;
        uint256 tokenIndex = ds._allTokensIndex[tokenId];

        uint256 lastTokenId = ds._allTokens[lastTokenIndex];

        ds._allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        ds._allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        delete ds._allTokensIndex[tokenId];
        ds._allTokens.pop();
    }

    function exists(uint256 tokenId) public view returns (bool) {
        return _exists(tokenId);
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }
}