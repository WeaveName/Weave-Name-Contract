// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface ISuffix {
    function addSuffix(string memory value) external;
    function getSuffix(uint256 _suffixId) external view returns (string memory);
    function isValidSuffix(uint256 _suffixId) external view returns (bool);
}