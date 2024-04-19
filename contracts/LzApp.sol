// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {BytesLib} from "../libraries/LibBytes.sol";
import {LibLzApp} from "../libraries/LibLzApp.sol";
import {ExcessivelySafeCall} from "../libraries/LibExcessivelySafeCall.sol";
import "../interfaces/ILayerZeroReceiver.sol";
import "../interfaces/ILayerZeroUserApplicationConfig.sol";
import "../interfaces/ILayerZeroEndpoint.sol";
import {IMainDiamond} from "../interfaces/IMainDiamond.sol";

abstract contract LzApp is ILayerZeroReceiver, ILayerZeroUserApplicationConfig {
    using BytesLib for bytes;
    using ExcessivelySafeCall for address;

    modifier onlyOwner() {
        require(
            IMainDiamond(payable(address(this))).owner() == msg.sender,
            "Only the owner can call this"
        );
        _;
    }

    function changeLzEndpoint (address _currentEndpoint) external onlyOwner {
        LibLzApp.LzAppStorage storage ds = LibLzApp.diamondStorage();
        ds.lzEndpoint = ILayerZeroEndpoint(_currentEndpoint);
    }

    event SetPrecrime(address precrime);
    event SetTrustedRemote(uint16 _remoteChainId, bytes _path);
    event SetTrustedRemoteAddress(uint16 _remoteChainId, bytes _remoteAddress);
    event SetMinDstGas(uint256 _minDstGas);
    event MessageFailed(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes _payload, bytes _reason);
    event RetryMessageSuccess(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes32 _payloadHash);

    function _blockingLzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload) internal virtual {
        (bool success, bytes memory reason) = address(this).excessivelySafeCall(gasleft(), 150, abi.encodeWithSelector(this.nonblockingLzReceive.selector, _srcChainId, _srcAddress, _nonce, _payload));
        // try-catch all errors/exceptions
        if (!success) {
            _storeFailedMessage(_srcChainId, _srcAddress, _nonce, _payload, reason);
        }
    }

    function lzReceive(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce, bytes calldata _payload) public virtual override  {
        LibLzApp.LzAppStorage storage ds = LibLzApp.diamondStorage();
        require(msg.sender == address(ds.lzEndpoint), "LzApp: invalid endpoint caller");
        bytes memory trustedRemote = ds.trustedRemoteLookup[_srcChainId];
        require(_srcAddress.length == trustedRemote.length && trustedRemote.length > 0 && keccak256(_srcAddress) == keccak256(trustedRemote), "LzApp: invalid source sending contract");
        _blockingLzReceive(_srcChainId, _srcAddress, _nonce, _payload);
    }

    function _lzSend(uint16 _dstChainId, bytes memory _payload, address payable _refundAddress, address _zroPaymentAddress, bytes memory _adapterParams, uint _nativeFee) internal virtual {
        LibLzApp.LzAppStorage storage ds = LibLzApp.diamondStorage();
        bytes memory trustedRemote = ds.trustedRemoteLookup[_dstChainId];
        require(trustedRemote.length != 0, "LzApp: destination chain is not a trusted source");
        _checkPayloadSize(_dstChainId, _payload.length);
        ds.lzEndpoint.send{value: _nativeFee}(_dstChainId, trustedRemote, _payload, _refundAddress, _zroPaymentAddress, _adapterParams);
    }

    function _checkGasLimit(uint16 _dstChainId, uint16 _type, bytes memory _adapterParams, uint _extraGas) internal view virtual {
        LibLzApp.LzAppStorage storage ds = LibLzApp.diamondStorage();
        uint providedGasLimit = _getGasLimit(_adapterParams);
        uint minGasLimit = ds.minDstGasLookup[_dstChainId][_type] + _extraGas;
        require(minGasLimit > 0, "LzApp: minGasLimit not set");
        require(providedGasLimit >= minGasLimit, "LzApp: gas limit is too low");
    }

    function _getGasLimit(bytes memory _adapterParams) internal pure virtual returns (uint gasLimit) {
        require(_adapterParams.length >= 34, "LzApp: invalid adapterParams");
        assembly {
            gasLimit := mload(add(_adapterParams, 34))
        }
    }

    function _checkPayloadSize(uint16 _dstChainId, uint _payloadSize) internal view virtual {
        LibLzApp.LzAppStorage storage ds = LibLzApp.diamondStorage();
        uint payloadSizeLimit = ds.payloadSizeLimitLookup[_dstChainId];
        if (payloadSizeLimit == 0) { // use default if not set
            payloadSizeLimit = ds.DEFAULT_PAYLOAD_SIZE_LIMIT;
        }
        require(_payloadSize <= payloadSizeLimit, "LzApp: payload size is too large");
    }

    function getConfig(uint16 _version, uint16 _chainId, address, uint _configType) external view returns (bytes memory) {
        LibLzApp.LzAppStorage storage ds = LibLzApp.diamondStorage();
        return ds.lzEndpoint.getConfig(_version, _chainId, address(this), _configType);
    }

    function setConfig(uint16 _version, uint16 _chainId, uint _configType, bytes calldata _config) external onlyOwner {
        LibLzApp.LzAppStorage storage ds = LibLzApp.diamondStorage();
        ds.lzEndpoint.setConfig(_version, _chainId, _configType, _config);
    }

    function setSendVersion(uint16 _version) external onlyOwner {
        LibLzApp.LzAppStorage storage ds = LibLzApp.diamondStorage();
        ds.lzEndpoint.setSendVersion(_version);
    }

    function setReceiveVersion(uint16 _version) external onlyOwner {
        LibLzApp.LzAppStorage storage ds = LibLzApp.diamondStorage();
        ds.lzEndpoint.setReceiveVersion(_version);
    }

    function forceResumeReceive(uint16 _srcChainId, bytes calldata _srcAddress) external onlyOwner {
        LibLzApp.LzAppStorage storage ds = LibLzApp.diamondStorage();
        ds.lzEndpoint.forceResumeReceive(_srcChainId, _srcAddress);
    }

    function setTrustedRemote(uint16 _remoteChainId, bytes calldata _path) external onlyOwner {
        LibLzApp.LzAppStorage storage ds = LibLzApp.diamondStorage();
        ds.trustedRemoteLookup[_remoteChainId] = _path;
        emit SetTrustedRemote(_remoteChainId, _path);
    }

    function setTrustedRemoteAddress(uint16 _remoteChainId, bytes calldata _remoteAddress) external onlyOwner {
        LibLzApp.LzAppStorage storage ds = LibLzApp.diamondStorage();
        ds.trustedRemoteLookup[_remoteChainId] = abi.encodePacked(_remoteAddress, address(this));
        emit SetTrustedRemoteAddress(_remoteChainId, _remoteAddress);
    }

    function getTrustedRemoteAddress(uint16 _remoteChainId) external view returns (bytes memory) {
        LibLzApp.LzAppStorage storage ds = LibLzApp.diamondStorage();
        bytes memory path = ds.trustedRemoteLookup[_remoteChainId];
        require(path.length != 0, "LzApp: no trusted path record");
        return path.slice(0, path.length - 20); // the last 20 bytes should be address(this)
    }

    function setPrecrime(address _precrime) external onlyOwner {
        LibLzApp.LzAppStorage storage ds = LibLzApp.diamondStorage();
        ds.precrime = _precrime;
        emit SetPrecrime(_precrime);
    }

    // if the size is 0, it means default size limit
    function setPayloadSizeLimit(uint16 _dstChainId, uint _size) external onlyOwner {
        LibLzApp.LzAppStorage storage ds = LibLzApp.diamondStorage();
        ds.payloadSizeLimitLookup[_dstChainId] = _size;
    }

    function isTrustedRemote(uint16 _srcChainId, bytes calldata _srcAddress) external view returns (bool) {
        LibLzApp.LzAppStorage storage ds = LibLzApp.diamondStorage();
        bytes memory trustedSource = ds.trustedRemoteLookup[_srcChainId];
        return keccak256(trustedSource) == keccak256(_srcAddress);
    }

    function _storeFailedMessage(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload, bytes memory _reason) internal virtual {
        LibLzApp.LzAppStorage storage ds = LibLzApp.diamondStorage();
        ds.failedMessages[_srcChainId][_srcAddress][_nonce] = keccak256(_payload);
        emit MessageFailed(_srcChainId, _srcAddress, _nonce, _payload, _reason);
    }

    function nonblockingLzReceive(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce, bytes calldata _payload) public virtual {
        require(msg.sender == address(this), "NonblockingLzApp: caller must be LzApp");
        _nonblockingLzReceive(_srcChainId, _srcAddress, _nonce, _payload);
    }

    function _nonblockingLzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload) internal virtual;

    function retryMessage(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce, bytes calldata _payload) public payable virtual {
        LibLzApp.LzAppStorage storage ds = LibLzApp.diamondStorage();
        bytes32 payloadHash = ds.failedMessages[_srcChainId][_srcAddress][_nonce];
        require(payloadHash != bytes32(0), "NonblockingLzApp: no stored message");
        require(keccak256(_payload) == payloadHash, "NonblockingLzApp: invalid payload");
        ds.failedMessages[_srcChainId][_srcAddress][_nonce] = bytes32(0);
        _nonblockingLzReceive(_srcChainId, _srcAddress, _nonce, _payload);
        emit RetryMessageSuccess(_srcChainId, _srcAddress, _nonce, payloadHash);
    }

}