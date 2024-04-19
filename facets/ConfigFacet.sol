// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IMainDiamond} from "../interfaces/IMainDiamond.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {LibConfig} from '../libraries/LibConfig.sol';

contract ConfigFacet {

    modifier onlyOwner() {
        require(IMainDiamond(payable(address(this))).owner() == msg.sender, "Only the owner can call this");
        _;
    }

    function initializeConfig() external onlyOwner {
        LibConfig.ConfigStorage storage ds = LibConfig.diamondStorage();
        require(!ds.initialized, "ConfigFacet: Contract instance has already been initialized");
        ds._paused = false;
        ds.initialized = true;
    }

    function changePaused() external onlyOwner{
        LibConfig.changePaused();
    }

    function getPaused() external view returns(bool) {
        return LibConfig.getPaused();
    }

    function withdraw(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "Insufficient balance");
        payable(IMainDiamond(payable(address(this))).owner()).transfer(amount);
    }

    function withdrawTokens(address tokenAddress, uint256 amount) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        require(token.balanceOf(address(this)) >= amount, "Insufficient token balance");
        token.transfer(IMainDiamond(payable(address(this))).owner(), amount);
    }
}