// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IDomainPrice {
    function getTolerance() external view returns (uint256);
    function getDomainPrice(string calldata domainName_, uint256 year_) external view returns (uint256);
}